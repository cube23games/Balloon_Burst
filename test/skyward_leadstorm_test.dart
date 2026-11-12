import 'package:balloon_burst/game/balloon_type.dart';
import 'package:balloon_burst/gameplay/balloon.dart';
import 'package:balloon_burst/skyward/lead_balloon_controller.dart';
import 'package:balloon_burst/skyward/microburst_controller.dart';
import 'package:balloon_burst/skyward/ribbon_chain_controller.dart';
import 'package:balloon_burst/skyward/skyward_play_ui.dart';
import 'package:balloon_burst/skyward/skyward_select_screen.dart';
import 'package:balloon_burst/skyward/world_one.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SkywardLevelRun _completeLeadstorm() {
  final run = SkywardLevelRun(SkywardWorldOne.level(7));

  // 23 normal taps, 3 genuine descending lead catches, 2 physical
  // two-balloon chains. Exactly 30 popped balloons but just 28 human taps.
  for (var i = 0; i < 23; i++) {
    run.recordPop();
  }
  for (var i = 0; i < 3; i++) {
    run.recordPop(leadCaught: true);
  }
  for (var i = 0; i < 2; i++) {
    run.recordPop(balloonsPopped: 2, triggeredChain: true);
  }
  return run;
}

void main() {
  group('TJ-44G — Leadstorm three-hazard composition', () {
    test('Level 7 uses the published three distinct hazard objectives', () {
      final level = SkywardWorldOne.level(7);
      expect(level.number, 7);
      expect(level.title, 'Leadstorm');
      expect(level.popsRequired, 30);
      expect(level.leadCatchesRequired, 3);
      expect(level.chainReactionsRequired, 2);
      expect(level.maxEscapes, 2);
      expect(level.hazards, {
        SkywardHazard.leadBalloon,
        SkywardHazard.microburst,
        SkywardHazard.ribbonChain,
      });
      expect(SkywardSelectScreen.playableThrough, 8);
      expect(SkywardWorldOne.level(6).leadCatchesRequired, 0);
      expect(SkywardWorldOne.level(8).unlocksCarnival, isTrue);
      expect(SkywardWorldOne.level(8).maxEscapes, 1,
          reason: 'Carnival Gate is the tougher final challenge');
    });

    test('each timer independently starts under active gameplay time', () {
      final leads = LeadBalloonController();
      final wind = MicroburstController();
      final ribbons = RibbonChainController();

      expect(leads.update(dt: 1.5, hasActiveLead: false), isFalse);
      expect(leads.warningSoon, isTrue);
      expect(leads.update(dt: 1.5, hasActiveLead: false), isTrue);
      final lead = leads.createLead();
      expect(lead.type, BalloonType.lead);
      expect(lead.y, lessThan(0));
      expect(leads.update(dt: 100, hasActiveLead: true), isFalse,
          reason: 'At most one live descending lead exists at once');

      expect(wind.update(MicroburstController.firstCalmSeconds), isTrue);
      expect(wind.phase, MicroburstPhase.warning);
      expect(wind.normalizedSway, 0);

      expect(ribbons.update(dt: 4.0, hasActiveRibbon: false), isTrue);
      final pair = ribbons.createPair(viewportHeight: 920);
      expect(pair, hasLength(2));
      expect(pair.every((b) => b.type == BalloonType.ribbon), isTrue);
      expect(ribbons.update(dt: 100, hasActiveRibbon: true), isFalse,
          reason: 'No second pair is spawned while the first is alive');

      wind.update(MicroburstController.warningSeconds +
          MicroburstController.gustSeconds / 2);
      expect(wind.isGusting, isTrue);
      expect(wind.direction, 1);
      final naturalXs = pair.map((b) => b.xOffset).toList();
      final windShift = wind.boundedGroupSway(naturalXs);
      expect(windShift, greaterThan(0));
      expect(
        (naturalXs.last + windShift) - (naturalXs.first + windShift),
        closeTo(naturalXs.last - naturalXs.first, 1e-9),
        reason: 'Simultaneous gust cannot stretch a linked pair',
      );
      expect(lead.ribbonGroupId, isNull);
      expect(lead.xOffset, lead.baseXOffset,
          reason: 'Descending lead has its own motion; no wind in lead model');
    });

    test('a lead never triggers a ribbon chain, even when balloons overlap', () {
      final lead = LeadBalloonController().createLead();
      final pair = RibbonChainController().createPair(viewportHeight: 800);
      final overlapping = Balloon(
        id: lead.id,
        y: pair.first.y,
        xOffset: pair.first.xOffset,
        baseXOffset: pair.first.xOffset,
        type: BalloonType.lead,
      );
      expect(
        RibbonChainController.linkedPeers(
          tapped: overlapping,
          balloons: [overlapping.pop(), ...pair],
        ),
        isEmpty,
      );
      final peers = RibbonChainController.linkedPeers(
        tapped: pair.first,
        balloons: [pair.first.pop(), pair.last, overlapping],
      );
      expect(peers.map((b) => b.id), [pair.last.id],
          reason: 'Only a live member with matching ribbon group can chain');

      final run = SkywardLevelRun(SkywardWorldOne.level(7));
      run.recordPop(leadCaught: true);
      expect(run.leadCatches, 1);
      expect(run.chainReactions, 0);
      run.recordPop(balloonsPopped: 2, triggeredChain: true);
      expect(run.popped, 3);
      expect(run.leadCatches, 1);
      expect(run.chainReactions, 1);
      expect(run.successfulTaps, 2,
          reason: 'One lead tap and one ribbon tap; no imaginary second tap');
    });

    test('30 ordinary pops and two chains cannot replace three lead catches',
        () {
      final run = SkywardLevelRun(SkywardWorldOne.level(7));
      for (var i = 0; i < 30; i++) {
        run.recordPop();
      }
      for (var i = 0; i < 2; i++) {
        run.recordPop(balloonsPopped: 2, triggeredChain: true);
      }
      expect(run.popped, 34);
      expect(run.chainReactions, 2);
      expect(run.leadCatches, 0);
      expect(run.isComplete, isFalse);
      for (var i = 0; i < 3; i++) {
        run.recordPop(leadCaught: true);
      }
      expect(run.isComplete, isTrue);
    });

    test('30 pops and three lead catches cannot replace two chains', () {
      final run = SkywardLevelRun(SkywardWorldOne.level(7));
      for (var i = 0; i < 30; i++) {
        run.recordPop();
      }
      for (var i = 0; i < 3; i++) {
        run.recordPop(leadCaught: true);
      }
      expect(run.isComplete, isFalse);
      run.recordPop(balloonsPopped: 2, triggeredChain: true);
      expect(run.isComplete, isFalse);
      run.recordPop(balloonsPopped: 2, triggeredChain: true);
      expect(run.isComplete, isTrue);
    });

    test('all three goals can complete with two physical secondary pops', () {
      final run = _completeLeadstorm();
      expect(run.popped, 30);
      expect(run.leadCatches, 3);
      expect(run.chainReactions, 2);
      expect(run.successfulTaps, 28);
      expect(run.tapAccuracy, 1);
      expect(run.isComplete, isTrue);
      expect(run.stars, 3);
      run.recordPop(leadCaught: true, triggeredChain: true);
      expect(run.popped, 30,
          reason: 'Finished levels cannot grant additional credit');
    });

    test('ribbon group escape is one penalty; lead escape is separate', () {
      final ribbons = RibbonChainController();
      final pair = ribbons.createPair(viewportHeight: 700);
      final lead = LeadBalloonController().createLead().movedBy(900);
      expect(
        LeadBalloonController.isBeyondExit(
          balloon: lead,
          viewportHeight: 700,
          margin: 24,
        ),
        isTrue,
      );
      final run = SkywardLevelRun(SkywardWorldOne.level(7));
      if (ribbons.shouldCountEscape(pair.first)) run.recordEscape();
      if (ribbons.shouldCountEscape(pair.last)) run.recordEscape();
      expect(run.escaped, 1);
      run.recordEscape(); // the lead escaped separately
      expect(run.escaped, 2);
      expect(run.isFailed, isFalse);
      run.recordEscape(); // third escape ends the level
      expect(run.escaped, 3);
      expect(run.isFailed, isTrue);
      run.recordPop(leadCaught: true);
      expect(run.leadCatches, 0,
          reason: 'A failed run cannot keep accumulating objective credit');
    });

    test('replay resets all three independently scheduled hazards', () {
      final leads = LeadBalloonController();
      final wind = MicroburstController();
      final ribbons = RibbonChainController();
      leads.update(dt: 3.1, hasActiveLead: false);
      leads.createLead();
      wind.update(6.5);
      ribbons.update(dt: 4.1, hasActiveRibbon: false);
      final pair = ribbons.createPair(viewportHeight: 900);
      ribbons.shouldCountEscape(pair.first);

      leads.reset();
      wind.reset();
      ribbons.reset();
      expect(leads.spawnedCount, 0);
      expect(leads.secondsUntilNext, LeadBalloonController.firstDelaySeconds);
      expect(wind.phase, MicroburstPhase.calm);
      expect(wind.gustCount, 0);
      expect(wind.direction, 1);
      expect(ribbons.spawnedGroups, 0);
      expect(ribbons.secondsUntilNext, RibbonChainController.firstDelaySeconds);
      expect(ribbons.shouldCountEscape(pair.first), isTrue);
    });

    test('saved six-level progress unlocks 7, never plays 8 prematurely', () {
      final afterFive =
          SkywardWorldOneProgress.fromSaved([3, 3, 3, 3, 3]);
      expect(afterFive.isLevelUnlocked(7), isFalse);
      final afterSix =
          SkywardWorldOneProgress.fromSaved([3, 3, 3, 3, 3, 3]);
      expect(afterSix.totalStars, 18);
      expect(afterSix.isLevelUnlocked(7), isTrue);
      expect(afterSix.isLevelUnlocked(8), isFalse);
      afterSix.submit(_completeLeadstorm());
      expect(afterSix.totalStars, 21);
      expect(afterSix.isLevelUnlocked(8), isTrue);
      expect(SkywardSelectScreen.playableThrough, 8,
          reason: 'Level 8 is playable after the Level 7 progress gate');
    });
  });

  testWidgets('three goals plus simultaneous whistle and gust warnings fit HUD',
      (tester) async {
    final run = SkywardLevelRun(SkywardWorldOne.level(7));
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
    expect(find.text('LEVEL 7 · Leadstorm'), findsOneWidget);
    expect(find.textContaining('POPS 0/30'), findsOneWidget);
    expect(find.text('LEAD 0/3'), findsOneWidget);
    expect(find.text('CHAINS 0/2'), findsOneWidget);
    expect(find.text('↓ WHISTLE! LEAD INCOMING'), findsOneWidget);
    expect(find.text('← CROSSWIND INCOMING'), findsOneWidget);
    expect(tester.takeException(), isNull);

    run.recordPop(leadCaught: true);
    run.recordPop(balloonsPopped: 2, triggeredChain: true);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SkywardObjectiveHud(
          run: run,
          windGusting: true,
          windDirection: 1,
          onExit: () {},
        ),
      ),
    ));
    expect(find.text('LEAD 1/3'), findsOneWidget);
    expect(find.text('CHAINS 1/2'), findsOneWidget);
    expect(find.text('→ GUST! KEEP YOUR AIM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Leadstorm selectable after Level 6; Carnival Gate still locked',
      (tester) async {
    final progress = SkywardWorldOneProgress.fromSaved([3, 3, 3, 3, 3, 3]);
    final selected = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: SkywardSelectScreen(
        progress: progress,
        onSelectLevel: selected.add,
        onBack: () {},
      ),
    ));

    await tester.scrollUntilVisible(
      find.text('Leadstorm'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Lead 3'), findsWidgets);
    expect(find.textContaining('Chains 2'), findsWidgets);
    await tester.tap(find.text('Leadstorm'));
    expect(selected, [7]);

    await tester.scrollUntilVisible(
      find.text('Carnival Gate'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Complete the previous level'), findsWidgets);
    await tester.tap(find.text('Carnival Gate'));
    expect(selected, [7],
        reason: 'Level 8 requires Level 7 victory, not just visibility');
  });
}
