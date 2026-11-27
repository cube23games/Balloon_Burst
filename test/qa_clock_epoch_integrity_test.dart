import 'package:balloon_burst/debug/qa_frame_request_binding.dart';
import 'package:balloon_burst/debug/qa_frame_request_stats.dart';
import 'package:balloon_burst/debug/qa_native_handoff_calibration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TJ-45M flag is disabled by default in release and older QA modes', () {
    expect(QaClockEpochFlags.enabled, isFalse);
  });

  QaNativeHandoffCalibration calibration({
    bool guarded = true,
    int? jumpNs,
  }) {
    final frame = QaFrameRequestStats()..reset();
    final c = QaNativeHandoffCalibration(frame, epochGuardEnabled: guarded);
    // Comparable to the real TJ-45L session: early sample at 0.168 sec.
    c.recordSample(
      phase: 'runStart', beforeUs: 164485, afterUs: 171195,
      monoBeforeNs: 100000000000, monoAfterNs: 100000001154,
      bootNs: 107035694061830,
    );
    // Later export sample at 97.577 sec. A suspend can move
    // BOOTTIME relative to native CLOCK_MONOTONIC by ~210 seconds.
    final extra = jumpNs ?? 0;
    c.recordSample(
      phase: 'reportExport', beforeUs: 97577213, afterUs: 97577343,
      monoBeforeNs: 200000000000, monoAfterNs: 200000000077,
      bootNs: 207035694061291 + extra,
    );
    return c;
  }

  test('210s offset jump: sample 3092 before pause MUST use start anchor', () {
    final c = calibration(jumpNs: 210545651695);
    c.markLifecycleAt('nativePause', 60229000);
    c.markLifecycleAt('resumeGraceOrSilent', 63475000);
    expect(c.clockEpochDiscontinuity, isTrue);
    expect(c.bootMinusMonoJumpNs, 210545651695);
    final e = c.resolveEvent(53125877); // real TJ-45L sample #3092
    expect(e.status, 'provisional-runStart-before-lifecycle');
    expect(e.anchor?.phase, 'runStart');
    expect(e.anchor!.atBootNs(53125877),
        c.anchorFor('runStart')!.atBootNs(53125877));
    // Legacy nearest-calibration algorithm would make the wrong choice.
    final legacy = calibration(guarded: false, jumpNs: 210545651695);
    expect(legacy.bestAt(53125877)?.phase, 'reportExport');
  });

  test('frames after lifecycle must be UNMAPPED, never given late clock', () {
    final c = calibration(jumpNs: 210545651695);
    c.markLifecycleAt('nativePause', 60229000);
    c.markLifecycleAt('resumeGraceOrSilent', 63475000);
    final x = c.resolveEvent(96533034); // real HUD-visible #3573
    expect(x.anchor, isNull);
    expect(x.status, 'unmapped-after-first-lifecycle');
    expect(c.reportFields, contains('qaClockEpochDiscontinuity: detected'));
    expect(c.reportFields, contains('qaClockEpochFirstLifecycleUs: 60229000'));
    expect(c.reportFields, contains('reason=nativePause'));
  });

  test('clock jump with no observed lifecycle boundary fails closed', () {
    final c = calibration(jumpNs: 210545651695);
    expect(c.resolveEvent(53125877).anchor, isNull);
    expect(c.resolveEvent(53125877).status,
        'unmapped-clock-jump-without-boundary');
  });

  test('normal clock noise does not pretend to be a 210s suspend', () {
    final c = calibration(jumpNs: 500000); // 0.5 ms
    expect(c.clockEpochDiscontinuity, isFalse);
    final decision = c.resolveEvent(53125877);
    expect(decision.anchor?.phase, 'runStart');
    expect(decision.status, 'provisional-runStart-before-lifecycle');
    // Still fail closed if lifecycle was observed (no new post-pause anchor).
    c.markLifecycleAt('flutterPause', 60229000);
    expect(c.resolveEvent(60500000).anchor, isNull);
  });

  test('out-of-order or missing start anchors cannot create a timestamp', () {
    final c = QaNativeHandoffCalibration(QaFrameRequestStats()..reset(),
        epochGuardEnabled: true);
    c.recordSample(phase: 'reportExport', beforeUs: 200,
        afterUs: 300, monoBeforeNs: 10000, monoAfterNs: 10100,
        bootNs: 30000);
    expect(c.resolveEvent(210).status, 'unmapped-no-runStart-anchor');
    c.recordSample(phase: 'runStart', beforeUs: 400,
        afterUs: 500, monoBeforeNs: 10000, monoAfterNs: 10100,
        bootNs: 30000);
    expect(c.resolveEvent(450).status, 'unmapped-anchor-order-invalid');
    expect(c.resolveEvent(200).status, 'unmapped-before-runStart-anchor');
  });

  test('lifecycle count bounded and fully cleared on new run', () {
    final c = calibration();
    for (var i = 0; i < 24; i++) {
      c.markLifecycleAt('nativePause', 200000 + 1000 * i);
    }
    expect(c.lifecycleMarks.length,
        QaNativeHandoffCalibration.maxLifecycleMarks);
    expect(c.lifecycleOverflow, 8);
    expect(c.lifecycleMarks.first.dartUs, 200000);
    expect(c.resolveEvent(53125877).anchor, isNull);
    c.reset();
    expect(c.lifecycleMarks, isEmpty);
    expect(c.lifecycleOverflow, 0);
    expect(c.resolveEvent(53125877).anchor, isNull);
    expect(c.reportFields, contains('qaClockEpochDiscontinuity: unknown'));
  });

  test('event fields expose mapping status with no invented BOOTTIME', () {
    final f = QaFrameRequestStats()..reset();
    final c = QaNativeHandoffCalibration(f, epochGuardEnabled: true);
    c.recordSample(phase: 'runStart', beforeUs: 0, afterUs: 100,
        monoBeforeNs: 10000000000, monoAfterNs: 10000000100,
        bootNs: 11000000050);
    c.markLifecycleAt('nativePause', 80000);
    c.recordSample(phase: 'reportExport', beforeUs: 200000,
        afterUs: 200100, monoBeforeNs: 20000000000,
        monoAfterNs: 20000000100, bootNs: 231000000000);
    f.recordRequest(1000);
    f.recordBegin(2000, 100000);
    f.recordTicker(tickerSample: 1, wallUs: 2010, rawStampUs: 100000);
    f.recordRequest(2020);
    f.recordBegin(60000, 116667);
    f.recordTicker(tickerSample: 2, wallUs: 60020, rawStampUs: 116667);
    f.recordRequest(85000);
    f.recordBegin(135000, 133334);
    f.recordTicker(tickerSample: 3, wallUs: 135020, rawStampUs: 133334);
    final report = c.eventFields;
    expect(report, contains('sample=2'));
    expect(report, contains('qaEpochMappingStatus=provisional-runStart-before-lifecycle'));
    expect(report, contains('sample=3'));
    expect(report, contains('qaEpochMappingStatus=unmapped-after-first-lifecycle'));
    expect(report, contains('calibrationPhase=unmapped qaEpochMappingStatus=unmapped-after-first-lifecycle requestBootNs=-1'));
    expect(report, contains('beginBootNs=-1'));
  });
}
