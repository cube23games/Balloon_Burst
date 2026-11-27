# TJ-45N — bounded QA app-frame breadcrumbs and honest Perfetto correlation

Status: experimental QA-only diagnostic; not a rendering fix and not proof of
individual game-surface presentation.

## Objective
Identify at most 32 Flutter slow request-to-begin events with the existing
TJ-45K frame IDs in Android's native trace. Allow offline comparison with
SurfaceFlinger display events without inventing a hard app-surface match.

## Instrumentation
- New exclusive `qa-app-frame` artifact: retains TJ-45M clock-epoch protection.
- Under `TJ45N_APP_FRAME_TRACE` only, existing game ticker evaluates the
  existing `QaFrameRequestStats.recordTicker` result. If request-to-begin is
  >=35.714ms, submit at most 32 async platform-channel marker requests per run.
- Android receives the reported `frameId` and wait microseconds and emits
  `TJ45N_f<id>_w<us>` using android.os.Trace.
- These are **arrival-time breadcrumbs after the callback**, NOT a timestamp of
  Flutter request, native vsync, app buffer queue or physical presentation.
- No new Choreographer callback, frame request, GPU readback, scheduled timer,
  Android permission, gameplay-state mutation or persisted data.
- Both Dart and Android cap markers to 32; a run initializes each cap.
- Report fields `qaAppFrameTraceSubmitted` and
  `qaAppFrameTraceMaxSubmitted` aid audit; legacy QA variants remain gated off.

## Offline analyzer
`python3 tools/tj45n_correlate.py --self-test`

`python3 tools/tj45n_correlate.py --report REPORT.txt --trace TRACE.perfetto-trace`

Uses the existing TJ-45M run-start BOOTTIME estimate to select a display-wide
Frame Timeline window. Aborts if clock discontinuity, lifecycle boundaries or
missing anchors invalidate mapping. Lists no more than eight slow Flutter
observations with nearest display event and the explicit result
`frame_match: UNPROVEN` and `app_surface_match: UNPROVEN`.

It deliberately does **not** join `frameId` to SurfaceFlinger's vsync ID.
To prove that, future experiments would need a verified app-layer frame token or
buffer lifecycle correlation from an instrumented Flutter engine/Android surface.

## Acceptance
- Dedicated artifact signed with permanent signer and exact CI version code.
- All earlier 13 signed variants unchanged in their feature flags.
- Python self-test and existing Flutter tests green.
- Normal 24/24 stars, saved coins, audio, V2 aura, physics, UI preserved.
- No new trace requested until signed CI and targeted phone QA are warranted.
- Keep source branches draft, no merges or backup main changes without approval.
