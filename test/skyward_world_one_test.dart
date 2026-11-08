import 'package:flutter_test/flutter_test.dart';
import 'package:balloon_burst/skyward/world_one.dart';

SkywardLevelRun clearLevel(SkywardLevelDefinition level) {
  final run = SkywardLevelRun(level);
  for (var i = 0; i < level.popsRequired; i++) {
    run.recordPop(
      leadCaught: i < level.leadCatchesRequired,
      triggeredChain: i < level.chainReactionsRequired,
    );
  }
  return run;
}

void main() {
  group('World 1 design catalog', () {
    test('contains eight ordered, unique objective levels', () {
      expect(SkywardWorldOne.levels.length, 8);
      expect(
        SkywardWorldOne.levels.map((level) => level.number).toList(),
        [1, 2, 3, 4, 5, 6, 7, 8],
      );
      expect(
        SkywardWorldOne.levels.map((level) => level.title).toSet().length,
        8,
      );
      for (final level in SkywardWorldOne.levels) {
        expect(level.popsRequired, greaterThan(0));
        expect(level.leadCatchesRequired, lessThanOrEqualTo(level.popsRequired));
        expect(level.chainReactionsRequired, lessThanOrEqualTo(level.popsRequired));
      }
    });

    test('introduces lead, wind, and ribbon chain before mixing them', () {
      expect(
        SkywardWorldOne.level(3).hazards,
        contains(SkywardHazard.leadBalloon),
      );
      expect(
        SkywardWorldOne.level(4).hazards,
        contains(SkywardHazard.microburst),
      );
      expect(
        SkywardWorldOne.level(5).hazards,
        contains(SkywardHazard.ribbonChain),
      );
      expect(SkywardWorldOne.level(8).hazards.length, 3);
      expect(SkywardWorldOne.level(8).unlocksCarnival, isTrue);
      expect(() => SkywardWorldOne.level(9), throwsRangeError);
    });
  });

  group('One level attempt', () {
    test('a normal tap adds one pop; a chain can add multiple pops', () {
      final run = SkywardLevelRun(SkywardWorldOne.level(5));
      run.recordPop(balloonsPopped: 3, triggeredChain: true);
      expect(run.popped, 3);
      expect(run.successfulTaps, 1);
      expect(run.chainReactions, 1);
      expect(run.tapAccuracy, 1.0);
    });

    test('lead and chain objectives must both be met', () {
      final level = SkywardWorldOne.level(7);
      final run = SkywardLevelRun(level);
      for (var i = 0; i < level.popsRequired; i++) {
        run.recordPop();
      }
      expect(run.isComplete, isFalse);
      expect(run.stars, 0);
    });

    test('failed escapes prevent completion and freeze counters', () {
      final run = SkywardLevelRun(SkywardWorldOne.level(8));
      run.recordEscape();
      run.recordEscape();
      expect(run.isFailed, isTrue);
      run.recordPop(leadCaught: true);
      expect(run.popped, 0);
      expect(run.stars, 0);
    });

    test('first, second, third star have distinct requirements', () {
      final level = SkywardWorldOne.level(1);
      final perfect = clearLevel(level);
      expect(perfect.stars, 3);

      final good = SkywardLevelRun(level);
      for (var i = 0; i < 11; i++) {
        good.recordPop();
      }
      good.recordMiss();
      good.recordPop();
      expect(good.stars, 2);

      final adequate = SkywardLevelRun(level);
      for (var i = 0; i < 4; i++) {
        adequate.recordMiss();
      }
      for (var i = 0; i < level.popsRequired; i++) {
        adequate.recordPop();
      }
      expect(adequate.stars, 1);
    });

    test('events are ignored after a level clears', () {
      final run = clearLevel(SkywardWorldOne.level(1));
      run.recordMiss();
      run.recordEscape();
      run.recordPop();
      expect(run.missedTaps, 0);
      expect(run.escaped, 0);
      expect(run.popped, 12);
      expect(() => run.recordPop(balloonsPopped: 0), throwsArgumentError);
    });
  });

  group('World 1 unlock progression', () {
    test('only level 1 starts unlocked', () {
      final progress = SkywardWorldOneProgress();
      expect(progress.isLevelUnlocked(1), isTrue);
      expect(progress.isLevelUnlocked(2), isFalse);
      expect(progress.nextLevel, 1);
      expect(progress.totalStars, 0);
      expect(progress.carnivalUnlocked, isFalse);
    });

    test('does not accept locked, incomplete, or custom level results', () {
      final progress = SkywardWorldOneProgress();
      final level1 = SkywardWorldOne.level(1);
      expect(() => progress.submit(SkywardLevelRun(level1)), throwsStateError);
      expect(
        () => progress.submit(clearLevel(SkywardWorldOne.level(2))),
        throwsStateError,
      );
      final imitation = SkywardLevelDefinition(
        number: 1,
        title: level1.title,
        popsRequired: level1.popsRequired,
      );
      expect(
        () => progress.submit(clearLevel(imitation)),
        throwsArgumentError,
      );
    });

    test('stars do not regress when a player replays a level', () {
      final progress = SkywardWorldOneProgress();
      final level = SkywardWorldOne.level(1);
      progress.submit(clearLevel(level));
      final weak = SkywardLevelRun(level);
      for (var i = 0; i < 4; i++) {
        weak.recordMiss();
      }
      for (var i = 0; i < level.popsRequired; i++) {
        weak.recordPop();
      }
      progress.submit(weak);
      expect(progress.bestStars[0], 3);
      expect(progress.isLevelUnlocked(2), isTrue);
    });

    test('all eight completed levels unlock carnival checkpoint', () {
      final progress = SkywardWorldOneProgress();
      for (final level in SkywardWorldOne.levels) {
        expect(progress.isLevelUnlocked(level.number), isTrue);
        progress.submit(clearLevel(level));
      }
      expect(progress.worldComplete, isTrue);
      expect(progress.carnivalUnlocked, isTrue);
      expect(progress.totalStars, 24);
      expect(progress.bestStars, hasLength(8));
      expect(() => progress.bestStars[0] = 0, throwsUnsupportedError);
    });

    test('saved data is clamped, gaps cannot unlock later levels', () {
      final progress = SkywardWorldOneProgress.fromSaved([9, -3, 3, 3]);
      expect(progress.bestStars, [3, 0, 0, 0, 0, 0, 0, 0]);
      expect(progress.nextLevel, 2);
      expect(progress.isLevelUnlocked(3), isFalse);
    });
  });
}
