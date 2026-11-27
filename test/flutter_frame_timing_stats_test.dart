import 'package:balloon_burst/debug/flutter_frame_timing_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TJ-45A Flutter UI and raster timing sampler', () {
    test('counts independent build/raster budget misses and overlap', () {
      final stats = FlutterFrameTimingStats();
      stats.record(
        buildDuration: const Duration(microseconds: 16000),
        rasterDuration: const Duration(microseconds: 16000),
      );
      stats.record(
        buildDuration: const Duration(microseconds: 17000),
        rasterDuration: const Duration(microseconds: 10000),
      );
      stats.record(
        buildDuration: const Duration(microseconds: 9000),
        rasterDuration: const Duration(microseconds: 20000),
      );
      stats.record(
        buildDuration: const Duration(microseconds: 23000),
        rasterDuration: const Duration(microseconds: 21000),
      );

      expect(stats.samples, 4);
      expect(stats.buildOverBudget, 2);
      expect(stats.rasterOverBudget, 2);
      expect(stats.bothOverBudget, 1);
      expect(stats.averageBuildMs, closeTo(16.25, 0.0001));
      expect(stats.averageRasterMs, closeTo(16.75, 0.0001));
      expect(stats.worstBuildMicros, 23000);
      expect(stats.worstRasterMicros, 21000);
      expect(stats.reportFields, contains('qaFlutterTimingSampleCount: 4'));
      expect(
        stats.reportFields,
        contains('qaFlutterTimingBothOverBudgetCount: 1'),
      );
    });

    test('exact frame budget is not over budget', () {
      final stats = FlutterFrameTimingStats();
      stats.record(
        buildDuration: const Duration(microseconds: 16667),
        rasterDuration: const Duration(microseconds: 16667),
      );
      expect(stats.samples, 1);
      expect(stats.buildOverBudget, 0);
      expect(stats.rasterOverBudget, 0);
      expect(stats.bothOverBudget, 0);
    });

    test('rejects negative durations and handles empty samples', () {
      final stats = FlutterFrameTimingStats();
      stats.record(
        buildDuration: const Duration(microseconds: -1),
        rasterDuration: const Duration(microseconds: 10000),
      );
      stats.record(
        buildDuration: const Duration(microseconds: 10000),
        rasterDuration: const Duration(microseconds: -1),
      );
      expect(stats.samples, 0);
      expect(stats.averageBuildMs, 0.0);
      expect(stats.averageRasterMs, 0.0);
      expect(stats.reportFields, contains('qaFlutterTimingSampleCount: 0'));
    });

    test('TJ-45D VSync overhead and total span are independently measured', () {
      final stats = FlutterFrameTimingStats();
      stats.record(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 8000),
        vsyncOverhead: const Duration(microseconds: 18000),
        totalSpan: const Duration(microseconds: 32000),
      );
      stats.record(
        buildDuration: const Duration(microseconds: 3000),
        rasterDuration: const Duration(microseconds: 7000),
        vsyncOverhead: const Duration(microseconds: 2000),
        totalSpan: const Duration(microseconds: 12000),
      );
      expect(stats.samples, 2);
      expect(stats.vsyncSamples, 2);
      expect(stats.totalSpanSamples, 2);
      expect(stats.buildOverBudget, 0);
      expect(stats.rasterOverBudget, 0);
      expect(stats.vsyncOverBudget, 1);
      expect(stats.totalSpanOverBudget, 1);
      expect(stats.averageVsyncMs, 10.0);
      expect(stats.averageTotalSpanMs, 22.0);
      expect(stats.worstVsyncMicros, 18000);
      expect(stats.worstTotalSpanMicros, 32000);
      expect(stats.reportFields,
          contains('qaFlutterTimingVsyncOverBudgetCount: 1'));
      expect(stats.reportFields,
          contains('qaFlutterTimingTotalSpanOverBudgetCount: 1'));
      stats.reset();
      expect(stats.vsyncSamples, 0);
      expect(stats.totalSpanSamples, 0);
      expect(stats.averageVsyncMs, 0);
      expect(stats.averageTotalSpanMs, 0);
    });

    test('non-diagnostic QA leaves extended fields absent', () {
      final stats = FlutterFrameTimingStats();
      stats.record(
        buildDuration: const Duration(microseconds: 3000),
        rasterDuration: const Duration(microseconds: 7000),
      );
      expect(stats.reportFields, isNot(contains('qaFlutterTimingVsync')));
      expect(stats.reportFields, isNot(contains('qaFlutterTimingTotalSpan')));
    });

    test('reset isolates later replay', () {
      final stats = FlutterFrameTimingStats();
      stats.record(
        buildDuration: const Duration(microseconds: 100000),
        rasterDuration: const Duration(microseconds: 40000),
      );
      stats.reset();
      stats.record(
        buildDuration: const Duration(microseconds: 5000),
        rasterDuration: const Duration(microseconds: 7000),
      );
      expect(stats.samples, 1);
      expect(stats.buildOverBudget, 0);
      expect(stats.rasterOverBudget, 0);
      expect(stats.bothOverBudget, 0);
      expect(stats.worstBuildMicros, 5000);
      expect(stats.worstRasterMicros, 7000);
      expect(stats.averageBuildMs, closeTo(5.0, 0.0001));
    });
  });
}
