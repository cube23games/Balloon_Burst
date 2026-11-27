#!/usr/bin/env python3
"""TJ-45N: offline, bounded QA-only Flutter/Perfetto correlation.

No device instrumentation or scheduling changes. All Android display events are
DISPLAY-WIDE, never asserted to be Balloon Burst surface presentations.
"""
import argparse
import json
import re
from pathlib import Path

MAX_RECORDS = 8
PACKET_FRAME_TIMELINE = 76
ACTUAL_DISPLAY_FRAME = 2


def varint(buf, pos):
    value = shift = 0
    while pos < len(buf):
        byte = buf[pos]
        pos += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, pos
        shift += 7
        if shift > 70:
            raise ValueError("invalid varint")
    raise ValueError("truncated varint")


def fields(buf, start=0, end=None):
    if end is None:
        end = len(buf)
    pos = start
    while pos < end:
        tag, pos = varint(buf, pos)
        number, wire = tag >> 3, tag & 7
        if wire == 0:
            value, pos = varint(buf, pos)
        elif wire == 2:
            size, pos = varint(buf, pos)
            value = (pos, pos + size)
            pos += size
        elif wire == 1:
            value = int.from_bytes(buf[pos:pos + 8], "little")
            pos += 8
        elif wire == 5:
            value = int.from_bytes(buf[pos:pos + 4], "little")
            pos += 4
        else:
            raise ValueError("unsupported wire type %s" % wire)
        if pos > end:
            raise ValueError("truncated field")
        yield number, value


def values(buf, start, end):
    return dict(fields(buf, start, end))


def parse_report(raw):
    match = lambda key: re.search(r"^" + re.escape(key) + r":\s*(.+)$", raw, re.M)
    def read(key, default=None):
        hit = match(key)
        return hit.group(1).strip() if hit else default

    if read("qaClockEpochIntegrityDiagnostic") != "enabled":
        raise ValueError("TJ-45M clock epoch diagnostic required")
    if read("qaClockEpochDiscontinuity") != "notDetected":
        raise ValueError("unverified clock discontinuity: refusing absolute matching")
    if int(read("qaClockEpochLifecycleMarkCount", "-1")) != 0:
        raise ValueError("lifecycle boundary present: fail closed")
    if int(read("qaClockEpochLifecycleMarkOverflow", "-1")) != 0:
        raise ValueError("lifecycle overflow present: fail closed")
    zero = int(read("qaNativeHandoffrunStartBootAtDartZeroNs", "-1"))
    run_mid = int(read("qaNativeHandoffrunStartDartMidUs", "-1"))
    export_mid = int(read("qaNativeHandoffreportExportDartMidUs", "-1"))
    if min(zero, run_mid, export_mid) < 0 or export_mid <= run_mid:
        raise ValueError("missing or out-of-order clock calibration")
    duration_s = float(read("engineElapsedSeconds", "-1"))
    if duration_s <= 0:
        raise ValueError("missing gameplay duration")
    observations = []
    for line in raw.splitlines():
        if not line.startswith("qaNativeHandoffWorstWait["):
            continue
        get = lambda name: re.search(r"\b" + name + r"=([^ ]+)", line)
        status = get("qaEpochMappingStatus")
        if not status or status.group(1) != "provisional-runStart-before-lifecycle":
            continue
        boot = get("beginBootNs")
        frame_id = get("frameId")
        wait = get("requestToBeginUs")
        if not (boot and frame_id and wait):
            continue
        stamp = int(boot.group(1))
        if stamp < zero or stamp > zero + export_mid * 1000:
            continue
        observations.append({"frame_id": int(frame_id.group(1)),
                             "begin_boot_ns": stamp,
                             "wait_ms": int(wait.group(1)) / 1000})
    return {"run_id": read("runId"), "zero_boot_ns": zero,
            "duration_s": duration_s, "export_end_ns": zero + export_mid * 1000,
            "observations": observations[:MAX_RECORDS]}


