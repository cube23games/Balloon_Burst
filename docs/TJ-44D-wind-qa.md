# TJ-44D — Crosswind Alley / Wind Microbursts

## Goal and isolated gameplay scope
Play **Skyward World 1 Level 4** with lead balloons and a telegraphed,
bounded horizontal microburst. Levels 5–8 remain "In development".
Endless Arcade has **no wind controller** and no changed spawn/speed curves.

## Wind contract
- Wind runs only if the active Skyward level lists
  `SkywardHazard.microburst`; Level 4 is first.
- After gameplay begins: 4.0 seconds calm, 2.0 seconds directional
  warning, 3.0 seconds smooth gust, then 7.0 seconds recovery.
  Repeat warning/gust/recovery with **alternating** left/right direction.
- Main HUD displays `→ CROSSWIND INCOMING` or `← CROSSWIND INCOMING`;
  during wind, it displays `→ GUST! KEEP YOUR AIM` or its reverse.
- Normal balloons receive a bell-curve horizontal sway up to 0.34
  normalized x offset (~68px on 400px device), peaking halfway through
  each gust and returning smoothly to their natural x position.
- Never push an outer-edge balloon farther outward than its current
  natural position. The same `Balloon.xOffset` is used for drawing and
  touch hit-testing.
- Descending lead balloons remain on their existing trajectory; their
  warning, sound, catch, escape, and 5-point bonus are unchanged.
- No wind progression during intro, paused lifecycle, or after level end.
  Replay resets warning/gust schedule and direction.
- Level 4 objectives stay **24 pops + 2 lead catches**, max 2 escapes.
  Clearing Level 4 does not unlock unimplemented Level 5 gameplay.

## Test evidence expected
`test/skyward_wind_test.dart` exercises first telegraph, alternating
cycles, gust envelope, safe edge, reset, level gates, and HUD.
Existing Skyward/lead/Endless-menu tests run in CI.

## Device QA: Moto G (2026)
- [ ] Install the TJ-44D internal QA APK **as an update**; stars/coins survive.
- [ ] From Endless end screen, MAIN MENU works and Skyward Journey opens.
- [ ] Level 4 remains locked until Level 3 is cleared; then playable.
- [ ] Warning appears for ~2 seconds BEFORE motion, with direction arrow.
- [ ] Gust visibly drifts regular balloons left/right without instant
      teleport or impossible edge targets; normal taps still hit.
- [ ] First gust moves right, next moves left; calm period between.
- [ ] Lead balloon whistling, descending and 2-catch objective still work.
- [ ] Normal pops alone cannot clear without the two leads.
- [ ] Clear Level 4; stars save after relaunch; Level 5 stays gated.
- [ ] Replay Level 4 resets gust timing; exiting/re-entering has no
      leftover wind from previous session.
- [ ] Endless Arcade still has original spawn/rise behavior with **no**
      wind warning or horizontal gust.
- [ ] Export one Level 4 and one Endless debug report; record any hitches,
      escaping balloons, surprises or fairness complaints.

## Branch & release gates
Built on TJ-44C1 menu and TJ-44S stable signing branches, isolated from
`main` until green CI and human device QA. No main merge or public
production release in this milestone.

## Post-QA tuning (TJ-44D2)

The November 8 on-device report confirmed alternating, warned gusts but
described the 0.18 normalized movement as barely perceptible. Peak sway
increases to 0.34 (~68px at 400px screen width), with the existing easing,
safe-edge bound, advance warning, and no wind on descending lead balloons
or Endless Arcade. No additional particles/render passes were added.

Hitch logs now include wind phase and normalized sway at the time of the
frame gap. Initial QA baseline: Skyward L4 11 hitches / 44.5 active seconds;
Endless 10 hitches / 74.2 active seconds. Distinct runs; this comparison
does not establish wind as the cause. Re-test with the new signed QA APK.
