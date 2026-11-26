# TJ-45F — Android Frame Presentation Investigation

**QA-only — not a VSync fix and not a production release.**

TJ-45E measured Flutter frame stages, but not physical display presentation.
TJ-45F uses two sources **without root or a PC**:

1. Optional Android **Window.FrameMetrics** for the Activity host window,
   with deadline comparison. Important limitation: Flutter's SurfaceView
   renders on a separate surface. Window metrics can be absent or irrelevant
   to the Flutter game surface, and are **not actual-present timestamps**.
2. Android's **on-device System Tracing** Perfetto FrameTimeline for genuine
   app and SurfaceFlinger expected/actual presentation evidence. This is the
   primary test for the game's visual hitch.

## Dedicated signed QA artifact

`balloon-burst-internal-qa-android-presentation-apk`

Build flags: `ENABLE_QA_AUTOTAP=true`,
`TJ45B_GLOW_AURA_V2=true`, `TJ45D_FRAME_DIAG=true`,
`TJ45E_FRAME_PHASES=true`, `TJ45F_ANDROID_PRESENTATION=true`.

Only TJ-45F installs the native on-demand listener. It uses a background
HandlerThread and bounded counters. No additional Android permissions,
second frame clock, timer, gameplay changes or performance reduction.

The debug report's Android section begins
`qaAndroidWindowFrameProbe: enabled`. It may legitimately report zero
host window frames; that is **not proof of no game jank**.

## Real on-phone frame presentation trace (critical test)

1. Open Android Settings > System > Developer options > **System Tracing**
   (or use Settings search). Enable a trace-to-file; select relevant
   categories including **Graphics**, **View**, **Window Manager**, and
   **CPU scheduling**, if shown. Source/label availability varies by OEM.
   Enable **FrameTimeline** if the options expose it; verify actual trace.
2. Start recording from the tracing Quick Settings tile or notification.
   Play a busy **20–30 second segment of Endless Arcade** with sound ON,
   auto-tap OFF. Avoid taking screenshots during the recorded segment.
   Capturing a shorter segment reduces trace size and recording overhead.
3. Stop tracing from the System Tracing notification, and use the system
   **Share** option to export the `.perfetto-trace` file. Android 10+
   supports this format. Do not assume FrameTimeline was captured until
   inspected. **System traces may include private app/system metadata**;
   review before sharing.
4. Export Balloon Burst's detailed debug report for that play session.
   It will contain existing TJ-45E Flutter phases and the optional
   host-window Android metrics. The timestamps are from different clock
   domains and must not be paired without trace-based clock alignment.
5. Confirm all 24 World 1 stars and the saved bank. Install-over ONLY;
   never uninstall or clear data.

## Interpretation

Inspect `actual_frame_timeline_slice` and
`expected_frame_timeline_slice` in Perfetto if the trace contains them.
App-related jank means investigate app producer/scheduling. SurfaceFlinger
jank indicates compositor/display-side delay. Both require further
event correlation to establish causes. A Flutter frame with a long total
span is not guaranteed to have missed actual physical presentation.

The on-device tracing capture may itself affect smoothness. Note that in
the report. A native Choreographer/VSync controller remains out of scope
until strong evidence shows the existing Flutter scheduling architecture
is deficient.

## Preservation gate

Keep Aura V2, all particles, sound, input, physics, stars, coins, and
saves unchanged. All seven APKs must have identical signing certificate
and incrementing CI versionCode, with green Flutter/unit/Android build.
No main merge, backup push, tags or public release without owner approval.

Sources:
- https://developer.android.com/topic/performance/tracing/on-device
- https://perfetto.dev/docs/data-sources/frametimeline
- https://developer.android.com/reference/android/view/FrameMetrics
