# TJ-45H — Existing Flutter Ticker / VSync frame-delivery diagnostic

**Research-only, QA-only.** Builds on signed-green TJ-45G #96, protected production and backup remain at f1b749e4ac3d87233423d7c8a73bd4e73653beaa.

## Research question

TJ-45G confirmed that normal game/widget builder bodies were fast and the 150ms early-session tick gap happened well before opening the Debug HUD. Flutter FrameTiming showed a 129.95ms VSync-to-buildStart delay in that run. Matched Perfetto work from TJ-45F showed already-runnable main/raster threads generally scheduled quickly. We need a more precise frame-callback observation **before making any scheduler fix**.

## New diagnostic and strict limits

TJ-45H records THREE deltas for **the same delivered existing game Ticker callback**:

- Ticker elapsed microsecond delta (animation time; not a stopwatch).
- Flutter SchedulerBinding.currentSystemFrameTimeStamp delta (raw engine timestamp of the onBeginFrame that invoked the Ticker; arbitrary epoch, **NOT** a display presentation timestamp).
- Stopwatch monotonic wall delta at the callback (time between callback entries, NOT the time a frame was requested).

This does NOT directly measure when Flutter called `scheduleFrame()`, nor when Android's VSync callback was posted. We may infer a *gap between delivered callbacks* but NOT isolate upstream schedule request latency without another verified source.

Only for samples above the existing ~35.7ms hitch threshold **that enter the top-eight list**, a one-shot `addPostFrameCallback` records the time between that Ticker callback and the end of Flutter's current frame callbacks. It **does not request a new frame**. This is NOT panel presentation or GPU finish. No new persistent frame observers, Choreographer loops, timers, or application-controlled FPS pacing.

Bounded counters: sample count, gap counts by each clock, unexpected scheduler phase, invalid/regressing timestamp count, eight worst ticker gaps, and up to eight lifecycle pause/resume markers. Raw epoch reported for potential future correlation but **not assumed equal to Perfetto or Flutter FrameTiming timestamps** without calibration. The original TJ-45E phase decomposition and TJ-45F Android host-window metrics are preserved.

Flags in the dedicated `balloon-burst-internal-qa-frame-scheduler-apk`: existing `qa-ui-build` defines plus `TJ45H_FRAME_SCHEDULER=true`; all other eight signed APK modes retain their flags and behavior. All nine signed variants should pass certificate + CI run-number checks.

## Phone acceptance (only after full green CI)
1. Install over current app, NEVER uninstall/clear game data. Confirm World 1 24/24 stars and saved coin bank.
2. Play one **90–120 second Endless** run with audio ON, auto-tap OFF. Avoid Debug HUD until the end; export detailed report once. No need to capture another huge Perfetto trace for the first pass.
3. Verify `qaGlowRenderer: tightAuraV2`, `qaFramePacingDiagnostic: enabled`, `qaFramePhaseDiagnostic: enabled`, `qaUiBuildDiagnostic: enabled`, `qaSchedulerDiagnostic: enabled`, and optional `qaAndroidWindowFrameProbe: enabled`.
4. Inspect `qaSchedulerWorst[n]`: ticker gap vs raw-engine timestamp gap vs monotonic wall interval, plus post-frame callback interval; lifecycle markers show pauses. A single report can rule out hypotheses but cannot prove physical-present jank.
5. Compare new slow callback data with existing Flutter FrameTiming slow-phase records. Avoid joining raw timestamps by assumption. If clocks diverge, investigate only after calibration.

**STOP conditions:** any failed CI/signing, missing saved stars/coins, renderer/audio/input differences, unexpected sample-clock regressions, or increased instability. Never merge or alter main/backup/tags/signing without explicit approval. No visual/auditory quality reductions.
