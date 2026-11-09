import 'package:balloon_burst/game/balloon_type.dart';
import 'package:balloon_burst/gameplay/balloon.dart';
import 'package:balloon_burst/skyward/ribbon_chain_controller.dart';
import 'package:balloon_burst/skyward/skyward_play_ui.dart';
import 'package:balloon_burst/skyward/skyward_select_screen.dart';
import 'package:balloon_burst/skyward/world_one.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TJ-44E ribbon spawn and linkage', () {
    test('ribbon spawn pool is exclusive to Skyward', () {
      expect(balloonTypeConfig[BalloonType.ribbon]!.spawnWeight, 0.0);
      expect(balloonTypeConfig[BalloonType.lead]!.spawnWeight, 0.0);
      expect(balloonTypeConfig[BalloonType.standard]!.spawnWeight, greaterThan(0));
      expect(SkywardWorldOne.level(4).hazards, isNot(contains(SkywardHazard.ribbonChain)));
      expect(SkywardWorldOne.level(5).hazards, contains(SkywardHazard.ribbonChain));
      expect(SkywardSelectScreen.playableThrough, 5);
    });

    test('one connected pair enters after active gameplay and blocks respawn', () {
      final ribbon = RibbonChainController();
      expect(ribbon.update(dt: 3.9, hasActiveRibbon: false), isFalse);
      expect(ribbon.update(dt: 0.1, hasActiveRibbon: false), isTrue);
      final pair = ribbon.createPair(viewportHeight: 800);
      expect(pair, hasLength(2));
      expect(pair.every((b) => b.type == BalloonType.ribbon), isTrue);
      expect(pair.first.ribbonGroupId, pair.last.ribbonGroupId);
      expect(pair.first.id, isNot(pair.last.id));
      expect(pair.first.y, 800 + RibbonChainController.entryPaddingY - 5);
      expect(pair.last.y, pair.first.y + 10,
          reason: 'A loose ribbon pair should not resemble a level bar');
      expect(pair.first.phase, isNot(pair.last.phase));
      expect(pair.last.xOffset - pair.first.xOffset, closeTo(0.34, 1e-9));
      expect(ribbon.spawnedGroups, 1);

      expect(ribbon.update(dt: 100, hasActiveRibbon: true), isFalse);
      expect(ribbon.spawnedGroups, 1);
      expect(ribbon.update(dt: 5.49, hasActiveRibbon: false), isFalse);
      expect(ribbon.update(dt: 0.02, hasActiveRibbon: false), isTrue);
      final second = ribbon.createPair(viewportHeight: 800);
      expect(second.first.ribbonGroupId, isNot(pair.first.ribbonGroupId));
    });

    test('two ribbon partners sway independently while keeping their tether', () {
      final pair = RibbonChainController().createPair(viewportHeight: 800);
      final a = pair.first.movedBy(-180);
      final b = pair.last.movedBy(-180);
      final leftX = a.driftedX(
        amplitude: RibbonChainController.swayAmplitude,
        frequency: 0.015,
      );
      final rightX = b.driftedX(
        amplitude: RibbonChainController.swayAmplitude,
        frequency: 0.015,
      );
      final leftSway = leftX - a.baseXOffset;
      final rightSway = rightX - b.baseXOffset;
      expect((leftSway - rightSway).abs(), greaterThan(0.005),
          reason: 'Partners should float individually, not in lockstep');
      expect((rightX - leftX).abs(), lessThan(0.65),
          reason: 'Pair should remain visually connected, not fly apart');
      expect(RibbonChainController.sharedRiseSpeedMultiplier, 1.0);
    });

    test('immutable positions and pop preserve ribbon group identity', () {
      final original =
          RibbonChainController().createPair(viewportHeight: 800).first;
      expect(original.movedBy(-12).ribbonGroupId, original.ribbonGroupId);
      expect(original.withXOffset(0.2).ribbonGroupId, original.ribbonGroupId);
      expect(original.pop().ribbonGroupId, original.ribbonGroupId);
    });

    test('one direct tap selects one living peer; never unrelated balloons', () {
      final ctrl = RibbonChainController();
      final pairA = ctrl.createPair(viewportHeight: 800);
      final pairB = ctrl.createPair(viewportHeight: 800);
      final other = Balloon(id: 'unrelated', y: 800);
      final active = <Balloon>[
        pairA.first.pop(), // The tap handler already popped the target.
        pairA.last,
        pairB.first,
        pairB.last,
        other,
      ];
      final peers = RibbonChainController.linkedPeers(
        tapped: pairA.first,
        balloons: active,
      );
      expect(peers.map((b) => b.id), [pairA.last.id]);
      expect(
        RibbonChainController.linkedPeers(
          tapped: pairA.first,
          balloons: active.map((b) => b.id == pairA.last.id ? b.pop() : b),
        ),
        isEmpty,
      );
      expect(
        RibbonChainController.linkedPeers(tapped: other, balloons: active),
        isEmpty,
      );
    });

    test('a missed pair consumes one escape, even on another frame', () {
      final ctrl = RibbonChainController();
      final pair = ctrl.createPair(viewportHeight: 800);
      expect(ctrl.shouldCountEscape(pair.first), isTrue);
      expect(ctrl.shouldCountEscape(pair.last), isFalse);
      expect(ctrl.shouldCountEscape(Balloon(id: 'normal', y: -20)), isTrue);
      final next = ctrl.createPair(viewportHeight: 800);
      expect(ctrl.shouldCountEscape(next.first), isTrue);
      ctrl.reset();
      expect(ctrl.shouldCountEscape(pair.first), isTrue);
      expect(ctrl.spawnedGroups, 0);
      expect(ctrl.secondsUntilNext, RibbonChainController.firstDelaySeconds);
    });

    test('Level 5 needs two actual chain reactions, not just pop count', () {
      final run = SkywardLevelRun(SkywardWorldOne.level(5));
      for (var i = 0; i < 25; i++) {
        run.recordPop();
      }
      expect(run.isComplete, isFalse);
      expect(run.chainReactions, 0);

      run.recordPop(balloonsPopped: 2, triggeredChain: true);
      expect(run.isComplete, isFalse);
      expect(run.chainReactions, 1);
      expect(run.popped, 27);

      run.recordPop(balloonsPopped: 2, triggeredChain: true);
      expect(run.isComplete, isTrue);
      expect(run.popped, 29);
      expect(run.chainReactions, 2);
      expect(run.successfulTaps, 27,
          reason: 'Two partner pops did not add imaginary human taps');
      expect(run.stars, 3);
    });

    test('completed Level 4 unlocks Level 5; Level 6 remains gated', () {
      final progress = SkywardWorldOneProgress.fromSaved([3, 3, 3, 3]);
      expect(progress.isLevelUnlocked(5), isTrue);
      expect(progress.isLevelUnlocked(6), isFalse);
    });
  });

  testWidgets('Skyward objective HUD reports required chains', (tester) async {
    final run = SkywardLevelRun(SkywardWorldOne.level(5));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SkywardObjectiveHud(run: run, onExit: () {}),
      ),
    ));
    expect(find.text('LEVEL 5 · Ribbon Reaction'), findsOneWidget);
    expect(find.text('CHAINS 0/2'), findsOneWidget);
    run.recordPop(balloonsPopped: 2, triggeredChain: true);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SkywardObjectiveHud(run: run, onExit: () {}),
      ),
    ));
    expect(find.text('CHAINS 1/2'), findsOneWidget);
  });
}
