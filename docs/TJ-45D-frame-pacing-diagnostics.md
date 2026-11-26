# TJ-45D — Frame-pacing instrumentation, QA only

**Status:** Research instrument; NOT a VSync fix or production release.
**Base commit:** `114a40f04d0dcc0a2474003428945c80678d49cb` (TJ-45B Aura V2).
**Protected main/backup:** TJ-44H `f1b749e4ac3d87233423d7c8a73bd4e73653beaa`.

## Purpose and architecture

SlimNation hypothesizes the visible ~50/66.7ms ticker gaps are caused
by display scheduling/refresh interactions rather than expensive visuals.
The game already advances on Flutter's `Ticker(vsync: this)`. Do NOT add a
second `Timer.periodic`, native `Choreographer` update loop or competing
VSync controller to test this hypothesis.

The diagnostic QA APK enables the same V2 aura colors and geometry as the
prior V2 build. It adds only bounded, numeric instrumentation, with no
per-frame debug log strings or growing event arrays.

## Report fields

- Existing `qaFrameGap*`: game-ticker callback intervals, including startup
  hitches. This is NOT native surface presentation timing.
- Existing `qaFlutterTimingBuild*` and `Raster*`: per-frame Flutter pipeline
  stages delivered asynchronously, sometimes in batches.
- **New** `qaFlutterTimingVsync*`: Flutter `FrameTiming.vsyncOverhead`,
  sampled only for the instrumented APK. Not a physical-present timestamp.
- **New** `qaFlutterTimingTotalSpan*`: Flutter `FrameTiming.totalSpan`,
  ending at raster completion, not actual display presentation.
- **New** `qaGameUpdate*`: monotonic Stopwatch duration for the synchronous
  in-ticker gameplay update path (from immediately before
  `widget.engine.update(dt)` until just before `setState`), including
  simulation/QA hitch logging but not UI build/raster. The field
  `OverBudgetAfterTickerHitch` means a slow update **on a callback preceded
  by a long interval**, not proof that update caused that earlier gap.
- `qaFramePacingDiagnostic: enabled` identifies this build.

Each sampler has a fixed number of int counters/sums; reports are formatted
only on export. No modifications to gameplay timestep, easing, particles,
audio, rendering shaders, wind, ribbons, game state persistence or scoring.
All new measures are compile-time gated by both
`ENABLE_QA_AUTOTAP=true` and `TJ45D_FRAME_DIAG=true`.
Production, normal QA and the four pre-existing signed QA artifacts retain
their original behavior and measurement overhead.

## CI and installation gate

GitHub Actions builds an additional APK artifact
`balloon-burst-internal-qa-frame-pacing-apk` from the SAME commit and
certificate as public, original QA, V1 and V2. Its versionCode must match
`GITHUB_RUN_NUMBER`. Wait for **full green signed CI**, never uninstall or
clear game data, and install over the existing Balloon Burst.

Verify saved World 1 24/24 stars and saved coins before/after; coin balance
may increase from legitimately earned rewards.

## Owner phone QA

1. Keep display at normal 60Hz, battery saver off and audio ON. Note battery,
   approximate temperature and whether other apps were busy. Avoid screen
   capture during the first uninterrupted measured run.
2. Cold launch; play **Level 8** (36 pops, 3 leads, 3 chains, <=1 escape),
   export detailed debug report: `TJ45D-L8-cold.txt`.
3. Without force-closing, replay **Level 8**; export:
   `TJ45D-L8-warm.txt`.
4. Play **Endless Arcade for >=120 seconds**, aim for streak >=100,
   export: `TJ45D-Endless.txt`.
5. Note whether perceived stutters happened during balloon movement,
   impacts/audio, screen transitions, screenshot interrupts or when idle.
6. Confirm each report contains `qaGlowRenderer: tightAuraV2` and
   `qaFramePacingDiagnostic: enabled`, alongside existing baseline fields.
7. Optional second set: repeat without screenshots during gameplay; perform
   an audio-muted control only **after** the first sound-on comparison.
8. Report three exports plus the observed star/coin balances and any
   reproduction details. No game data reset.

## Interpretation guide (not a causal claim)

- High ticker gaps **with low** game-update, build and raster costs:
  investigate scheduling, Android app lifecycle, OS/thermal contention,
  background services and future native presentation tracing.
- High synchronous update times: profile game-loop CPU processing and
  instrumentation overhead *without* reducing content/effects.
- High VSync overhead: scrutinize the Flutter frame scheduling path;
  compare callbacks carefully, not frame-by-frame one-to-one.
- High raster or totalSpan: profile raster/compositing/asset costs.
- Good Flutter metrics + visibly jerky physical output: consider a
  platform FrameTimeline/Perfetto trace if device access allows.
- `FrameTiming` callbacks may report *batches*. Sample counts are not
  guaranteed to match `qaFrameGapSampleCount`; do not correlate samples
  by array index.

## Stop conditions

No merge, release, backup push or protected-tag alteration without owner
approval. Reject if signed CI fails, replay/reset breaks, stars/coins change
unexpectedly, or the experiment visibly changes animation/audio/glow.