def read_display_events(path, start_ns, stop_ns):
    # Standard Perfetto Trace.packet field 1, TracePacket.timestamp field 8,
    # TracePacket.frame_timeline_event field 76,
    # FrameTimelineEvent.actual_display_frame_start field 2.
    raw = Path(path).read_bytes()
    items = []
    for tag, value in fields(raw):
        if tag != 1 or not isinstance(value, tuple):
            continue
        packet = values(raw, *value)
        ts = packet.get(8)
        event_range = packet.get(PACKET_FRAME_TIMELINE)
        if not isinstance(ts, int) or not isinstance(event_range, tuple):
            continue
        if ts < start_ns or ts > stop_ns:
            continue
        event = values(raw, *event_range)
        actual = event.get(ACTUAL_DISPLAY_FRAME)
        if not isinstance(actual, tuple):
            continue
        event_data = values(raw, *actual)
        items.append({"boot_ns": ts,
                      "presentation_type": event_data.get(4),
                      "jank_type": event_data.get(7),
                      "vsync_id": event_data.get(2)})
    return items


def correlate(report, events):
    on_time = sum(e["presentation_type"] == 1 for e in events)
    late = sum(e["presentation_type"] == 2 for e in events)
    unknown = len(events) - on_time - late
    rows = []
    for obs in report["observations"]:
        nearby = sorted(events, key=lambda e: abs(e["boot_ns"] - obs["begin_boot_ns"]))[:1]
        nearest = nearby[0] if nearby else None
        delta_ms = ((nearest["boot_ns"] - obs["begin_boot_ns"]) / 1e6
                    if nearest else None)
        rows.append({**obs,
                     "nearest_display_event_delta_ms": delta_ms,
                     "nearest_display_presentation_type": (
                         nearest["presentation_type"] if nearest else None),
                     "app_surface_match": "UNPROVEN",
                     "frame_match": "UNPROVEN"})
    return {"scope": "display-wide, not app surface",
            "counts": {"on_time": on_time, "late": late, "other": unknown},
            "app_presentation_status": "UNPROVEN",
            "reason": "No verified Flutter-frame to Android Surface frame token.",
            "candidates": rows}


def self_test():
    def enc(value):
        out = bytearray()
        while value >= 128:
            out.append((value & 127) | 128)
            value >>= 7
        out.append(value)
        return bytes(out)
    def int_field(n, value):
        return enc(n << 3) + enc(value)
    def blob_field(n, data):
        return enc(n << 3 | 2) + enc(len(data)) + data
    actual = int_field(2, 2) + int_field(4, 1) + int_field(7, 1)
    event = blob_field(2, actual)
    pkt = int_field(8, 1000000) + blob_field(76, event)
    trace = blob_field(1, pkt)
    nested = values(trace, *next(value for tag, value in fields(trace) if tag == 1))
    assert nested[8] == 1000000
    assert values(trace, *values(trace, *nested[76])[2])[4] == 1
    demo = {"observations": [{"frame_id": 3, "begin_boot_ns": 999999,
                               "wait_ms": 43.0}]}
    result = correlate(demo, [{"boot_ns": 1000000,
                               "presentation_type": 1, "jank_type": 1}])
    assert result["counts"]["on_time"] == 1
    assert result["candidates"][0]["frame_match"] == "UNPROVEN"
    try:
        parse_report("qaClockEpochIntegrityDiagnostic: enabled\n"
                     "qaClockEpochDiscontinuity: detected")
    except ValueError:
        pass
    else:
        raise AssertionError("clock discontinuity must fail closed")
    print("TJ-45N self-test PASS")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--trace", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.report is None or args.trace is None:
        parser.error("--report and --trace required")
    info = parse_report(args.report.read_text(encoding="utf-8"))
    events = read_display_events(args.trace, info["zero_boot_ns"],
                                 info["zero_boot_ns"] +
                                 int(info["duration_s"] * 1e9))
    print(json.dumps({"run_id": info["run_id"],
                      **correlate(info, events)}, indent=2))


if __name__ == "__main__":
    main()
