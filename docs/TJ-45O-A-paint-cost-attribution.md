# TJ-45O-A — Paint Cost Attribution (QA-only)

## Starting evidence
From verified TJ-45N November 27 QA report: 59.8 s run; 3,485 Flutter
frame-timing samples; 45 raster samples over 16.7 ms; 735 long
Flutter phase spans, 633 raster-work dominant; 13 ticker hitches;
game-update mean 0.06 ms, zero update budget violations.

## Instrumentation
`qa-paint-cost` is a dedicated signed experimental APK; the public release,
TJ-45N control and all previous APK feature flags are unchanged.
The new `TJ45O_PAINT_COST` compile-time gate allocates a bounded
`QaPaintCostStats` collector only when enabled. Each selected
`CustomPainter.paint` operation runs normally. Only one of 16 calls per
category uses a Dart Stopwatch; the call is never skipped.

Categories: balloon (whole moving-scene painter including glow/ribbons),
aura (nested subset of balloon paint, not additive), particles, shockwaves,
scoreBursts (including TextPainter layout). The latter three are wrapped with
a delegating CustomPainter in QA mode only. Counters, sum, max and up to eight
slow measurements per category use bounded state. Resets on new game run.

## Interpretation
Numbers are CPU-side Flutter Dart canvas command recording and preparation
times. They do NOT include GPU rasterization, compositor queue, physical
frame presentation, or actual surface deadlines.
Aura timings are a nested subset of balloon timings; never sum the two.
The sampling rate is per category rather than every 16th screen frame,
and rare transient effects may not reach 16 invocations.
No per-frame platform calls, scheduler modifications, image capture or
persistent storage.

## Acceptance
- Python TJ-45N analyzer self-test and Flutter regressions green.
- TJ-45O-A-specific Dart test run with `TJ45O_PAINT_COST=true` green.
- New QA APK has permanent signing identity and monotonic CI version code.
- Compare normal Flutter timing statistics against TJ-45N only with
  explicit caveat for non-identical game runs.
- At phone QA, preserve 24/24 stars and last 4,534 coins; run ~60-90 s
  without Perfetto first and export debug report.
- Do not promote to production or change visual effects before evidence.
