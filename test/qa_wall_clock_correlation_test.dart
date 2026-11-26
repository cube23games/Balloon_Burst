import 'package:balloon_burst/debug/qa_frame_scheduler_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TJ-45I flag is disabled in earlier QA modes', () {
    expect(QaWallClockCorrelationFlags.enabled, isFalse);
    final control = QaFrameSchedulerStats();
    expect(control.wallCorrelationEnabled, isFalse);
    expect(control.reportFields, isNot(contains('qaWallClockCorrelationDiagnostic: enabled')));
  });

  test('exact mutually exclusive wall-vs-engine classification', () {
    final v = QaFrameSchedulerStats(wallCorrelationEnabled: true);
    expect(v.recordTick(
        tickerElapsedUs: 10000, engineFrameStampUs: 100000, wallStampUs: 10000,
        transientPhase: true, debugVisible: false), isNull);

    // Wall-only: raw engine +16.667ms, callback arrives +50ms.
    final wallOnly = v.recordTick(
        tickerElapsedUs: 26667, engineFrameStampUs: 116667, wallStampUs: 60000,
        transientPhase: true, debugVisible: false);
    expect(wallOnly, isNotNull);
    expect(wallOnly!.wallGapUs, 50000);
    expect(wallOnly.engineGapUs, 16667);
    expect(v.worstWallOnly.single.sample, 2);
    expect(wallOnly.startup, isTrue);
    v.recordPostFrame(wallOnly, 64000, 116667);
    expect(wallOnly.postFrameUs, 4000);

    // Engine-only: ticker/engine +50ms; wall +10ms.
    final engineOnly = v.recordTick(
        tickerElapsedUs: 76667, engineFrameStampUs: 166667, wallStampUs: 70000,
        transientPhase: true, debugVisible: false);
    expect(engineOnly, isNotNull);
    expect(engineOnly!.engineGapUs, 50000);
    expect(engineOnly.wallGapUs, 10000);

    // Both: each interval crosses threshold.
    final both = v.recordTick(
        tickerElapsedUs: 126667, engineFrameStampUs: 216667,
        wallStampUs: 125000, transientPhase: true, debugVisible: true);
    expect(both, isNotNull);
    expect(both!.debugVisible, isTrue);

    // Neither: both below threshold.
    expect(v.recordTick(
        tickerElapsedUs: 143334, engineFrameStampUs: 233334,
        wallStampUs: 141667, transientPhase: true, debugVisible: false), isNull);

    expect(v.intervalSamples, 4);
    expect(v.wallOnlySlow, 1);
    expect(v.engineOnlySlow, 1);
    expect(v.bothSlow, 1);
    expect(v.neitherSlow, 1);
    expect(v.wallGapsOverThreshold, 2);
    expect(v.engineGapsOverThreshold, 2);
    expect(v.tickerHitches, 2);
    expect(v.differingClockIntervals, 2);
    expect(v.startupSlowWallIntervals, 2);
    expect(v.debugVisibleSlowWallIntervals, 1);
    expect(v.worstWall.length, 2);
    expect(v.worstWallOnly.length, 1);
    expect(v.reportFields, contains('qaWallClockWallOnlySlowCount: 1'));
    expect(v.reportFields, contains('qaWallClockEngineOnlySlowCount: 1'));
    expect(v.reportFields, contains('qaWallClockBothSlowCount: 1'));
    expect(v.reportFields, contains('qaWallClockNeitherSlowCount: 1'));
    expect(v.reportFields, contains('qaWallClockWorstWallOnly[0]'));
    expect(v.reportFields, contains('postFrameCallbackMs=4.00'));
  });

  test('wall-only history retains the worst eight, no ticker hitch needed', () {
    final v = QaFrameSchedulerStats(wallCorrelationEnabled: true);
    var ticker = 1, engine = 100, wall = 1;
    v.recordTick(tickerElapsedUs: ticker, engineFrameStampUs: engine,
        wallStampUs: wall, transientPhase: true, debugVisible: false);
    for (var i = 0; i < 25; i++) {
      ticker += 16667;
      engine += 16667;
      wall += 40000 + 1000 * i;
      v.recordTick(tickerElapsedUs: ticker, engineFrameStampUs: engine,
          wallStampUs: wall, transientPhase: true, debugVisible: false);
    }
    expect(v.intervalSamples, 25);
    expect(v.wallOnlySlow, 25);
    expect(v.engineOnlySlow, 0);
    expect(v.bothSlow, 0);
    expect(v.tickerHitches, 0);
    expect(v.worst.length, 0);
    expect(v.worstWall.length, 8);
    expect(v.worstWallOnly.length, 8);
    expect(v.worstWallOnly.first.wallGapUs, 64000);
    expect(v.worstWallOnly.last.wallGapUs, 57000);
    expect(v.reportFields.split('qaWallClockWorstWallOnly[').length - 1, 8);
    v.reset();
    expect(v.wallOnlySlow, 0);
    expect(v.worstWallOnly, isEmpty);
    expect(v.worstWall, isEmpty);
    expect(v.intervalSamples, 0);
  });

  test('lifecycle marks reset pairing but retain accumulated evidence', () {
    final v = QaFrameSchedulerStats(wallCorrelationEnabled: true);
    v.recordTick(tickerElapsedUs: 100, engineFrameStampUs: 1000,
        wallStampUs: 100, transientPhase: true, debugVisible: false);
    v.recordTick(tickerElapsedUs: 200, engineFrameStampUs: 1100,
        wallStampUs: 50000, transientPhase: true, debugVisible: false);
    expect(v.wallOnlySlow, 1);
    v.markLifecycle('nativePause');
    expect(v.recordTick(tickerElapsedUs: 0, engineFrameStampUs: 50000,
        wallStampUs: 250000, transientPhase: true, debugVisible: false), isNull);
    expect(v.intervalSamples, 1);
    expect(v.wallOnlySlow, 1);
    v.recordTick(tickerElapsedUs: 16667, engineFrameStampUs: 66667,
        wallStampUs: 300000, transientPhase: true, debugVisible: false);
    expect(v.intervalSamples, 2);
    expect(v.wallOnlySlow, 2);
    expect(v.reportFields, contains('qaWallClockAfterLifecycle2500msSlowWallCount: 1'));
  });

  test('invalid clocks excluded from cross tab', () {
    final v = QaFrameSchedulerStats(wallCorrelationEnabled: true);
    v.recordTick(tickerElapsedUs: 100, engineFrameStampUs: 100,
        wallStampUs: 100, transientPhase: true, debugVisible: false);
    v.recordTick(tickerElapsedUs: 90, engineFrameStampUs: 150,
        wallStampUs: 60000, transientPhase: true, debugVisible: false);
    expect(v.timestampRegressions, 1);
    expect(v.intervalSamples, 0);
    expect(v.wallOnlySlow + v.engineOnlySlow + v.bothSlow + v.neitherSlow, 0);
  });
}
