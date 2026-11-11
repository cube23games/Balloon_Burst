# TJ-44G — World 1, Level 7: Leadstorm

## Authoritative base
- Starts at `main` commit `66150f9f283b0e4975732b57d3c8a8fdd9d1f76c`, independently verified against the immutable annotated tag `tj44f-main-integrated-device-verified`.
- That commit has full signed CI #77 and Moto G Android 16 device acceptance for Skyward Levels 1–6, saved coins/stars, Endless Main Menu, and Level 7 gate.
- PRIVATE `cube23games/Balloon_Burst-backup` retained the entire approved history and integration tag (15 branch refs, 131 tag refs) before TJ-44G. Do not synchronize unapproved work to the recovery mirror prematurely.

## Gameplay and safe composition
Level 7 was already defined in the World 1 rulebook. This PR activates the existing independent hazard controllers together rather than inventing a new physics mechanic:

| Goal | Level 7 rule |
|---|---|
| Popped balloons | 30 physical pops; linked partner counts physically but not as an extra player tap |
| Descending lead catches | 3 actual tapped lead balloons |
| Ribbon chain reactions | 2 genuine linked partner-pop events |
| Allowed escapes | 2; the third fails the run |
| Hazards | Lead balloons + right/left microburst wind + independently floating linked ribbons |

- Lead: descends from top, whistles and warns before spawning. Existing Level 3/4 behavior and lead 5-point bonus remain unchanged. As established in Level 4, lead motion is exempt from lateral gust displacement.
- Wind: keeps the existing 2-second directional warning and smooth alternating gusts; the normal balloons drift individually. Linked pairs use the Level 6 **shared bounded displacement**, preserving their organic rope shape and tap hitboxes.
- Ribbon: linked cyan/gold pair remains Skyward-only, one tap triggers two physical pops but one human tap and one chain reaction; ribbon siblings are selected solely by `ribbonGroupId`, never proximity to a lead balloon.
- Each hazard controller's timer and cap remains independent. Only one live lead and one live linked pair can be scheduled at once; the normal balloon spawner remains unchanged.
- All goals are **AND** requirements. 30 ordinary pops with 0 chains or 0 lead catches cannot win. A wind gust does not count toward catches/chains.
- Level 7 unlocks after saved Level 6 clear; Level 8 `Carnival Gate` remains **In development** even after Level 7 is completed.
- Replay resets lead, wind and ribbon schedules. No change to existing signing, bank, revives, Endless modes or previous Skyward levels.
- HUD can show whistle and wind warnings simultaneously along with lead/chain counters. Map tiles now expose the lead catch requirement for any applicable level.
- New `SKYWARD LEADSTORM ...` debug logs are emitted **only when all three hazards are enabled**. `LEAD_SPAWN` logs current wind phase and active ribbon state; `RIBBON_SPAWN` logs wind phase and active lead; `OBJECTIVE` records special tap goals. Low-frequency events, no added per-frame renderer or particles.

## Automated regression gates
`test/skyward_leadstorm_test.dart` is added to signed CI alongside the established first six levels, stable signing and Endless tests:
- exact Level 7 goals/hazards and Level 8 gate;
- independent lead, wind and ribbon timing; one-live-entity caps;
- gusted ribbon pairs retain spacing and group identity;
- close/overlapping lead balloons never trigger a ribbon chain;
- tap and pop accounting stays separate (30 physical pops from 28 human taps);
- missing one goal prevents victory even with excess pops;
- ribbon pair escape counts once; separate lead escape counts normally;
- replay resets three controllers and clears cached escape groups;
- 18-star saved progress unlocks Level 7; 21 stars can unlock Level 8 *on the map*, but cannot make its unimplemented gameplay selectable;
- both warnings and both objectives render simultaneously without a widget exception.

## Moto G (2026) Android 16 — device QA checklist
- [ ] Signed GitHub Actions pipeline fully green, both APKs uploaded and signer/versionCode checks passed. Use **internal QA APK**, *never* public artifact for diagnostic runs.
- [ ] Install as an **update** on top of accepted build #77 without uninstalling or clearing data. Check bank **327 coins** and **18/24 stars** remain (unless you spent/earned coins since the report).
- [ ] Level 7 `Leadstorm` is playable after Level 6's 3 stars. Level 8 says In development.
- [ ] Level 7 HUD: `POPS 0/30`, `ESCAPES 0/2`, `LEAD 0/3`, `CHAINS 0/2`.
- [ ] Hear the descending lead whistle and see `↓ WHISTLE! LEAD INCOMING`. Watch both right and left wind warnings/gusts; when timers overlap, both warnings appear together.
- [ ] Catch **3 descending leads**, preserving the original 5-point lead reward. Lead does not suddenly shift sideways during gust.
- [ ] Pop **2 ribbon pairs** while gusts run; each advances POPS by 2, CHAINS by 1 and player streak by a single tap. The silk link stays flexible and does not stretch when gusted.
- [ ] Pop normal balloons and catch leads: neither may increment CHAINS. Pop ribbon pairs: neither may increment LEAD. Automated rule tests cover impossible 30-ordinary-pops-only cases without failing the live level by escape limit.
- [ ] Win at 30+ pops and all lead/chain goals before a third escape; confirm Level 7 stars persist after quitting/reopening.
- [ ] Allow one whole ribbon pair to escape; check only one escape charged. A lead escaping is a separate one. Do not require deliberately failing a run if it would cost progress.
- [ ] Replay Level 7: whistle, first gust direction, pair IDs, goals and schedules all reset. Levels 3–6 still behave unchanged.
- [ ] Endless Arcade has **no whistles, gust warnings or ribbon pairs**; results screen MAIN MENU still works.
- [ ] Export a Level 7 debug report after a mixed run, especially `SKYWARD LEADSTORM LEAD_SPAWN`, `RIBBON_SPAWN`, `OBJECTIVE`, `SKYWARD WIND`, `SKYWARD RIBBON CHAIN`, `SKYWARD LEAD CAUGHT`, `PERF HITCH` and active `windSway`.

## Safety and promotion
Draft PR only. Do not merge to main, create a milestone tag, delete refs, change repository default branch, synchronize unaccepted work to the private recovery mirror, or publish the game until signed CI **and** owner device acceptance are complete. Maintain one change per commit where practical. Existing release-signing key, GitHub Actions secrets, and encrypted offline signing-key backup are outside Git history.
