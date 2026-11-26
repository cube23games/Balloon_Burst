import 'package:balloon_burst/debug/qa_ui_build_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TJ-45G probe disabled by default', () {
    expect(QaUiBuildFlags.enabled, isFalse);
  });
  test('boundary, bounded four worst and reset', () {
    final s = QaUiStageStats();
    s.record(16667, debugVisible: false, msAfterNavigation: -1);
    for (var i = 0; i < 25; i++) {
      s.record(17000 + i * 100, debugVisible: true, msAfterNavigation: i);
    }
    expect(s.samples, 26);
    expect(s.overBudget, 25);
    expect(s.retainedCount, 4);
    expect(s.worstSamples.first.durationUs, 19400);
    expect(s.worstSamples.last.durationUs, 19100);
    expect(s.worstSamples.first.debugVisible, isTrue);
    s.reset();
    expect(s.samples, 0);
    expect(s.overBudget, 0);
    expect(s.retainedCount, 0);
  });
  test('navigation markers and selected builder recording', () {
    final s = QaUiBuildStats();
    for (var i = 0; i < 12; i++) {
      s.navigationRequest(opening: true);
      s.navigationPostFrame(opening: true);
      s.navigationRequest(opening: false);
      s.navigationPostFrame(opening: false);
    }
    expect(s.opens, 12);
    expect(s.closes, 12);
    expect(s.reportFields.split('qaUiNavigation[').length - 1, 8);
    final start = s.begin(QaUiBuildStage.gameLayout);
    s.end(QaUiBuildStage.gameLayout, start);
    expect(s.stage(QaUiBuildStage.gameLayout).samples, 1);
    expect(s.stage(QaUiBuildStage.debugHud).samples, 0);
    s.reset();
    expect(s.opens, 0);
    expect(s.reportFields, contains('qaUiBuildDiagnostic: enabled'));
  });
}
