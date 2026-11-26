import 'package:balloon_burst/debug/game_update_timing_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TJ-45D QA frame-pacing update sampler', () {
    test('public/default builds never enable extra frame instrumentation', () {
      expect(FramePacingDiagnosticFlags.enabled, isFalse);
    });

    test('records update time and same-tick prior-gap correlation', () {
      final stats = GameUpdateTimingStats();
      stats.record(durationMicros: 10000, precedingTickerHitch: false);
      stats.record(durationMicros: 17000, precedingTickerHitch: true);
      stats.record(durationMicros: 40000, precedingTickerHitch: false);
      expect(stats.samples, 3);
      expect(stats.overBudget, 2);
      expect(stats.overSevereBudget, 1);
      expect(stats.samplesAfterTickerHitch, 1);
      expect(stats.overBudgetAfterTickerHitch, 1);
      expect(stats.averageUpdateMs, closeTo(22.333333, 0.0001));
      expect(stats.worstUpdateMicros, 40000);
      expect(stats.reportFields, contains('qaFramePacingDiagnostic: enabled'));
      expect(stats.reportFields, contains('qaGameUpdateSampleCount: 3'));
      expect(stats.reportFields,
          contains('qaGameUpdateOverBudgetAfterTickerHitch: 1'));
    });

    test('exact budget is not a miss; reject negative, accept zero', () {
      final stats = GameUpdateTimingStats();
      stats.record(durationMicros: -1, precedingTickerHitch: false);
      stats.record(durationMicros: 0, precedingTickerHitch: false);
      stats.record(durationMicros: 16667, precedingTickerHitch: true);
      stats.record(durationMicros: 33333, precedingTickerHitch: false);
      expect(stats.samples, 3);
      expect(stats.overBudget, 1);
      expect(stats.overSevereBudget, 0);
      expect(stats.samplesAfterTickerHitch, 1);
    });

    test('replay reset clears all counters, sums and maximums', () {
      final stats = GameUpdateTimingStats();
      stats.record(durationMicros: 40000, precedingTickerHitch: true);
      stats.reset();
      expect(stats.samples, 0);
      expect(stats.averageUpdateMs, 0);
      expect(stats.overBudget, 0);
      expect(stats.overBudgetAfterTickerHitch, 0);
      expect(stats.worstUpdateMicros, 0);
      stats.record(durationMicros: 2000, precedingTickerHitch: false);
      expect(stats.samples, 1);
      expect(stats.averageUpdateMs, 2.0);
      expect(stats.worstUpdateMicros, 2000);
    });
  });
}
