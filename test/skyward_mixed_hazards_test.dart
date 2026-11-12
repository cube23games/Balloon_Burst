import 'package:balloon_burst/game/balloon_type.dart';
import 'package:balloon_burst/skyward/microburst_controller.dart';
import 'package:balloon_burst/skyward/ribbon_chain_controller.dart';
import 'package:balloon_burst/skyward/skyward_play_ui.dart';
import 'package:balloon_burst/skyward/skyward_select_screen.dart';
import 'package:balloon_burst/skyward/world_one.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TJ-44F mixed-hazard wind + ribbons', () {
    test('Level 6 combines ONLY crosswind and ribbon chain requirements', () {
      final level = SkywardWorldOne.level(6);
      expect(level.title, 'Spiraling Skies');
      expect(level.popsRequired, 28);
      expect(level.chainReactionsRequired, 2);
      expect(level.maxEscapes, 2);
      expect(level.leadCatchesRequired, 0);
      expect(level.hazards, {
        SkywardHazard.microburst,
        SkywardHazard.ribbonChain,
      });
      expect(SkywardWorldOne.level(5).hazards, {SkywardHazard.ribbonChain});
      expect(SkywardWorldOne.level(7).hazards, contains(SkywardHazard.leadBalloon));
      expect(SkywardSelectScreen.playableThrough, 8);
    });

    test('two-second warning moves neither normal balloons nor linked pairs', () {
      final wind = MicroburstController();
      wind.update(MicroburstController.firstCalmSeconds);
      expect(wind.phase, MicroburstPhase.warning);
      expect(wind.warningSoon, isTrue);
      expect(wind.normalizedSway, 0);
      expect(wind.applySway(0.3), 0.3);
      expect(wind.boundedGroupSway([0.3, 0.6]), 0);
      wind.update(1.5);
      expect(wind.boundedGroupSway([0.3, 0.6]), 0);
    });

    test('gust moves a whole pair equally and stops at the nearest edge', () {
      final wind = MicroburstController()
        ..update(MicroburstController.firstCalmSeconds +
            MicroburstController.warningSeconds +
            MicroburstController.gustSeconds / 2);
      expect(wind.isGusting, isTrue);
      expect(wind.direction, 1);
      expect(wind.normalizedSway, closeTo(0.34, 1e-9));

      final xs = <double>[0.38, 0.78];
      final groupShift = wind.boundedGroupSway(xs);
      expect(groupShift, closeTo(0.10, 1e-9));
      final shifted = xs.map((x) => x + groupShift).toList();
      expect(shifted[0], closeTo(0.48, 1e-9));
      expect(shifted[1], closeTo(0.88, 1e-9));
      expect(shifted[1] - shifted[0], closeTo(xs[1] - xs[0], 1e-9),
          reason: 'Wind cannot stretch the silk tether');
      expect(wind.applySway(0.38), closeTo(0.72, 1e-9),
          reason: 'Ordinary balloons keep individual wind behavior');
      expect(wind.boundedGroupSway([0.95, 0.60]), 0,
          reason: 'Naturally edge-spawned balloons cannot be forced out');
      expect(wind.boundedGroupSway(const <double>[]), 0);
    });

    test('left-hand gust is bounded consistently for a ribbon pair', () {
      final wind = MicroburstController();
      wind.update(MicroburstController.firstCalmSeconds +
          MicroburstController.warningSeconds +
          MicroburstController.gustSeconds +
          MicroburstController.recoverySeconds +
          MicroburstController.warningSeconds +
          MicroburstController.gustSeconds / 2);
      expect(wind.direction, -1);
      expect(wind.isGusting, isTrue);
      expect(wind.normalizedSway, closeTo(-0.34, 1e-9));
      final xs = <double>[-0.84, -0.40];
      final shared = wind.boundedGroupSway(xs);
      expect(shared, closeTo(-0.04, 1e-9));
      expect(xs[0] + shared, closeTo(-0.88, 1e-9));
      expect(xs[1] + shared, closeTo(-0.44, 1e-9));
      expect(xs[1] - xs[0], closeTo(0.44, 1e-9));
      wind.reset();
      expect(wind.boundedGroupSway(xs), 0);
      expect(wind.direction, 1);
    });

    test('mixed gust preserves flexible, independently drifting ribbon links',
        () {
      final pair = RibbonChainController().createPair(viewportHeight: 800);
      final moved = pair.map((b) => b.movedBy(-250)).toList();
      final natural = moved
          .map((b) => b.driftedX(
              amplitude: RibbonChainController.swayAmplitude,
              frequency: 0.015))
          .toList();
      expect(natural[0], isNot(natural[1]));
      final wind = MicroburstController()
        ..update(MicroburstController.firstCalmSeconds +
            MicroburstController.warningSeconds +
            MicroburstController.gustSeconds / 2);
      final shared = wind.boundedGroupSway(natural);
      final gusted = List.generate(2,
          (i) => moved[i].withXOffset(natural[i] + shared));
      expect(gusted.first.ribbonGroupId, gusted.last.ribbonGroupId);
      expect(gusted.first.type, BalloonType.ribbon);
      expect(gusted.last.type, BalloonType.ribbon);
      expect(gusted.last.xOffset - gusted.first.xOffset,
          closeTo(natural[1] - natural[0], 1e-9));
      expect(
        RibbonChainController.linkedPeers(
          tapped: gusted.first,
          balloons: [gusted.first.pop(), gusted.last],
        ).single.id,
        gusted.last.id,
        reason: 'Wind cannot break linked-pop identity',
      );
    });

    test('28 normal pops alone never win; two real chains are required', () {
      final run = SkywardLevelRun(SkywardWorldOne.level(6));
      for (var i = 0; i < 28; i++) {
        run.recordPop();
      }
      expect(run.popped, 28);
      expect(run.isComplete, isFalse);
      expect(run.stars, 0);
      run.recordPop(balloonsPopped: 2, triggeredChain: true);
      expect(run.chainReactions, 1);
      expect(run.isComplete, isFalse);
      run.recordPop(balloonsPopped: 2, triggeredChain: true);
      expect(run.chainReactions, 2);
      expect(run.popped, 32);
      expect(run.successfulTaps, 30);
      expect(run.isComplete, isTrue);
      expect(run.stars, 3);
    });

    test('Level 6 is unlocked only by saved Level 5 clear', () {
      final afterFour = SkywardWorldOneProgress.fromSaved([3, 3, 3, 3]);
      expect(afterFour.isLevelUnlocked(6), isFalse);
      final afterFive = SkywardWorldOneProgress.fromSaved([3, 3, 3, 3, 3]);
      expect(afterFive.isLevelUnlocked(6), isTrue);
      expect(afterFive.isLevelUnlocked(7), isFalse);
      expect(afterFive.totalStars, 15);
      expect(afterFive.bestStars, hasLength(8));
    });
  });

  testWidgets('mixed-hazard HUD shows both chain goal and advance wind warning',
      (tester) async {
    final run = SkywardLevelRun(SkywardWorldOne.level(6));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SkywardObjectiveHud(
          run: run,
          windWarning: true,
          windDirection: -1,
          onExit: () {},
        ),
      ),
    ));
    expect(find.text('LEVEL 6 · Spiraling Skies'), findsOneWidget);
    expect(find.text('CHAINS 0/2'), findsOneWidget);
    expect(find.text('← CROSSWIND INCOMING'), findsOneWidget);
    expect(find.textContaining('POPS 0/28'), findsOneWidget);
  });

  testWidgets('Level 6 map tile is playable only after Level 5 completion',
      (tester) async {
    final progress = SkywardWorldOneProgress.fromSaved([3, 3, 3, 3, 3]);
    final selected = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: SkywardSelectScreen(
        progress: progress,
        onSelectLevel: selected.add,
        onBack: () {},
      ),
    ));
    await tester.scrollUntilVisible(
      find.text('Spiraling Skies'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Chains 2'), findsWidgets);
    await tester.tap(find.text('Spiraling Skies'));
    expect(selected, [6]);
    await tester.scrollUntilVisible(
      find.text('Leadstorm'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Complete the previous level'), findsWidgets,
        reason: 'Level 6 has not been completed, so Level 7 is still locked');
    await tester.scrollUntilVisible(
      find.text('Carnival Gate'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Complete the previous level'), findsWidgets);
  });
}
