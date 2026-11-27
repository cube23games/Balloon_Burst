import 'package:balloon_burst/debug/qa_frame_scheduler_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TJ-45H disabled in previous QA and public builds', () {
    expect(QaFrameSchedulerFlags.enabled, isFalse);
  });

  test('compares ticker engine and wall deltas without joining epochs', () {
    final v = QaFrameSchedulerStats();
    expect(v.recordTick(tickerElapsedUs: 10000, engineFrameStampUs: 1000000,
        wallStampUs: 0, transientPhase: true, debugVisible: false), isNull);
    expect(v.recordTick(tickerElapsedUs: 26667, engineFrameStampUs: 1016667,
        wallStampUs: 18000, transientPhase: true, debugVisible: false), isNull);
    final slow = v.recordTick(tickerElapsedUs: 76667,
        engineFrameStampUs: 1066667, wallStampUs: 68000,
        transientPhase: true, debugVisible: false);
    expect(slow, isNotNull);
    expect(slow!.tickerGapUs, 50000);
    expect(slow.engineGapUs, 50000);
    expect(slow.wallGapUs, 50000);
    expect(v.intervalSamples, 2);
    expect(v.tickerHitches, 1);
    expect(v.engineGapsOverThreshold, 1);
    expect(v.wallGapsOverThreshold, 1);
    v.recordPostFrame(slow, 70000, 1066667);
    expect(slow.postFrameUs, 2000);
    expect(v.postFrameCallbacksObserved, 1);
    expect(v.reportFields, contains('qaSchedulerTickerHitchCount: 1'));
  });

  test('slow frames retain just eight worst records', () {
    final v = QaFrameSchedulerStats();
    v.recordTick(tickerElapsedUs: 1, engineFrameStampUs: 100,
        wallStampUs: 1, transientPhase: true, debugVisible: false);
    for (var i = 0; i < 25; i++) {
      v.recordTick(tickerElapsedUs: 1 + (i + 1) * 50000,
          engineFrameStampUs: 100 + (i + 1) * 50000,
          wallStampUs: 1 + (i + 1) * 50000,
          transientPhase: true, debugVisible: i > 10);
    }
    expect(v.tickerHitches, 25);
    expect(v.retainedCount, 8);
    expect(v.worst.first.tickerGapUs, 50000);
    expect(v.outOfTransientPhase, 0);
  });

  test('pause eliminates spurious interval and retains old evidence', () {
    final v = QaFrameSchedulerStats();
    v.recordTick(tickerElapsedUs: 100, engineFrameStampUs: 1000,
        wallStampUs: 100, transientPhase: false, debugVisible: false);
    v.recordTick(tickerElapsedUs: 50100, engineFrameStampUs: 51000,
        wallStampUs: 50100, transientPhase: true, debugVisible: false);
    expect(v.tickerHitches, 1);
    expect(v.outOfTransientPhase, 1);
    v.markLifecycle('nativePause');
    expect(v.recordTick(tickerElapsedUs: 1, engineFrameStampUs: 1000000,
        wallStampUs: 100000, transientPhase: true, debugVisible: false), isNull);
    expect(v.tickerHitches, 1);
    expect(v.intervalSamples, 1);
    expect(v.reportFields, contains('qaSchedulerLifecycle[0]'));
    v.reset();
    expect(v.tickerHitches, 0);
    expect(v.retainedCount, 0);
  });

  test('invalid or regressing raw clocks are rejected', () {
    final v = QaFrameSchedulerStats();
    v.recordTick(tickerElapsedUs: 20, engineFrameStampUs: 20,
        wallStampUs: 20, transientPhase: true, debugVisible: false);
    v.recordTick(tickerElapsedUs: 10, engineFrameStampUs: 30,
        wallStampUs: 40, transientPhase: true, debugVisible: false);
    expect(v.timestampRegressions, 1);
    expect(v.intervalSamples, 0);
  });
}
