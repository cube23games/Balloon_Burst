# TJ-45E — Frame Delivery: Same-Frame Phase Correlation

Status: QA-only research instrument; **not a VSync fix**.

Base: TJ-45D signed green `9c49ff485b205489b3805bcce8e385880909382c`. Production main and private backup stay at protected `f1b749e4ac3d87233423d7c8a73bd4e73653beaa`.

## Why

TJ-45D revealed nearly zero synchronous game-loop time, few individual build/raster misses, but many frame total-spans over 16.7ms. Its worst ticker-gap and VSync-overhead maxima are independent summaries and cannot be assigned to the same frame. We need **per-frame phase decomposition**.

## Diagnostic design

Using `FrameTiming.timestampInMicroseconds(FramePhase.*)`, four phase durations for the **same frame** are computed:

- VSync wait: buildStart − vsyncStart
- UI build: buildFinish − buildStart
- Raster-queue/handoff wait: rasterStart − buildFinish
- Raster work: rasterFinish − rasterStart
- Total Flutter span: rasterFinish − vsyncStart (exact sum of the above)

Captures at most eight worst-by-total slow frames over 16,667µs with `frameNumber`, raw engine timestamp and all four durations. Counts dominant phase for each slow frame. Invalid phase order is counted separately; never fudged or clamped. No frame-event history growth, and strings appear only on export. Asynchronous timing callbacks are batched and have **no guaranteed 1:1 pairing** with ticker gaps. The engine timestamp epoch is not UTC. These metrics do **not** show actual physical screen presentation.

The sampler is gated behind the existing TJ-45D build flags AND `TJ45E_FRAME_PHASES=true`; no new ticker, timer, native Choreographer callback or change to game timestep. Sound, Aura V2, physics, particles, wind, ribbon chains, stars and coins are untouched.

## Two independently identifiable, same-commit QA artifacts

1. **Control:** `balloon-burst-internal-qa-frame-pacing-apk` (TJ-45D diagnostics, no frame phase history).
2. **Experiment:** `balloon-burst-internal-qa-frame-phases-apk` (same TJ-45D diagnostics plus top-eight phase analysis).

Both must use the SAME signing certificate and versionCode as the public and other QA artifacts, automatically verified by CI. The control and experiment must use identical V2 glow settings and preserved Android app ID.

## Phone test, after GREEN CI only

1. Confirm saved World 1 stars and bank; install experiment over the existing app without uninstalling or clearing data.
2. Play Level 8 once, then Endless for at least 120 seconds with sound ON and auto-tap OFF; avoid gameplay screenshots during the run. Export both reports.
3. Confirm `qaGlowRenderer: tightAuraV2`, `qaFramePacingDiagnostic: enabled`, `qaFramePhaseDiagnostic: enabled`, and no more than eight `qaFramePhaseWorst[n]` rows.
4. Optional overhead control: install **control APK from the same CI run** over data, play matched 120-second Endless, export. It should have TJ-45D fields but **not** `qaFramePhaseDiagnostic: enabled`.
5. Verify retained 24/24 stars and coins. Record observed stutters separately from debug counters, especially before/after pause or screenshot.
6. Upload detailed report text. Compare same-frame phase attribution and control/experiment overhead; do not infer physical present or refresh-desync without Android FrameTimeline evidence.

## Stop conditions

No merge, tag/mirror update, production promotion or release without owner authorization. Do not reduce visuals/audio to improve scores. Keep PR draft. Unit tests assert 16.667ms boundary, phase identity, bounded top-eight, invalid frame handling and replay reset. CI must pass including signing verification.