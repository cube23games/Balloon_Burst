import 'package:balloon_burst/skyward/skyward_play_ui.dart';
import 'package:balloon_burst/skyward/skyward_select_screen.dart';
import 'package:balloon_burst/skyward/world_one.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SkywardLevelRun _clearCarnivalGate({int escapes = 0}) {
  final run = SkywardLevelRun(SkywardWorldOne.level(8));
  for (var i = 0; i < escapes; i++) {
    run.recordEscape();
  }
  // 27 standard balloons, 3 real lead catches, 3 two-balloon chain events
  // = 36 physical pops, but only 33 human taps.
  for (var i = 0; i < 27; i++) {
    run.recordPop();
  }
  for (var i = 0; i < 3; i++) {
    run.recordPop(leadCaught: true);
  }
  for (var i = 0; i < 3; i++) {
    run.recordPop(balloonsPopped: 2, triggeredChain: true);
  }
  return run;
}

void main() {
  group('TJ-44H — Carnival Gate final level contract', () {
    test('final challenge uses all three proven hazards and strict objectives', () {
      final level = SkywardWorldOne.level(8);
      expect(level.number, 8);
      expect(level.title, 'Carnival Gate');
      expect(level.popsRequired, 36);
      expect(level.leadCatchesRequired, 3);
      expect(level.chainReactionsRequired, 3);
      expect(level.maxEscapes, 1);
      expect(level.unlocksCarnival, isTrue);
      expect(level.hazards, {
        SkywardHazard.leadBalloon,
        SkywardHazard.microburst,
        SkywardHazard.ribbonChain,
      });
      expect(SkywardSelectScreen.playableThrough, 8);
      expect(() => SkywardWorldOne.level(9), throwsRangeError);
    });

    test('36 physical pops, three leads and three chains clear the finale', () {
      final run = _clearCarnivalGate();
      expect(run.popped, 36);
      expect(run.successfulTaps, 33);
      expect(run.leadCatches, 3);
      expect(run.chainReactions, 3);
      expect(run.escaped, 0);
      expect(run.isComplete, isTrue);
      expect(run.stars, 3);
      run.recordPop(leadCaught: true, triggeredChain: true);
      expect(run.popped, 36, reason: 'No duplicate victory scoring');
    });

    test('normal balloons alone cannot open the Carnival Gate', () {
      final run = SkywardLevelRun(SkywardWorldOne.level(8));
      for (var i = 0; i < 36; i++) {
        run.recordPop();
      }
      expect(run.popped, 36);
      expect(run.leadCatches, 0);
      expect(run.chainReactions, 0);
      expect(run.isComplete, isFalse);
      expect(run.stars, 0);
    });

    test('missing lead catches blocks the gate despite excess pops and chains',
        () {
      final run = SkywardLevelRun(SkywardWorldOne.level(8));
      for (var i = 0; i < 36; i++) {
        run.recordPop();
      }
      for (var i = 0; i < 3; i++) {
        run.recordPop(balloonsPopped: 2, triggeredChain: true);
      }
      expect(run.chainReactions, 3);
      expect(run.isComplete, isFalse);
      for (var i = 0; i < 3; i++) {
        run.recordPop(leadCaught: true);
      }
      expect(run.isComplete, isTrue);
    });

    test('missing ribbon chains blocks the gate despite excess pops and leads',
        () {
      final run = SkywardLevelRun(SkywardWorldOne.level(8));
      for (var i = 0; i < 36; i++) {
        run.recordPop();
      }
      for (var i = 0; i < 3; i++) {
        run.recordPop(leadCaught: true);
      }
      expect(run.leadCatches, 3);
      expect(run.isComplete, isFalse);
      for (var i = 0; i < 3; i++) {
        run.recordPop(balloonsPopped: 2, triggeredChain: true);
      }
      expect(run.isComplete, isTrue);
    });

    test('one escape is permitted; the second fails and freezes the run', () {
      final nearlyPerfect = _clearCarnivalGate(escapes: 1);
      expect(nearlyPerfect.isComplete, isTrue);
      expect(nearlyPerfect.stars, 2);
      final failed = SkywardLevelRun(SkywardWorldOne.level(8))
        ..recordEscape()
        ..recordEscape();
      expect(failed.isFailed, isTrue);
      failed.recordPop(balloonsPopped: 2, leadCaught: true, triggeredChain: true);
      expect(failed.popped, 0);
      expect(failed.leadCatches, 0);
      expect(failed.chainReactions, 0);
      expect(failed.stars, 0);
    });

    test('21 saved stars unlock Level 8, but not the completion banner', () {
      final progress = SkywardWorldOneProgress.fromSaved(
        [3, 3, 3, 3, 3, 3, 3],
      );
      expect(progress.totalStars, 21);
      expect(progress.isLevelUnlocked(8), isTrue);
      expect(progress.worldComplete, isFalse);
      expect(progress.carnivalUnlocked, isFalse);
      progress.submit(_clearCarnivalGate());
      expect(progress.totalStars, 24);
      expect(progress.worldComplete, isTrue);
      expect(progress.carnivalUnlocked, isTrue);
      expect(progress.bestStars, List<int>.filled(8, 3));
      final reopened = SkywardWorldOneProgress.fromSaved(progress.bestStars);
      expect(reopened.worldComplete, isTrue);
      expect(reopened.totalStars, 24);
    });

    test('missing Level 7 progress cannot fabricate final gate access', () {
      final saved = SkywardWorldOneProgress.fromSaved(
        [3, 3, 3, 3, 3, 3, 0, 3],
      );
      expect(saved.totalStars, 18);
      expect(saved.isLevelUnlocked(8), isFalse);
      expect(saved.worldComplete, isFalse);
      expect(
        () => saved.submit(_clearCarnivalGate()),
        throwsStateError,
      );
    });
  });

  testWidgets('Level 8 HUD keeps strict finale goals and warnings readable',
      (tester) async {
    final run = SkywardLevelRun(SkywardWorldOne.level(8));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SkywardObjectiveHud(
          run: run,
          leadWarning: true,
          windWarning: true,
          windDirection: -1,
          onExit: () {},
        ),
      ),
    ));
    expect(find.text('LEVEL 8 · Carnival Gate'), findsOneWidget);
    expect(find.textContaining('POPS 0/36'), findsOneWidget);
    expect(find.textContaining('ESCAPES 0/1'), findsOneWidget);
    expect(find.text('LEAD 0/3'), findsOneWidget);
    expect(find.text('CHAINS 0/3'), findsOneWidget);
    expect(find.text('↓ WHISTLE! LEAD INCOMING'), findsOneWidget);
    expect(find.text('← CROSSWIND INCOMING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Level 8 requires saved Level 7 clear and has correct map goals',
      (tester) async {
    final chosen = <int>[];
    final progress = SkywardWorldOneProgress.fromSaved(
      [3, 3, 3, 3, 3, 3],
    );
    Future<void> showMap(SkywardWorldOneProgress value) async {
      await tester.pumpWidget(MaterialApp(
        home: SkywardSelectScreen(
          progress: value,
          onSelectLevel: chosen.add,
          onBack: () {},
        ),
      ));
      await tester.scrollUntilVisible(
        find.text('Carnival Gate'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
    }

    await showMap(progress);
    expect(find.text('Complete the previous level'), findsWidgets);
    await tester.tap(find.text('Carnival Gate'));
    expect(chosen, isEmpty);

    final afterSeven = SkywardWorldOneProgress.fromSaved(
      [3, 3, 3, 3, 3, 3, 3],
    );
    await showMap(afterSeven);
    expect(find.textContaining('36 pops'), findsOneWidget);
    expect(find.textContaining('Lead 3'), findsWidgets);
    expect(find.textContaining('Chains 3'), findsOneWidget);
    expect(find.textContaining('Max 1 escapes'), findsOneWidget);
    await tester.tap(find.text('Carnival Gate'));
    expect(chosen, [8]);
    expect(afterSeven.carnivalUnlocked, isFalse);
  });

  testWidgets('victory celebrates World 1 and never offers nonexistent Level 9',
      (tester) async {
    var mapOpened = false;
    final won = _clearCarnivalGate();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          SkywardResultOverlay(
            run: won,
            onMap: () => mapOpened = true,
            onReplay: () {},
          ),
        ]),
      ),
    ));
    expect(find.text('WORLD 1 COMPLETE!'), findsOneWidget);
    expect(find.text('CARNIVAL GATE OPENED!'), findsOneWidget);
    expect(find.textContaining('All eight Skyward challenges are cleared'),
        findsOneWidget);
    expect(find.text('★★★'), findsOneWidget);
    expect(find.text('NEXT LEVEL'), findsNothing);
    await tester.tap(find.text('LEVEL MAP'));
    expect(mapOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed finale has no victory banner and no next-level action',
      (tester) async {
    final failed = SkywardLevelRun(SkywardWorldOne.level(8))
      ..recordEscape()
      ..recordEscape();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          SkywardResultOverlay(
            run: failed,
            onMap: () {},
            onReplay: () {},
          ),
        ]),
      ),
    ));
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('CARNIVAL GATE OPENED!'), findsNothing);
    expect(find.text('WORLD 1 COMPLETE!'), findsNothing);
    expect(find.text('NEXT LEVEL'), findsNothing);
  });

  testWidgets('restored eight-level completion shows opened gate on the map',
      (tester) async {
    final completed = SkywardWorldOneProgress.fromSaved(
      [3, 3, 3, 3, 3, 3, 3, 3],
    );
    await tester.pumpWidget(MaterialApp(
      home: SkywardSelectScreen(
        progress: completed,
        onSelectLevel: (_) {},
        onBack: () {},
      ),
    ));
    expect(find.text('24 / 24 stars earned'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('CARNIVAL GATE OPENED!'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('World 1 complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
