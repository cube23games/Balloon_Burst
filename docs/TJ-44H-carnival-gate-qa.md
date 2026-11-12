# TJ-44H — Carnival Gate (World 1 final challenge)

## Starting authority
**Source**: `main` SHA `334f7f5fce5b08fcb0ed44541ca0b345642f67ea`, exactly the target of annotated recovery tag `tj44g-main-integrated-device-verified`. Fully green permanently signed CI #81 and Moto G 2026 device QA accepted, **21/24 saved stars, bank 536 at last owner report**. At milestone start the PRIVATE `cube23games/Balloon_Burst-backup` mirrored **17 branches and 132 tags** with identical SHA refs; don't change it before TJ-44H acceptance.

## Official Level 8 rules — unchanged
These were defined in the original World 1 design catalog before activating this level.

| Item | Requirement |
|---|---|
| Level title | **8 · Carnival Gate** |
| Physical pops | **36** |
| Actual descending lead catches | **3** |
| Ribbon chain reactions | **3** |
| Escape allowance | **1**; second escape fails |
| Hazards | Lead whistle/drop + alternating crosswind + organic linked ribbons |
| Stars | Existing 1–3-star tap accuracy/zero-escape rules |
| Unlock | Level 7 must have at least one saved star |
| World completion | Levels 1–8 must each have at least one saved star |

**Core contract:** 36 physical pops, 3 distinct lead catches and 3 linked-pair events are all required; a single ribbon tap pops 2 physical balloons but is 1 successful human tap and 1 chain. A lead catch is not a chain. Two escaped balloons in one run end the attempt, but a linked pair counts one escaped group under existing controller rules. No new per-frame physics, special-currency bonus, altered spawner, or separate tap-streak policy.

## New UI/progression
- The World 1 map now allows levels **1–8** to be selected **only if their previous level has a saved clear**. Level 8 is no longer labeled In development.
- The Level 8 map tile exposes pops, lead catches, chains and the strict maximum 1 escape.
- Level 8 victory shows **WORLD 1 COMPLETE!** and **CARNIVAL GATE OPENED!** plus stars and the normal replay/map controls. No `NEXT LEVEL` action (no Level 9).
- The map banner changes from "clear Level 8 to open the gate" to **CARNIVAL GATE OPENED! World 1 complete** only when all eight official progress slots have a saved clear. Completion is persisted through the existing `skyward.world1.stars.v1` key; no destructive migration.
- The gate opening is a **World 1 achievement**, *not* a promise that a separately playable Carnival minigame already exists. An expansion can be designed later.
- An optional one-time-per-victory `SKYWARD CARNIVAL GATE OPENED` system event records popped/lead/chain/escape/star totals at the actual game victory boundary, then the existing app completion callback saves stars.

## Automated acceptance
The existing full Skyward + Endless regression suite remains in signed CI; new `test/skyward_carnival_gate_test.dart` checks:
- Official Level 8 rules and no ninth level.
- 36 physical pops from 33 legitimate taps (27 normal, 3 lead, 3 double-pop chains).
- 36+ ordinary pops cannot substitute for lead catches or ribbon chains.
- One escape can win with at most 2 stars; a second escape fails and freezes counters.
- Saved 21/24 stars permit entry, but not World 1 completion until Level 8 is cleared.
- Progress restored from saved stars preserves World 1 completion; interrupted star sequences cannot forge the gate.
- HUD shows 36/3/3, escapes 0/1, both lead and crosswind warnings.
- Level 8 map tile remains locked after Level 6 and playable after Level 7.
- Victory overlay celebrates World 1; failed runs do not; there is no Level 9 action.
- Reopened 24/24-star map correctly shows the completion banner.

## Moto G 2026 — human acceptance checklist
- [ ] Signed CI fully GREEN (Flutter tests + public and internal QA signed APKs; verified certificate, increasing versionCode, both uploaded artifacts).
- [ ] Install **internal QA APK** over existing #81; **never uninstall/clear data**. Check 21 previous stars and current coin bank (last known 536) survive.
- [ ] On the World 1 map, Level 8 **Carnival Gate** is selectable, with `36 pops · Lead 3 · Chains 3 · Max 1 escapes`. Previous seven levels still show saved stars.
- [ ] Enter Level 8; HUD displays `POPS 0/36`, `ESCAPES 0/1`, `LEAD 0/3`, `CHAINS 0/3`.
- [ ] Hear whistling lead warning, catch 3 descending lead balloons, see fair alternating left/right wind, and pop 3 flexible ribbon pairs. Each ribbon pair gives +2 pops and +1 chain; each lead catch gives +1 lead. With two simultaneous warnings, neither HUD counter is obscured.
- [ ] Complete all 36 pops and three of each special objective with **no more than one escape**; receive **WORLD 1 COMPLETE! / CARNIVAL GATE OPENED!** and stars. Confirm **no NEXT LEVEL button**.
- [ ] Return to the map, verify World 1 completion banner, appropriate total stars (up to **24/24** if three-star win), and all eight tiles unlocked. Fully close and reopen: saved stars and gate state persist.
- [ ] Replay Level 8 and verify lead/wind/ribbon timers, group IDs and objectives restart; no stale previous victory.
- [ ] Existing Level 7 remains playable, and Endless Arcade has **no special Skyward wind/ribbon/lead hazards** and its Main Menu works.
- [ ] Export final Level 8 and Endless debug reports. Look for `SKYWARD CARNIVAL GATE OPENED`, lead/ribbon/wind events, hitches and any escapes. Watch hitch rate for new regressions.
- [ ] Do **not** deliberately fail a level merely to test two escapes: deterministic automated tests already enforce that rule.

## Release governance
Keep TJ-44H PR **draft** until signed CI + human device QA accept the exact commit. Do not merge directly into `main`, create a verified milestone tag, publish to Google Play, or synchronize unaccepted work to the private backup. After acceptance, use a history-preserving merge, freshly verify the signed `main` APK and install-over-update data retention, then create a separate annotated main tag and non-force private mirror synchronization. Current `main` CI is pinned to proven Flutter **3.47.9** for Gradle 8.14 compatibility.
