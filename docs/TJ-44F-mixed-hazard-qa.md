# TJ-44F — Spiraling Skies: Level 6 mixed hazards

## Scope and source of truth
Stacked on **TJ-44E1 floating ribbon visual** and its fully green signed
build #69. This milestone combines previously accepted wind and linked
ribbon mechanisms in World 1 **Level 6: Spiraling Skies**. No changes to
Endless Arcade spawner, scoring, difficulty, leaderboard, or to existing
level objectives/signing keys.

World 1 catalog already specifies:
- **28 physical pops**, including auto-popped linked partners.
- **2 genuine ribbon chain reactions**, not just 28 ordinary pops.
- **Maximum 2 escaped opportunities**; third escape ends the run.
- **Wind + ribbon hazards**; no lead-balloon objective until Level 7.
- Level 6 unlocks only when Level 5 has been cleared; Level 7+ stays
  unimplemented even if the player clears Level 6.

## Interaction and fairness contract
- Intro finished => wind's existing 4-second calm, 2-second direction
  warning, 3-second gust and 7-second recovery run on active gameplay time.
  Direction alternates after each gust. HUD shows directional warning and
  CHAINS counter **at the same time**.
- Ribbon pairs use existing Skyward-only timed spawn, curved sagging gold
  tether, individualized buoyant sway, balloon-like bodies and one-tap,
  two-pop gameplay. No ribbon spawn weight in Endless Arcade.
- During a gust, ordinary balloons retain their existing individual wind
  cap. A linked pair shares the **same** safe, bounded wind shift,
  constrained by its nearest edge member. The two partners' independent
  natural sway and spacing are preserved so the ribbon doesn't stretch
  unnaturally or force a balloon offscreen.
- Both linked balloon hit targets follow their actual rendered x/y
  coordinates, not the connecting ribbon. A single tap on a live
  linked member pops its live partner, with one player tap and one chain.
- An entire ribbon pair escaping charges one missed opportunity. No
  extra lead balloons in Level 6. Level 4/5 and Endless must retain
  their previous hazards and behavior.
- Replay resets BOTH wind and ribbon controller schedules.
- Completion persists stars using the existing Skyward progress store.
  The original permanently signed certificate and increasing
  versionCode preserve installed game progress through APK updates.

## Automated acceptance
`test/skyward_mixed_hazards_test.dart` validates:
- official Level 6 objectives/hazards, Level 7 lead gating;
- quiet warning interval and simultaneous wind+chain HUD;
- right- and left-gust group shift bounds and shared displacement;
- wind never stretches a pair / breaks chain group identity;
- 28 ordinary pops alone cannot win without two real chains;
- Level 5 progress unlocks Level 6 and keeps Level 7 gated;
- level map includes Level 6 chain objective and selectable tile.

Existing World1/UI, lead, wind, ribbon, Endless Main Menu unit/widget
tests remain in the signed CI workflow. Both public and internal QA APKs
must build with matching validated signer identities and versionCode.

## Phone QA — Moto G (2026), Android 16
- [ ] CI green; install **internal QA APK** over build #69, never
      uninstall or clear data. Confirm 15/24 stars and balance persist.
- [ ] Level 6 appears as a playable tile after Level 5 clear, with
      28 pops and 2 chains; Level 7 "Leadstorm" still says In development.
- [ ] Enter Level 6. Confirm objective HUD shows POPS 0/28 and CHAINS 0/2.
- [ ] First ribbon pair appears with the accepted floppy curved tether.
      During the warning it does not suddenly jump.
- [ ] First gust pushes linked pair right, second pushes it left; silk
      ribbon remains attached with independent wobble and bounded motion.
- [ ] Tap a linked balloon DURING a gust; both pop, POPS +2, CHAINS +1,
      no false misses, hitboxes track moving balloons.
- [ ] Pop normal balloons; they sway in the expected wind and do not
      increment CHAINS. 28 ordinary pops alone cannot satisfy chain goal
      (already covered by deterministic unit test; no need to risk
      repeated escape-limit failures for this case).
- [ ] Clear with 28+ pops and 2 chains, under 3 escapes; Level 6 stars
      persist after fully closing and reopening the app.
- [ ] Replay Level 6; both gust warning/direction and ribbon schedule
      restart cleanly; no stale chain groups.
- [ ] Repeat one Level 5 ribbon pair (no wind) and Level 4 wind plus
      lead catches (no ribbons).
- [ ] Endless Arcade has NO wind warnings, NO ribbon balloons and still
      reaches its normal results screen / Main Menu.
- [ ] Export one Level 6, Level 5 and Endless debug log. Check
      `SKYWARD WIND phase`, `SKYWARD RIBBON SPAWN windPhase`,
      `SKYWARD RIBBON CHAIN`, performance hitches, escapes and misses.

## Integration guardrail
This draft is stacked on PR #10 (TJ-44E1), #9 (TJ-44E), #8 (TJ-44D2),
#7 (TJ-44D), #6 (TJ-44C1), #5 (TJ-44S) and prior Skyward branches.
Do **not** merge straight into main or publish as Play production; wait
for coordinated dependency-order integration and device QA.
