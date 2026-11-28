# TJ-45I — Wall-clock callback correlation QA
Status: QA-only experiment; no frame-pacing change.

## Evidence basis
The TJ-45H Moto G 2026 Endless report (November 25, 2026) had:
- 7,614 valid paired callback intervals.
- 10 long ticker/engine nominal timestamp intervals (>= 35.714 ms).
- 57 long monotonic wall-clock callback arrival intervals at the same threshold.
- Worst Ticker/engine delta 66.65 ms; worst wall delta 56.81 ms.
- Only ticker-long intervals were retained individually; exact event overlap was
  unknown. Subtracting 10 from 57 DOES NOT establish 47 wall-only events.
The aim is to expose the *same-interval* cross-tab without extrapolation.

## New diagnostic
The default-off QA flag TJ45I_WALL_CLOCK_CORRELATION=true extends the
existing (TJ-45H) Ticker callback observer. For each valid interval it
increments one and only one of:
- wall-only slow (wall >= threshold, raw engine < threshold)
- engine-only slow (raw engine >= threshold, wall < threshold)
- both slow
- neither slow

For slow wall-clock intervals it also counts startup (<1 second of local
sampler clock), within 2.5 seconds after a recorded lifecycle event, and
Debug HUD visibility. Retains 8 worst wall-clock intervals across all
categories and **separately 8 worst wall-only intervals**, with Ticker and
engine deltas, monotonic elapsed clock in ms, raw engine frame timestamp
(unverified epoch), navigation/lifecycle markers and optional post-frame
callback latency. Existing TJ-45H top-8 ticker and counters remain.

A one-shot addPostFrameCallback is installed only when an interval enters
one of the bounded top-8 lists. It DOES NOT request a frame. Callback
time to Flutter post-frame is not display presentation, and this probe
does not measure the time of internal scheduleFrame() requests or native
Choreographer/VSync delivery. Raw frame timestamps are not automatically
clock-aligned with Perfetto; work with deltas unless verified.

## Artifact, controls and signing
Artifact: balloon-burst-internal-qa-wall-clock-apk
Built with prior TJ-45H flags + TJ45I_WALL_CLOCK_CORRELATION=true.
The same CI commit also builds the previous
balloon-burst-internal-qa-frame-scheduler-apk control WITHOUT TJ-45I
to allow a controlled comparison if diagnostic overhead appears material.
All ten APK variants must be built with the existing permanent signing
key and same monotonically increasing CI-run versionCode.
Never downgrade the installed APK to an earlier workflow run merely
to obtain a control.

## Phone test (ONLY after full green signed CI)
1. Install over the existing app without clearing storage or uninstalling.
   Confirm World 1 24/24 stars and last saved coins (latest: 3,085 after
   the TJ-45H run result). The bank may legitimately increase thereafter.
2. Play ONE 90–120 second Endless run with sound ON and auto-tap OFF.
   Keep Debug HUD closed during gameplay; export a detailed report only
   at the end. Note any system overlay, notification or focus interruption.
3. Verify all earlier QA signature fields plus
   qaWallClockCorrelationDiagnostic: enabled, and check the four disjoint
   counters total qaSchedulerIntervalSampleCount. Compare
   qaWallClockWorstWall and qaWallClockWorstWallOnly with existing
   qaSchedulerWorst Ticker entries.
4. If there is a surprising spike, consider one 90–120 second same-commit
   TJ-45H frame-scheduler control run, install-over only, then return to
   the new QA artifact using the same CI run. A/B comparison is optional
   and not evidence of causality with one sample.
5. Upload the report; optionally an on-phone short 20–30s Perfetto trace
   with CPU scheduling if precise source attribution is still unclear.
   There is no need to capture a large Perfetto trace initially.

## Safety
No new VSync controller, timers, CPU polling, requestFrame calls, frame
rate override, audio or visual reduction, game logic or persistence
changes. No permissions or package identifier changes. No production,
backup, tag or release updates. Unmerged draft PR only.
