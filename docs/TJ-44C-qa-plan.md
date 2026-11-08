# TJ-44C — Whistle Drop: descending lead balloon

**Status:** Development branch / draft PR only. No merge to main.
**Parent QA baseline:** TJ-44B `5f9b09fa0794ff2df2bb6bb94d6ff8eb73623746`.
Moto G 2026 / Android 16 TJ-44B tests: all eight functional checks passed.
Historical World 1-4 speed settings are unchanged.

## Implemented in this candidate

- World 1 **Level 3: Whistle Drop** is selectable after Level 2 is cleared.
- Objective: >=20 confirmed pops, including **2 confirmed descending lead catches**.
- Lead target: metallic Pb marking, red down arrow, gold outline and motion streaks.
- Lead appears from the top of the screen, moves down at a controlled speed,
  and escapes only after crossing the **bottom** of the viewport.
- Countdown warns in the objective HUD before an incoming lead.
- Original synthesized downward-sweeping `lead_whistle.wav` plays on spawn
  when sound is enabled, never as the sole warning.
- One lead at a time; first appears after ~3 seconds of active level gameplay,
  then repeats at ~6.5-second intervals when no lead is visible.
- Lead pop awards 5 score points (normal balloon awards 1) and contributes
  exactly **one lead catch** plus **one popped balloon**.
- A lead escaping without being popped counts toward the level escape limit,
  except when existing Shield or mercy protection applies.
- For TJ-44C the lead takes **one tap**; armor/multiple-hit variants will be
  evaluated separately after touch accuracy and fairness QA.
- Level 4+ remains gated until wind/chain mechanics exist.
- Lead spawns only via the Skyward scheduler: Endless Arcade weighted random
  spawns ignore `spawnWeight=0` lead entries.

## CI checks

- `flutter test test/skyward_world_one_test.dart test/skyward_ui_test.dart test/skyward_lead_test.dart`
- Existing public and internal QA Android APK builds and artifact upload.
- Test properties: schedule repeat while active; warned spawn; reversed exit;
  lead catch credit; level 3 gating; no lead in weighted random pool.

## On-phone QA checklist

1. Confirm Skyward Levels 1 and 2 and Endless Arcade still work as before.
2. Finish Level 2 and open Level 3, **Whistle Drop**. Check Levels 4–8 remain gated.
3. With sound enabled, confirm a descending whistle on lead spawn; mute and
   verify there is **still a visible incoming warning**.
4. Confirm the metallic Pb-marked balloon falls rather than rises, and can be
   popped with a single fair tap. Confirm visibly higher score reward.
5. Confirm Level 3's LEAD counter increases only when the lead is popped;
   normal pops do not count. 20 normal pops alone must **not** clear Level 3.
6. Let one lead escape bottom: confirm escape counter increments and the next
   lead eventually returns. This must not be misreported as an upward escape.
7. Clear Level 3 using >=20 total pops and >=2 lead catches. Verify stars,
   return to map, persistence after app restart and that Level 4 is gated.
8. Compare the performance debug report with TJ-44B: 9 hitches in 25.4s
   Level 2, 12 hitches in 59.8s Endless. Report hitch counts, FPS,
   pop accuracy, unexpected misses and any audio-related stutter.
9. Keep auto-tap disabled; report shield/revive use if any. Share both the
   completed Level 3 report and an Endless regression report.

Do not merge the branch based only on green compilation. Real device QA
determines whether descent speed, warning lead time, and touch hitbox are fair.
