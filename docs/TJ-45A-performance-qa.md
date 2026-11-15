# TJ-45A — Smooth Skies: frame-gap diagnostic baseline

**Starting authority:** signed, owner-device-verified TJ-44H checkpoint
`f1b749e4ac3d87233423d7c8a73bd4e73653beaa`,
tag `tj44h-main-integrated-device-verified`. World 1 is 8/8,
24/24 saved stars; existing coins and Endless Arcade must be preserved.

## What the metric means

- A **ticker callback interval** `rawDt >= 1/28 sec` (about 35.7 ms)
  increments the existing `performanceHitches` counter.
- The game already clamps gameplay delta to at most 1/30 sec (33.3 ms).
  Frame-gap reporting does not alter this behavior.
- Flutter's `Ticker` time gaps are **not proof of a rendering/GPU bottleneck**:
  they can include scheduling delays, app startup and system contention.
- The new QA-only, fixed-memory `FrameGapStats` tracks raw callback gaps.
  `firstSecond` means gameplay engine elapsed time under one second,
  not the time since Android launched the process.
- The four buckets are at most 16.7 ms, (16.7..33.3] ms,
  (33.3..50] ms and over 50 ms. Each recorded tick goes into one bucket.
  The hitch threshold is independently reflected by the two hitch counters.
- Paused ticks, resume grace and ended-run callbacks are excluded because
  `_onTick` exits before recording them; replay resets the counters.
- In QA exports, `qaFrameGapHitchesTotal` should equal
  `performanceHitches` for the current run. If not, STOP and investigate.
  The DebugLog may retain rows from older runs; don't sum its historical entries.

## Moto G 2026 reproducible baseline (QA build only)

Install the newly green **internal QA APK over the existing app**;
NEVER uninstall or clear data. Verify 24/24 stars and the current coin bank.

1. Record device refresh rate, Android version, battery level, power saving,
   temperature impression and whether audio is on. Keep conditions similar.
2. Force-close and launch app; play **Level 8 Carnival Gate** once.
   Export **Share Text File** from the completed results screen.
3. Replay Level 8 while the app remains open; export a second separate file.
4. Enter **Endless Arcade** and perform a comparable duration run; export.
5. Repeat the three test conditions with the same playing method where possible;
   avoid enabling auto-tap. Report visible stutters separately from metrics.
6. Optional after first set: repeat with app audio muted, keeping everything
   else consistent.

Suggested filename labels: `L8-cold-1.txt`, `L8-warm-1.txt`,
`endless-1.txt`. These are names of saved exports, not new features.

Compare session duration, normalized hitches/minute,
`qaFrameGapFirstSecondHitches`, `qaFrameGapLaterHitches`,
`qaFrameGapWorstMs` and all four gap buckets. A single run is not
sufficient evidence to change mechanics. Do not infer that wind or ribbon
effects caused a gap merely because a hitch happened near them.

## Release gate

This work adds QA-only diagnostics and tests. No adjustment to the engine's
timing, physics, spawner, difficulty, effects, user progression, stars, coins,
or playability. Keep TJ-45A on a review branch until signed CI and device
upgrade testing pass. Do not update the protected TJ-44H tag or private backup.
