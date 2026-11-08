# TJ-44B: Playable Skyward Journey (first two levels)

> **QA candidate — do not merge to `main` or release until CI and on-device QA pass.**
>
> Baseline: TJ-43H1 commit `60267594c9ad90e8e1e32be6d0a8b9c5d0fad7b6`.
> TJ-44A branch `tj-44-skyward-world1-foundation` added the world
> catalog and mission rules. TJ-44B branches from TJ-44A.

## What is playable now

- Start menu now offers **Skyward Journey** and the original **Endless Arcade**.
- Skyward Journey shows eight defined World 1 levels. **Only Levels 1 and 2
  are playable**. Levels 3–8 are marked *In development*; they require
  descending leads, wind, and ribbon physics not implemented yet.
- Level 1: pop 12 balloons; Level 2: pop 20 balloons.
- The current `GameScreen`, `TapHandler`, `BalloonSpawner`, `TJEngine`,
  sound, painter, physics, HUD telemetry, and existing world speeds are reused.
- Confirmed hit/miss/escape events flow into `SkywardLevelRun`.
- A level victory ends its run; the results overlay shows stars, accuracy,
  replay/map and next-level controls. A failed attempt allows replay or map.
- Local progress is saved under SharedPreferences key
  `skyward.world1.stars.v1` (eight stringified integers). The player retains
  their highest star count for each level.
- Skyward runs are **not** submitted to the original Endless Arcade leaderboard
  and do not pay the original arcade run coins. Future ticket economics are
  separate. A previously purchased engine shield still applies to an
  escape event, and shield absorption must not count as a mission escape.

## Required on-phone QA (after CI passes)

1. Install the **internal QA APK** from the *latest TJ-44B PR #2 CI run*,
   not TJ-44A, and record Android model/build. Use auto-tap **off**.
2. Launch > **Skyward Journey**. Confirm Level 1 selectable; Level 2 locked;
   Levels 3–8 clearly say *In development* and cannot be entered.
3. Start Level 1. Confirm tap response, familiar visuals, objective progress
   counter, and no clipping/overlap of objective HUD on the target phone.
4. Pop 12 balloons. Confirm **LEVEL CLEARED**, stars, replay/map and NEXT.
   The result must not show the original Endless Arcade leaderboard.
5. Tap NEXT; Level 2 begins with **0/20** progress and working touch input.
6. Fail Level 2 via misses or three unshielded escapes; verify TRY AGAIN,
   correct end state, and no unlocked Level 3.
7. Replay Level 2. Clear it; select LEVEL MAP and verify saved stars. Force
   close/reopen the app and verify stars/unlocks persist.
8. Return to start; enter ENDLESS ARCADE and verify classic play, adaptive
   four-world progression, sounds, leaderboard and original overlays remain
   unchanged.
9. Export a QA debug report; record input misses, observed FPS/hitches,
   any unexplained escapes, and the build commit SHA.

## Engineering verification

- `flutter test test/skyward_world_one_test.dart test/skyward_ui_test.dart`
- Both original CI APK artifacts must build successfully.
- No new Flutter dependencies, no Gradle edits, no physical-device writing.
- Do not infer gameplay fairness from CI alone. Human testing is mandatory.
- The `test/widget_test.dart` boilerplate is pre-existing and outside this
  scoped step; it has not been claimed to pass.
- The remaining six levels, carnival gameplay, special balloons and wind
  effects belong to later TJ-44 milestones.
