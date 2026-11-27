# TJ-45M — Clock-Epoch Integrity Correction

**Status:** QA-only measurement correction. No gameplay optimization.

## Evidence: why this fix exists

Signed TJ-45L CI #100 ran on the Moto G 2026. The matching original
debug report and Android Perfetto trace from Nov 26, 2026 show:
- 24/24 stars and 3,766 coins after the game run; progress intact.
- Nine valid anchors at run start and nine at report export.
- Run-start native BOOTTIME minus MONOTONIC offset agrees with the
  Perfetto trace's initial clock snapshot to within 654 nanoseconds.
- The offset differs by +210,545,651,695ns (~210.55 seconds) at export.
  Device suspend is consistent with this, but the exact suspension
  mechanism/transition instant was NOT established by the trace.
- The old TJ-45L nearest-in-Dart-time anchor selector incorrectly chose
  `reportExport` for gameplay Ticker sample #3092 at Dart ~53.13sec,
  despite that event belonging to the run-start clock epoch.
- Android native Choreographer/VSync-delivery gaps (~40–68ms) coincided
  with several long Flutter framework request→begin waits. The engine
  Ticker usually began ~0.02–0.03ms after the Flutter framework began.
  This supports an upstream timing issue, NOT a proven faulty screen
  signal or completed smoothing fix.

## TJ-45M QA-only correction (flag-gated)
- The older `qa-native-handoff` APK retains TJ-45L's selector and
  remains a same-commit diagnostic comparison/control.
- New build mode `qa-clock-epoch` enables `TJ45M_CLOCK_EPOCH=true`,
  retaining prior TJ-45L/K/I/H diagnostic flags and Aura V2.
- The existing GameScreen lifecycle pause/resume hooks now record a
  bounded list (max 16) of clock-positioned lifecycle boundaries.
  These are application observations, NOT independent proof of suspend.
- The initial `runStart` calibration is the only clock anchor
  permitted to map a recorded gameplay event *before* the first
  observed lifecycle transition, after the anchor itself. It is
  explicitly labeled PROVISIONAL, not a proven hard-bound event match.
- Any event after the first lifecycle boundary is deliberately
  `unmapped-after-first-lifecycle` until a separately valid
  resumption epoch is established in a later experiment; it does NOT
  assume that the later report-export anchor applies backward.
- If a large BOOTTIME-versus-MONOTONIC jump exists (>=50ms) but
  no lifecycle boundary was observed, its location is unknown:
  do NOT guess any absolute event time; output -1 and status
  `unmapped-clock-jump-without-boundary`.
- Absence of a run-start calibration, events preceding it, invalid
  phase order, and events at/after export also fail closed.
- Preserve raw framework-local microsecond intervals even where
  absolute BOOTTIME estimates are unavailable. Include explicit
  `qaEpochMappingStatus` with each retained event; don't silently
  substitute zero or a late epoch. `qaClockEpochDiscontinuity`,
  marker count, first boundary, overflow count, phase drift and
  uncertainty are visible in the detailed report.
- The diagnostic record is reset on game replay in the same app
  session so old anchors cannot be reused for a subsequent run.
- No native frame observer, extra Choreographer listener, timers,
  frame requests, edits to Android permissions, or per-frame IPC.

## Verification
- Synthetic deterministic tests reproduce the exact #3092 error with
  +210.545651695sec offset jump and verify runStart anchor selection.
- Post-lifecycle, no-boundary, invalid anchor order, no runStart,
  lifecycle overflow/reset and rendering of unmapped estimates
  are separately tested.
- CI must compile, run all regression tests, build all **13** signed
  APKs, verify exactly the permanent signing certificate and
  monotonically increasing versionCode for each.
- New artifact: `balloon-burst-internal-qa-clock-epoch-apk`.
- Public production main and private backup main remain protected
  at `f1b749e4ac3d87233423d7c8a73bd4e73653beaa`.
  Draft PR only, no merges/tags/backup push without owner approval.

## Phone QA AFTER full GREEN signed workflow
1. Install the TJ-45M APK over the current app, NEVER uninstall or
   clear saved data. Confirm 24/24 stars, saved bank (last 3766).
2. This is primarily a *diagnostic correctness* acceptance, not a
   stress test. Play about 45–60 seconds Endless with audio ON,
   auto-tap OFF, HUD closed; then open Debug HUD and share one
   detailed report. Android System Tracing is OPTIONAL for this first
   integrity test, and can be used only when a new trace is needed.
3. The report should have `qaClockEpochIntegrityDiagnostic: enabled`,
   `qaNativeHandoffDiagnostic: enabled`,
   `qaFrameRequestCorrelationDiagnostic: enabled`,
   `qaWallClockCorrelationDiagnostic: enabled`,
   `qaGlowRenderer: tightAuraV2`.
4. If a lifecycle pause is observed, check later events say
   `unmapped-after-first-lifecycle` and emit bootNs=-1. Earlier
   records should be labeled `provisional-runStart-before-lifecycle`.
   No need to deliberately induce suspend to test on the phone.
5. Preserve/review bank and stars; no production promotion.

## Limitations
We cannot infer the native suspend instant from two clock anchors
alone; there can be unobserved pauses. A mapped pre-lifecycle event
remains provisional. This correction improves diagnostic honesty
but does not itself reduce frame hitches.
