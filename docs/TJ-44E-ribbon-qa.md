# TJ-44E — Ribbon Chain Reactions (Skyward World 1, Level 5)

## Scope
- Unlock **Level 5: Ribbon Reaction** once Level 4 is cleared.
- Level 5: **25 total pops, 2 triggered chain reactions, max 2 escapes**.
- Levels 6–8 remain unplayable until the mixed-hazard level implementations.
- Endless Arcade's existing weighted spawner, difficulty and normal tap
  accounting are unchanged. Ribbon balloons have spawn weight 0 and only the
  active Skyward ribbon controller can introduce them.

## Play mechanic
A distinct **cyan/gold ribbon pair** enters together 4 seconds after gameplay
begins. Both partners share a group ID, enter at the same altitude and sway
together. The renderer draws a link between them and stripes their surfaces.
Tapping either member causes the untouched partner to pop automatically:

- **one physical human tap**, not two;
- **two physical popped balloons** in the spawner and engine lifecycle;
- **one chain reaction** for the active Skyward objective;
- +1 score per balloon, with secondary score/particle effects limited to a
  small burst to minimize potential hitch impact.

After no linked ribbon remains, the controller waits 5.5 active gameplay
seconds before spawning another pair. An isolated ribbon, a popped balloon,
or a normal balloon does **not** count toward chain reactions. Only living
members of the identical group are secondary pop candidates. If both
balloons escape, count **one escape penalty for the linked pair**, including
across adjacent frames; this is one missed opportunity.

Replay clears the ribbon schedule and escape-group state. Intro, lifecycle
pause and ended runs do not advance the schedule. Unmodified lead balloons
cannot be included in a chain group.

## Independent automated verification
`test/skyward_ribbon_test.dart` verifies:
- zero weight in normal spawn pool, Level 5-only hazard gate;
- spawn delay, unique pair ID, spacing and one active group;
- ribbon ID persistence through movement and pop;
- only living peers in the same group can chain;
- grouped escapes, proper reset and new run;
- exactly one tap for a two-pop reaction, two reactions for Level 5 clear;
- Level 4 saved progress unlocks Level 5 without unlocking Level 6;
- HUD chain requirement and count.

Existing Skyward, lead, wind, Endless-menu tests remain in signed CI.

## Device QA — Moto G 2026 Android 16
- [ ] Install **internal QA** APK as an **update** over the existing app
      without uninstalling; confirm saved coins and all prior stars retained.
- [ ] Level 5 unlocks after Level 4 completion; Level 6 remains gated.
- [ ] Level 5 starts with 25 POPS and 0/2 CHAINS in HUD.
- [ ] Cyan/gold two-balloon group enters with visible ribbon connection.
- [ ] Tap one pair member: both pop, extra score/particles appear,
      CHAINS increments by one, and POPS advances by two.
- [ ] Pop normal balloons without links: CHAINS **does not** increment.
- [ ] Pop 25 normal balloons first: cannot win without two chains.
- [ ] Two successful chain groups + at least 25 pops clear Level 5.
- [ ] Let one entire pair escape; one escape is counted, not two.
- [ ] Replay Level 5 resets counters and ribbon schedule.
- [ ] Exit/relaunch game: Level 5 stars and progress remain saved.
- [ ] Level 4 stronger wind is noticeable but retains fair tap targets;
      the 2s warning still precedes gusts, and lead catches are unchanged.
- [ ] Endless Arcade has **no ribbon pairs**, no wind, same rise/spawn/score.
- [ ] Save Level 5, Level 4, and Endless debug exports, especially
      `PERF HITCH` lines and `SKYWARD RIBBON CHAIN` events.
- [ ] Revisit Endless results MAIN MENU, Replay, Revive and Leaderboard.

## Release and integration
Branch is stacked on draft #8 (wind tuning), #7 (wind), #6 (menu),
#5 (permanent signing), and earlier Skyward work. No merge to main until
manual QA and dependency-order integration. The public release artifact
must not enable QA auto-tap. No passwords or keystores belong in the PR.
