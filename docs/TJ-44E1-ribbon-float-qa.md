# TJ-44E1 — Loose Ribbon Visual & Independent Float

## Source of change
Player Moto G Android 16 review of TJ-44E #9 after signed build #68:
- **PASS** signed APK updated without data loss, Level 5 all 3 stars, Level 6 gated.
- **PASS** one ribbon tap produces two pops and one chain event.
- **PASS** stronger Level 4 wind is perceptible and fair, Endless unchanged.
- **Visual issue** ribbon balloons resemble dumbbells: both move together,
  the link is straight and joins their centers, round bodies lack knots.
- Manual test of 25 ordinary pops without any chains is not practical given
  the Level 5 escape limit. The pure level test already asserts that case.

## Fix in this isolated PR
- Preserve exact ribbon group IDs, live-only sibling pop logic, score and
  tap accounting, pair spawn timing, safe escape count and unlock logic.
- Give two balloons distinct oscillation phases and a 10px initial height
  stagger; they move naturally relative to each other with a shared vertical
  rise speed so the tether does not stretch indefinitely.
- Skyward-only ribbon sway amplitude 0.085 normalized (regular balloons
  remain 0.035). Existing collision/hit tests use the same Balloon.xOffset
  written by the movement loop as the painter uses.
- Replace center-to-center straight cyan/yellow bar with a curved sagging
  gold silk strip, a subtle cloth flutter and soft shadow. Attach near the
  balloons' lower inner edges.
- Paint balloon-shaped tapered bodies with tied knots and trailing strings
  instead of featureless cyan discs.
- Change no world objectives, currency, Endless Arcade movement, UI route,
  Gradle signing or auth secrets. No main merge; draft integration only.

## Automated checks
- Existing 25-normal-pops-without-chains test must still pass.
- Verify ribbon partners differ in age-sway while remaining visibly close,
  shared ascent, link identity through copies and pops.
- Render link through Flutter CustomPaint test with no painter exceptions.
- Full Skyward, lead, wind, main menu, ribbon test suite + signed APK CI.

## On-device follow-up
- [ ] Update-install the next signed QA APK over build #68 (do not uninstall).
- [ ] A connected pair now looks like two freely floating balloons with a
      curved, gently sagging ribbon (not a rigid dumbbell handle).
- [ ] Their positions oscillate independently, with stable tapped hitboxes.
- [ ] One tap still pops BOTH, updates POPS +2 and CHAINS +1.
- [ ] Pair escape counts as one penalty; Level 5 star/progress persists.
- [ ] Level 4 wind and Endless remain unchanged.
- [ ] Export fresh Level 5 debug report for hitch comparison.

## Initial QA telemetry from provided report
Level 5: 4 hitches / 37.0 seconds (6.5/min), 22 pops, 95.65% accuracy,
4 confirmed ribbon-chain events, no chain escape recorded.
Level 4 strong wind: 11 / 44.1 seconds (15.0/min), two hitch samples
occur during gust, others during calm/warning or startup.
Endless: 10 / 94.0 seconds (6.4/min), wind=off. Independent runs, not an
experimental A/B comparison; none establishes causation.
