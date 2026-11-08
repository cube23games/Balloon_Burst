# TJ-44 — Skyward Journey / World 1 implementation contract

Status: **TJ-44A foundation in development; NOT PLAYABLE YET**. This branch contains
the World 1 mission catalog and pure-Dart progression rules only.

## Verified baseline (do not rewrite)

- Repository: `cube23games/Balloon_Burst`
- Integration base: `main`, commit `60267594c9ad90e8e1e32be6d0a8b9c5d0fad7b6` (TJ-43H1).
- Last baseline CI success: run `34763688207`, public and internal QA APKs.
- The GitHub repository's configured default branch was `accuracy-expose-v1`
  when this initiative started. All TJ-44 work MUST explicitly base on `main`.
- Do not adjust the four historical world speed multipliers, spawn intervals,
  thresholds, or TJ Engine adaptive progression before redesigned-mode QA.
- Preserve existing endless arcade mode and its debug telemetry as a comparison.
- No local Flutter/Android builds in Termux. Build APKs using existing GitHub Actions.

## Product goal

New **Skyward Journey** mode: eight short, objective-based levels inside World 1,
progressively introducing lead balloons, microburst winds, and ribbon-chain
reactions. Completing the eighth level unlocks a **Carnival Gate** checkpoint.
Carnival dart gameplay is a separate later implementation milestone.

Players should have a clear reason to complete the next level and replay for
three stars. A tap must remain snappy; complexity belongs in moving targets
and specific goals, not difficult controls.

## World 1 catalog (initial tuning hypotheses)

| Level | Title | Minimum pops | Additional goal | Environmental mechanics |
| --- | --- | ---: | --- | --- |
| 1 | First Flight | 12 | None | Original familiar targets |
| 2 | Cloud Combos | 20 | None | Combo-focused presentation |
| 3 | Whistle Drop | 20 | Catch 2 leads | Descending lead balloons |
| 4 | Crosswind Alley | 24 | Catch 2 leads | Lead + microburst |
| 5 | Ribbon Reaction | 25 | Trigger 2 chains | Linked balloons |
| 6 | Spiraling Skies | 28 | Trigger 2 chains | Microburst + chains |
| 7 | Leadstorm | 30 | Catch 3 leads + 2 chains | All three mechanics |
| 8 | Carnival Gate | 36 | Catch 3 leads + 3 chains | All three, max 1 escape |

These numbers are placeholders until human playtesting. They do **not** replace
or mutate the existing four-world endless arcade tuning.

## Gameplay contracts

- Level objectives count **confirmed popped balloons**. A linked cluster
  counts each popped balloon toward the pop target, but a triggered chain
  counts once toward the chain objective.
- A **successful tap** increments hit accuracy by one, regardless of
  the number of balloons bursting in the resulting chain.
- A lead catch is credited only for a successfully popped descending
  lead balloon, never for its spawn or offscreen escape.
- Failed taps increment misses; escaped targets increment escapes separately.
- Exceeding a level's allowed escapes fails its attempt.
- On completion: 1 star always; 2 stars at >=88% successful tap accuracy;
  3 stars at >=95% accuracy with zero escaped balloons.
- Players unlock level N+1 when level N has at least 1 star. Replay retains
  the highest star count per level. World 1 completion unlocks Carnival Gate
  access; it does **not** mean the carnival minigame exists yet.
- Save and load are future integration tasks; TJ-44A does not touch wallet,
  SharedPreferences, current score tables, or save format.

## Safe integration sequence — new, separate milestones

1. **TJ-44A (this branch)**: freeze H1 SHA, eight-level catalog, isolated
   event/score/unlock rules, unit tests. No modification of shipped arcade path.
2. **TJ-44B**: add mode selection and level-start / level-end UI. Route confirmed
   pop/miss/escape events from current `GameScreen` / `TapHandler` into a
   separate `SkywardLevelRun`. Preserve old endless mode behavior.
   Completion/failure must stop the active level cleanly and offer replay/next.
3. **TJ-44C**: implement a descending lead balloon with visible warning,
   sound cue, recognizable appearance, correct reverse-direction escape rules,
   and explicit hit-radius policy. Define two-hit armor only after testing
   collision and score semantics.
4. **TJ-44D**: implement an early visible wind telegraph and smooth, bounded
   microburst forces. Clamp travel so touches remain fair; include a
   reduced-motion setting and screen-edge safeguards.
5. **TJ-44E**: implement linked ribbon chains and atomic burst accounting.
   One tap may pop multiple balloons, but lifecycle/QA events must be consistent
   and never double-credit rewards.
6. **TJ-44F**: add progression persistence, carnival gate reveal, performance
   budgets, human QA capture, and balance iteration. Carnival darts, sonic boom,
   shops, and sky boss follow as independent workstreams.

## QA acceptance gates

- Unassisted play: auto-tap off, shield/revive off, same phone/OS recorded.
- Every introduced mechanic has discoverable visual feedback and an accessible
  alternative to audio-only warnings.
- Check touch miss rate, near-misses, FPS/hitches, level completion time,
  per-level failure rate, and offscreen escape fairness.
- Never penalize an escaping bomb that should be safe under preexisting rules.
- Respect capped visual-effects counts and performance on budget Android devices.
- Add regression tests before altering core run lifecycle authority.
- Build both existing public/QA APKs in GitHub Actions, and execute the new
  `test/skyward_world_one_test.dart` tests before merging. Current CI build
  workflow does not run Flutter tests automatically, so green APK builds alone
  are not evidence the unit tests passed.

## Rollback and release discipline

Do not merge an untested mechanic into `main`. Treat H1 as the guaranteed
baseline. A draft PR is the integration checkpoint. Code changes remain
independently revertible. No new dependencies, Gradle changes, or workflow
edits during the initial catalog milestone.
