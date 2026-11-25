# TJ-45G — Frame-start, UI-build and Debug HUD transition investigation

Status: research-only QA build. This is NOT a VSync controller or gameplay fix.
Base: signed-green TJ-45F commit 0dc6f99eb3f15cddbc44eb5cf82cc03e41aea79c.

Evidence: Matched TJ-45F trace/frame report found frame #2319 UI build 47.75ms (with ~30.62ms app-main CPU) near report export, plus other frames with VSync-to-build waits of 20–47ms. AppRoot displays DebugScreen OVER the still-mounted GameScreen. We need to distinguish steady gameplay from entering the debug overlay.

New bounded instrumentation in QA only: AppRoot.build, GameScreen.build, GameScreen LayoutBuilder callback, and DebugScreen.build synchronous Dart builder durations. Counters record sample count, >16.667ms, mean, max, four longest per stage. Records also carry whether debug was requested/visible and elapsed monotonic milliseconds since navigation request. Eight latest navigation markers distinguish opening/closing from first Flutter post-frame callback.

IMPORTANT: selected builder times do NOT equal Flutter FrameTiming.buildDuration (which includes framework and other work). Post-frame callbacks are NOT physical display presentation. Timeline.startSync / instantSync may not be visible in Perfetto's Android System Tracing: verify before claiming them; do not join raw Stopwatch epoch to FrameTiming or Perfetto without alignment.

Dedicated artifact: balloon-burst-internal-qa-ui-build-apk. Includes existing TJ-45F flags, Aura V2 and TJ45G_UI_BUILD=true. All prior seven variants remain with unchanged build defines. Verify same permanent signature and incrementing versionCode. Do not change game logic, animation, particles, sound, stars, coins, app package or save keys. Production main and private backup remain frozen at f1b749e4ac3d87233423d7c8a73bd4e73653beaa; draft PR only.

After FULL GREEN CI: install-over without clearing data. First Endless run 60–90s sound on/auto-tap off without opening HUD until after gameplay; then open Debug HUD and export. Second Endless run same approximate duration, intentionally open/close HUD once DURING play, continue ~20s, then export. Compare the two reports' qaUiBuild and qaUiNavigation fields to Flutter frame-phase worst records, noting async timing batches may include transition frames. Confirm all 24 stars and saved coins. Screenshot only after test. Optional Perfetto trace if more exact correlation is required. STOP if signing/test gate fails or graphics/audio/state differ. No production promotion or custom VSync loop based only on this probe.
