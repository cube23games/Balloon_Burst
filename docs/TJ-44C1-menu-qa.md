# TJ-44C1 — Endless results Main Menu regression

## Why
Player QA on Moto G (2026, Android 16) found that the Endless Arcade
final-score overlay offered replay, revive, shield and leaderboard, but no way
back to the opening mode chooser without relaunching Balloon Burst (#4).

## Patch
- The Endless-only `RunEndOverlay` results screen gains a visible
  `MAIN MENU` action, below Replay and before the Shield offer.
- `GameScreen` only responds when the Endless run is already ended. It
  stops the gameplay ticker and delegates navigation; it does not end,
  replay, credit, or submit the run again.
- `AppRoot` passes the callback through to `BalloonBurstApp`, which
  returns to `AppView.start`; the old gameplay widget disposes normally.
- Existing replay, revive, shield purchase and leaderboard actions are
  not modified.

## Automated acceptance
`flutter test test/endless_main_menu_test.dart`: both escape and victory
results display MAIN MENU once the score presentation completes. Tapping
calls the menu callback exactly once without invoking replay or leaderboard.
Existing Skyward tests run alongside this new test in CI.

## On-device QA (pending)
1. Finish an Endless Arcade run by escapes/misses, confirm MAIN MENU present
   and existing coins/leaderboard/Replay/Revive remain functional.
2. Tap MAIN MENU and land on the mode chooser.
3. Tap Skyward Journey and check prior level progress remains saved.
4. Return to Endless Arcade and confirm a fresh run starts.
5. Repeat on a victory result if practical; confirm no duplicate reward.
6. Confirm the QA APK installs as an update without clearing saved data
   thanks to TJ-44S stable signing.

## Integration
Based on draft signing branch `tj-44s-stable-apk-signing`.
This is a stacked draft patch, not a mainline merge. Game balance untouched.
