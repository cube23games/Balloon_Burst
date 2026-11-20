import 'package:balloon_burst/debug/frame_gap_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TJ-45A QA frame-gap sampler', () {
    test('matches legacy hitch threshold and separates early/later phases', () {
      final stats = FrameGapStats();
      stats.record(rawDeltaSeconds: 1.0 / 60.0, runSeconds: 0.0);
      stats.record(rawDeltaSeconds: 1.0 / 28.0, runSeconds: 0.4);
      stats.record(rawDeltaSeconds: 0.050, runSeconds: 0.8);
      stats.record(rawDeltaSeconds: 0.120, runSeconds: 2.4);

      expect(stats.samples, 4);
      expect(stats.totalHitches, 3);
      expect(stats.firstSecondHitches, 2);
      expect(stats.laterHitches, 1);
      expect(stats.worstGapMs, closeTo(120.0, 0.001));
      expect(stats.atMost16_7Ms, 1);
      expect(stats.over16_7To33_3Ms, 0);
      expect(stats.over33_3To50Ms, 2);
      expect(stats.over50Ms, 1);
      expect(stats.reportFields, contains('qaFrameGapHitchesTotal: 3'));
    });

    test('negative, zero, NaN and infinite measurements are ignored', () {
      final stats = FrameGapStats();
      stats.record(rawDeltaSeconds: 0, runSeconds: 0);
      stats.record(rawDeltaSeconds: -0.1, runSeconds: 0);
      stats.record(rawDeltaSeconds: double.nan, runSeconds: 0);
      stats.record(rawDeltaSeconds: double.infinity, runSeconds: 0);
      stats.record(rawDeltaSeconds: 0.05, runSeconds: -1);
      expect(stats.samples, 0);
      expect(stats.totalHitches, 0);
    });

    test('reset isolates replays and does not retain older hitches', () {
      final stats = FrameGapStats();
      stats.record(rawDeltaSeconds: 0.1, runSeconds: 0.2);
      expect(stats.totalHitches, 1);
      stats.reset();
      stats.record(rawDeltaSeconds: 0.016, runSeconds: 0.0);
      expect(stats.samples, 1);
      expect(stats.totalHitches, 0);
      expect(stats.worstGapMs, closeTo(16, 0.001));
    });

    test('first-second boundary is exclusive and 50 ms is not over-50', () {
      final stats = FrameGapStats();
      stats.record(rawDeltaSeconds: 0.05, runSeconds: 1.0);
      expect(stats.firstSecondHitches, 0);
      expect(stats.laterHitches, 1);
      expect(stats.over33_3To50Ms, 1);
      expect(stats.over50Ms, 0);
    });
  });
}
