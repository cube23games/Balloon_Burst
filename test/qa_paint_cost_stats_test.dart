import 'package:balloon_burst/debug/qa_paint_cost_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TJ-45O-A five fixed categories, bounded sampling, reset', () {
    expect(QaPaintCostStats.categories.length, 5);
    final stats = QaPaintCostStats();
    var paints = 0;
    for (var i = 0; i < 40; i++) {
      stats.measure(QaPaintCostStats.balloon, () => paints++);
    }
    expect(paints, 40); // Never omit actual paint operations.
    if (QaPaintCostStats.enabled) {
      expect(stats.calls(QaPaintCostStats.balloon), 40);
      expect(stats.samples(QaPaintCostStats.balloon), 2);
      expect(stats.reportFields, contains('qaPaintCostDiagnostic: enabled'));
      expect(stats.reportFields, contains('scope: NOT-GPU'), isFalse);
      expect(stats.reportFields, contains('qaPaintCost_balloon: calls=40 samples=2'));
    } else {
      expect(stats.calls(QaPaintCostStats.balloon), 0);
      expect(stats.samples(QaPaintCostStats.balloon), 0);
      expect(stats.reportFields, contains('qaPaintCostDiagnostic: disabled'));
    }
    stats.reset();
    expect(stats.calls(QaPaintCostStats.balloon), 0);
    expect(stats.samples(QaPaintCostStats.balloon), 0);
  });

  test('TJ-45O-A painter exceptions propagate without swallowing', () {
    final stats = QaPaintCostStats();
    var attempts = 0;
    for (var i = 0; i < 15; i++) {
      stats.measure(QaPaintCostStats.particles, () { attempts++; });
    }
    expect(() => stats.measure(QaPaintCostStats.particles, () {
      attempts++;
      throw StateError('painter failure');
    }), throwsStateError);
    expect(attempts, 16);
    if (QaPaintCostStats.enabled) {
      expect(stats.samples(QaPaintCostStats.particles), 1);
    }
  });
}
