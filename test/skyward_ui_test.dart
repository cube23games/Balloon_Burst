import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balloon_burst/skyward/world_one.dart';
import 'package:balloon_burst/skyward/skyward_play_ui.dart';
import 'package:balloon_burst/skyward/skyward_select_screen.dart';

SkywardLevelRun _winFirstLevel() {
  final run = SkywardLevelRun(SkywardWorldOne.level(1));
  for (var i = 0; i < run.level.popsRequired; i++) {
    run.recordPop();
  }
  return run;
}

void main() {
  testWidgets('World 1 map only allows available, unlocked levels', (tester) async {
    final progress = SkywardWorldOneProgress();
    final chosen = <int>[];

    await tester.pumpWidget(MaterialApp(
      home: SkywardSelectScreen(
        progress: progress,
        onSelectLevel: chosen.add,
        onBack: () {},
      ),
    ));

    expect(find.text('WORLD 1 · OPEN SKIES'), findsOneWidget);
    expect(find.text('First Flight'), findsOneWidget);
    expect(find.text('In development'), findsWidgets);
    await tester.tap(find.text('First Flight'));
    expect(chosen, [1]);
    await tester.tap(find.text('Cloud Combos'));
    expect(chosen, [1], reason: 'Level 2 is still locked');
  });

  testWidgets('Completing level 1 unlocks level 2', (tester) async {
    final progress = SkywardWorldOneProgress();
    progress.submit(_winFirstLevel());
    final chosen = <int>[];

    await tester.pumpWidget(MaterialApp(
      home: SkywardSelectScreen(
        progress: progress,
        onSelectLevel: chosen.add,
        onBack: () {},
      ),
    ));
    expect(find.text('★★★'), findsOneWidget);
    await tester.tap(find.text('Cloud Combos'));
    expect(chosen, [2]);
    // Crosswind Alley is now playable; ribbon-chain levels remain gated.
    expect(SkywardSelectScreen.playableThrough, 4);
  });

  testWidgets('Result overlay exposes Next, Replay and Map actions', (tester) async {
    final clicked = <String>[];
    final run = _winFirstLevel();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          SkywardResultOverlay(
            run: run,
            onNext: () => clicked.add('next'),
            onReplay: () => clicked.add('replay'),
            onMap: () => clicked.add('map'),
          ),
        ]),
      ),
    ));

    expect(find.text('LEVEL CLEARED!'), findsOneWidget);
    expect(find.text('★★★'), findsOneWidget);
    await tester.tap(find.text('NEXT LEVEL'));
    await tester.tap(find.text('REPLAY LEVEL'));
    await tester.tap(find.text('LEVEL MAP'));
    expect(clicked, ['next', 'replay', 'map']);
  });

  testWidgets('Failed level has no next-level action', (tester) async {
    final run = SkywardLevelRun(SkywardWorldOne.level(1));
    for (var i = 0; i < 3; i++) {
      run.recordEscape();
    }
    expect(run.isFailed, isTrue);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          SkywardResultOverlay(
            run: run,
            onReplay: () {},
            onMap: () {},
          ),
        ]),
      ),
    ));
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('NEXT LEVEL'), findsNothing);
  });

  testWidgets('Objective HUD displays goals and exit button', (tester) async {
    final run = SkywardLevelRun(SkywardWorldOne.level(1));
    var exited = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          SkywardObjectiveHud(
            run: run,
            onExit: () => exited = true,
          ),
        ]),
      ),
    ));
    expect(find.textContaining('POPS 0/12'), findsOneWidget);
    await tester.tap(find.byTooltip('Exit to level map'));
    expect(exited, isTrue);
  });
}
