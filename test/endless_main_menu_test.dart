import 'package:balloon_burst/game/end/run_end_overlay.dart';
import 'package:balloon_burst/game/end/run_end_state.dart';
import 'package:balloon_burst/tj_engine/engine/tj_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reason in <RunEndReason>[
    RunEndReason.escape,
    RunEndReason.victory,
  ]) {
    testWidgets('Endless ${reason.name} results return to main menu',
        (tester) async {
      var menuCalls = 0;
      var replayCalls = 0;
      var leaderboardCalls = 0;
      final engine = TJEngine();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RunEndOverlay(
              state: RunEndState(reason: reason, misses: 0, escapes: 3),
              engine: engine,
              onReplay: () => replayCalls++,
              onMainMenu: () => menuCalls++,
              onRevive: reason == RunEndReason.victory ? null : () {},
              onViewLeaderboard: () => leaderboardCalls++,
            ),
          ),
        ),
      );

      // End splash is intentionally shown before the final score buttons.
      expect(find.byKey(const ValueKey('endless-main-menu')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 650));

      final menu = find.byKey(const ValueKey('endless-main-menu'));
      expect(menu, findsOneWidget);
      expect(find.text('MAIN MENU'), findsOneWidget);
      expect(find.text('REPLAY'), findsOneWidget);
      expect(find.text('VIEW LEADERBOARD'), findsOneWidget);

      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pump();

      expect(menuCalls, 1);
      expect(replayCalls, 0,
          reason: 'Returning to start must never silently replay');
      expect(leaderboardCalls, 0,
          reason: 'Returning to start must never resubmit a score');
    });
  }
}
