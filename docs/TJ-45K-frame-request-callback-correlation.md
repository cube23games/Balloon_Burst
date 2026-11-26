# TJ-45K — Framework frame request → beginFrame → game Ticker

Status: unmerged QA-only investigation. No performance correction is included.

## Evidence from TJ-45J
A matching November 25, 2026, ~50-second Perfetto recording and the
44.5-second TJ-45I debug report established:
- 36 wall-only callback delays, 13 engine-only, 3 both, out of 2,601
  valid game Ticker intervals.
- Android process PID 8401 (main), raster TID 8436.
- In five in-game ~49–52ms wall-only intervals, the app's Android
  main thread spent ~30–37ms sleeping and <2ms runnable-but-unscheduled.
  The trace's 5,160 wake-to-run pairs had ~0.069ms median and ~0.501ms
  p99, against a max of 3.338ms. This is evidence AGAINST sustained
  50ms CPU scheduler starvation on that thread.
- Perfetto ftrace markers included AIDL requestNextVsync and
  processPendingEvents VSync delivery. 2,637 request/delivery intervals,
  ~12.08ms median; 15 were >35ms. The trace is not proof of defective
  Android VSync or actual physical presentation times.

## Directly observable by Flutter without modifying engine or Android VSync
In the **TJ-45K QA APK only**, main() instantiates
QaFrameRequestBinding BEFORE runApp. This subclass calls super normally
while passively observing:
  (1) framework scheduleFrame() requests which were not already
      scheduled, and which framesEnabled permits,
  (2) handleBeginFrame(rawTimeStamp) entered when the engine wakes
      the Flutter framework to start the frame,
  (3) the **existing** GameScreen Ticker callback reached in the
      same raw-timestamp frame, paired via frame ID.
No additional scheduleFrame(), second VSync controller, timer,
independent frame loop, or native Choreographer callback is registered.

The report has a bounded top 8 worst wall-only arrival gaps and top 8
worst framework request-to-begin waits, plus counts of unmatched
framework begins and Tickers, lifecycle and invalid events. "Missing
request" does NOT necessarily imply no engine request: force frames,
warm-up frames, or engine-internal requests may bypass this hook.

For offline clock alignment, the existing lifecycle MethodChannel
handles getQaFrameClockAnchor exactly once per game start. It reads
System.nanoTime() (native CLOCK_MONOTONIC source) and
SystemClock.elapsedRealtimeNanos() (BOOTTIME) without making frame
requests. It records both local Dart Stopwatch timestamps bracketing
this call, so the anchor's round-trip interval is explicit. Report
clock conversion is a *calibrated estimate* with ± half the round-trip
as an uncertainty bound, NOT exact to nanoseconds. Raw Flutter engine
timestamps are left in their original epoch, never silently joined to
Perfetto until independently validated. For a new capture, Perfetto
clock snapshots can cross-check these offsets, and OS frame markers
can be compared to the Flutter-side request/begin/ticker sequence.
Native internal requestNextVsync is NOT hooked directly.

## New report fields
- qaFrameRequestCorrelationDiagnostic: enabled
- qaFrameRequestCount / qaFrameBeginCount / qaFrameTickerCount
- qaFrameRequestUnmatchedBegins / UnmatchedTickers / InvalidIntervals
- qaFrameRequestWallOnlySlowCount / WaitOver35_7Count
- qaFrameRequestClockAnchorRoundTripUs / ClockMonoAtZeroNs /
  ClockBootMinusMonoNs
- qaFrameRequestWorstWallOnly[n] and qaFrameRequestWorstWait[n]:
  sample ID, frame ID, request/begin/ticker local Stopwatch values,
  raw engine timestamp, per-stage intervals in ms.

## Signed artifact + phone QA
- build mode: qa-frame-request
- artifact: balloon-burst-internal-qa-frame-request-apk
- inner APK: balloon-burst-internal-qa-frame-request.apk
- Requires permanent signing and increasing CI-run versionCode.
- All previous 10 artifacts remain built as controls in same commit.

After full GREEN CI only:
1. Install over the current same-package signed build, NEVER uninstall
   or clear game data. Confirm 24/24 stars and saved coins (last
   confirmed 3,588, before further runs).
2. Sound ON, auto-tap OFF. Play ONE ~45–60-second Endless session with
   Debug HUD closed during play. Use the Android System Tracing settings
   used for TJ-45J, if available: CPU scheduling and graphics.
3. Start system trace BEFORE gameplay. Stop it AFTER the run; ideally
   preserve a short 5–10 second overlap/lead-in. Then open HUD and
   export one detailed report from that same game session.
4. Verify QA signatures: tightAuraV2, qaSchedulerDiagnostic,
   qaWallClockCorrelationDiagnostic, qaFrameRequestCorrelationDiagnostic.
5. Upload the small debug report. For Perfetto, if too large to upload,
   review the trace through Desktop Commander ONLY with separate
   explicit authorization, read-only, and immediately disconnect.

## Guardrails
One change per commit, draft PR only, signed green CI before phone test.
No changes to gameplay, draw effects, particles, audio, saving, native
frame callbacks, refresh rate, watchdogs, app permissions or signing.
Keep main and private backup pinned at
f1b749e4ac3d87233423d7c8a73bd4e73653beaa.
