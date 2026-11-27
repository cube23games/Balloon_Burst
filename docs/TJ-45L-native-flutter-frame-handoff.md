# TJ-45L — Native-to-Flutter Frame Handoff Isolation

Status: QA-only investigation, draft PR. No gameplay correction included.

## Evidence from TJ-45K
The signed November 26 QA run showed 39 wall-only Ticker delays
and 38 long Flutter scheduleFrame → handleBeginFrame waits. In the
eight worst wall-only cases, request-to-begin was 42–54ms, but the
begin-to-Ticker cost was only 0.02–0.04ms.

Read-only inspection of the matching Perfetto trace showed native
Android processPendingEvents VSync gaps of roughly 34–45ms around
several of those Flutter delays. Main-thread wake-to-CPU latency was
small relative to the gaps (median 0.068ms, p99 0.51ms, 6341 pairs).
This does not prove faulty Android VSync or physical presentation.

TJ-45K's single clock anchor required a 37.66ms Dart/native round trip:
the midpoint was not precise enough to identify an individual VSync
with confidence.

## TJ-45L implementation
- The dedicated QA APK retains exactly the current framework
  scheduleFrame and handleBeginFrame probes and the existing Ticker.
  It does not introduce any independent VSync listener or new frame
  scheduling behavior.
- Nine sequential native MethodChannel clock anchors at game start,
  and nine more on detailed report export after the gameplay session.
  Nothing is sampled over the MethodChannel on each frame. The early
  sampling is marked as startup QA overhead; the late burst happens
  outside the requested gameplay trace.
- Each native anchor reads System.nanoTime, then
  SystemClock.elapsedRealtimeNanos, then System.nanoTime. The Android
  main thread includes a brief ATrace marker TJ45L_clock_anchor around
  the read. This marker is calibration evidence, not a frame event.
- Dart reads its monotonic Stopwatch just before and just after each
  MethodChannel call. Only the lowest-roundtrip valid sample is kept
  in each phase, tie-broken by the narrowest native sampling interval.
- The report includes attempts, valid samples, RTT, native sample span,
  best approximate boot-at-Dart-zero, BOOTTIME/MONOTONIC offset,
  early-to-late drift, and nominal midpoint uncertainty. This nominal
  window is an assumption, not a guaranteed bound; suspend can affect
  clock offsets and must be explicitly considered during trace analysis.
- For the bounded eight worst wall-only cases and eight worst
  request-wait cases, estimate BOOTTIME timestamps for Dart framework
  request, beginFrame, and existing Ticker. Label the selected anchor
  phase and uncertainty for independent matching to native Perfetto
  processPendingEvents and requestNextVsync markers.
- Do not equate Dart Stopwatch, Flutter raw engine timestamp, Android
  MONOTONIC, BOOTTIME, wall DateTime, or actual screen presentation.

## QA gate and follow-up
A dedicated qa-native-handoff build with TJ45L_NATIVE_HANDOFF=true,
with all prior TJ-45K diagnostic flags and tight Aura V2 retained.
Artifact name: balloon-burst-internal-qa-native-handoff-apk.
Its signer MUST match all previous variants; versionCode MUST equal
the new GitHub Actions run number. Existing eleven APK variants remain
unchanged and built as controls.

After full GREEN CI only: install over the existing signed app without
wiping progress; verify 24/24 stars and saved bank (last 3678).
Capture a ~45–60 second Endless Arcade run with Android CPU scheduling
and graphics tracing on, sound on, auto-tap off, HUD closed. Stop
system tracing before opening HUD. Then export a detailed report to
collect the final nine native clock anchors.

Required fields: qaNativeHandoffDiagnostic: enabled, both start and
export phases with ideally 9 valid samples, the original
qaFrameRequestCorrelationDiagnostic, qaWallClockCorrelationDiagnostic,
and qaGlowRenderer: tightAuraV2. Compare best RTTs to the 37660us
single-anchor TJ-45K baseline. The trace remains a separate file, and
read-only Desktop Commander inspection needs explicit authorization
and immediate disconnect after use.

## Guardrails
No changes to gameplay, particle or balloon rendering, glow, audio,
storage, signed release, permissions, autonomous frame scheduling, or
refresh rate. Production and private backup main stay at
f1b749e4ac3d87233423d7c8a73bd4e73653beaa. No merge,
promotion, or backup sync without owner approval.
