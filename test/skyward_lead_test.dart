import 'package:flutter_test/flutter_test.dart';
import 'package:balloon_burst/game/balloon_type.dart';
import 'package:balloon_burst/gameplay/balloon.dart';
import 'package:balloon_burst/skyward/lead_balloon_controller.dart';
import 'package:balloon_burst/skyward/world_one.dart';

void main() {
  group('TJ-44C lead balloon schedule', () {
    test('warning precedes spawn and timing never depends on wall clock', () {
      final timer = LeadBalloonController();
      expect(timer.warningSoon, isFalse);
      expect(timer.update(dt: 1.7, hasActiveLead: false), isFalse);
      expect(timer.warningSoon, isTrue);
      expect(timer.update(dt: 1.31, hasActiveLead: false), isTrue);
      expect(timer.warningSoon, isFalse);
      expect(timer.spawnedCount, 0);
      final lead = timer.createLead();
      expect(lead.id, 'skyward_lead_0');
      expect(lead.y, lessThan(0));
      expect(lead.type, BalloonType.lead);
      expect(timer.spawnedCount, 1);
    });

    test('only one live lead may spawn; timer resumes after pop/escape', () {
      final timer = LeadBalloonController();
      expect(timer.update(dt: 3.1, hasActiveLead: false), isTrue);
      final a = timer.createLead();
      expect(timer.update(dt: 100.0, hasActiveLead: true), isFalse);
      expect(timer.spawnedCount, 1);
      expect(timer.update(dt: 6.4, hasActiveLead: false), isFalse);
      expect(timer.warningSoon, isTrue);
      expect(timer.update(dt: 0.11, hasActiveLead: false), isTrue);
      final b = timer.createLead();
      expect(b.id, isNot(a.id));
      expect(b.xOffset, isNot(a.xOffset));
    });

    test('descending lead uses bottom exit; regular rises to top exit', () {
      final controller = LeadBalloonController();
      final lead = controller.createLead().movedBy(1050);
      expect(
        LeadBalloonController.isBeyondExit(
          balloon: lead,
          viewportHeight: 900,
          margin: 16,
        ),
        isTrue,
      );
      expect(
        LeadBalloonController.isBeyondExit(
          balloon: controller.createLead(),
          viewportHeight: 900,
          margin: 16,
        ),
        isFalse,
      );
      final rising = Balloon(
        id: 'original',
        y: -17,
        type: BalloonType.standard,
      );
      expect(
        LeadBalloonController.isBeyondExit(
          balloon: rising,
          viewportHeight: 900,
          margin: 16,
        ),
        isTrue,
      );
      expect(
        LeadBalloonController.isBeyondExit(
          balloon: Balloon(id: 'rising-in-bounds', y: 200),
          viewportHeight: 900,
          margin: 16,
        ),
        isFalse,
      );
    });

    test('reset restores deterministic first-spawn pattern', () {
      final timer = LeadBalloonController();
      timer.update(dt: 5, hasActiveLead: false);
      final first = timer.createLead();
      timer.reset();
      expect(timer.secondsUntilNext, LeadBalloonController.firstDelaySeconds);
      expect(timer.spawnedCount, 0);
      expect(timer.createLead().baseXOffset, first.baseXOffset);
    });
  });

  group('Skyward objective accounting', () {
    test('Whistle Drop requires actual lead catches', () {
      final level = SkywardWorldOne.level(3);
      expect(level.leadCatchesRequired, 2);
      final run = SkywardLevelRun(level);
      for (var i = 0; i < level.popsRequired; i++) {
        run.recordPop();
      }
      expect(run.isComplete, isFalse);
      run.recordPop(leadCaught: true);
      expect(run.isComplete, isFalse);
      run.recordPop(leadCaught: true);
      expect(run.isComplete, isTrue);
      expect(run.leadCatches, 2);
    });

    test('zero-weight lead never enters normal weighted random pool', () {
      expect(balloonTypeConfig[BalloonType.lead]!.spawnWeight, 0);
      expect(balloonTypeConfig[BalloonType.standard]!.spawnWeight, greaterThan(0));
    });
  });
}
