import 'package:balloon_burst/skyward/microburst_controller.dart';
import 'package:balloon_burst/skyward/skyward_play_ui.dart';
import 'package:balloon_burst/skyward/skyward_select_screen.dart';
import 'package:balloon_burst/skyward/world_one.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wind announces itself before the first gust', () {
    final wind = MicroburstController();
    expect(wind.phase, MicroburstPhase.calm);
    expect(wind.normalizedSway, 0);
    expect(wind.warningSoon, isFalse);

    wind.update(MicroburstController.firstCalmSeconds - 0.1);
    expect(wind.phase, MicroburstPhase.calm);
    wind.update(0.1);
    expect(wind.phase, MicroburstPhase.warning);
    expect(wind.warningSoon, isTrue);
    expect(wind.normalizedSway, 0);

    wind.update(MicroburstController.warningSeconds);
    expect(wind.phase, MicroburstPhase.gust);
    expect(wind.gustCount, 1);
    expect(wind.normalizedSway, closeTo(0, 1e-12));
    wind.update(MicroburstController.gustSeconds / 2);
    expect(wind.normalizedSway, closeTo(MicroburstController.maxSway, 1e-9));
    wind.update(MicroburstController.gustSeconds / 2);
    expect(wind.phase, MicroburstPhase.calm);
    expect(wind.normalizedSway, 0);
    expect(wind.direction, -1);
  });

  test('later gusts alternate direction with a full recovery interval', () {
    final wind = MicroburstController();
    wind.update(MicroburstController.firstCalmSeconds +
        MicroburstController.warningSeconds +
        MicroburstController.gustSeconds);
    expect(wind.phase, MicroburstPhase.calm);
    wind.update(MicroburstController.recoverySeconds);
    expect(wind.phase, MicroburstPhase.warning);
    expect(wind.direction, -1);
    wind.update(MicroburstController.warningSeconds +
        MicroburstController.gustSeconds / 2);
    expect(wind.gustCount, 2);
    expect(wind.normalizedSway, closeTo(-MicroburstController.maxSway, 1e-9));
  });

  test('gusts stay within the playfield and do not snap during warning', () {
    final wind = MicroburstController();
    wind.update(MicroburstController.firstCalmSeconds);
    expect(wind.applySway(0.87), 0.87);
    wind.update(MicroburstController.warningSeconds +
        MicroburstController.gustSeconds / 2);

    expect(MicroburstController.maxSway, 0.34);
    expect(wind.applySway(0), closeTo(0.34, 1e-9));
    expect(wind.applySway(0.85), closeTo(0.88, 1e-9));
    expect(wind.applySway(0.95), 0.95,
        reason: 'Do not force a naturally edge-spawned balloon farther out');
    expect(wind.applySway(-0.5), closeTo(-0.16, 1e-9));
  });

  test('reset clears wind phase, direction, and gust count', () {
    final wind = MicroburstController();
    wind.update(32);
    expect(wind.gustCount, greaterThan(0));
    wind.reset();
    expect(wind.phase, MicroburstPhase.calm);
    expect(wind.warningSoon, isFalse);
    expect(wind.normalizedSway, 0);
    expect(wind.direction, 1);
    expect(wind.gustCount, 0);
    expect(wind.secondsRemaining, MicroburstController.firstCalmSeconds);
    wind.update(-1);
    expect(wind.phase, MicroburstPhase.calm);
  });

  test('wind applies to Crosswind Alley; other early levels are unchanged', () {
    expect(SkywardSelectScreen.playableThrough, 8);
    expect(SkywardWorldOne.level(1).hazards.contains(SkywardHazard.microburst),
        isFalse);
    expect(SkywardWorldOne.level(2).hazards.contains(SkywardHazard.microburst),
        isFalse);
    expect(SkywardWorldOne.level(3).hazards.contains(SkywardHazard.microburst),
        isFalse);
    final four = SkywardWorldOne.level(4);
    expect(four.hazards, containsAll([
      SkywardHazard.leadBalloon,
      SkywardHazard.microburst,
    ]));
    expect(four.popsRequired, 24);
    expect(four.leadCatchesRequired, 2);
    expect(SkywardWorldOne.level(8).hazards,
        contains(SkywardHazard.microburst),
        reason: 'Finale reuses the established wind controller');
  });

  testWidgets('HUD warns with direction and announces an active gust',
      (tester) async {
    final run = SkywardLevelRun(SkywardWorldOne.level(4));
    Widget hud({required bool warning, required bool gust, required int dir}) =>
        MaterialApp(
          home: Scaffold(
            body: SkywardObjectiveHud(
              run: run,
              windWarning: warning,
              windGusting: gust,
              windDirection: dir,
              onExit: () {},
            ),
          ),
        );

    await tester.pumpWidget(hud(warning: true, gust: false, dir: -1));
    expect(find.text('← CROSSWIND INCOMING'), findsOneWidget);
    expect(find.textContaining('LEAD 0/2'), findsOneWidget);
    await tester.pumpWidget(hud(warning: false, gust: true, dir: 1));
    expect(find.text('→ GUST! KEEP YOUR AIM'), findsOneWidget);
    await tester.pumpWidget(hud(warning: false, gust: false, dir: 1));
    expect(find.byKey(const ValueKey('skyward-wind-warning')), findsNothing);
  });
}
