import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';
import 'package:balloon_burst/gameplay/balloon.dart';

void main() {
  const balloons = [
    Balloon(id: 'a', y: 100),
    Balloon(id: 'b', y: 200, xOffset: 0.3),
  ];

  test('benchmark requires simulation time and respects fixed cadence', () {
    final controller = AutoTapController(enabled: true, benchmarkSeed: 42);
    final taps = <Offset>[];
    void tick(int? ms) => controller.update(
          canTap: true,
          lastSize: const Size(400, 800),
          balloons: balloons,
          onTapAt: taps.add,
          benchmarkElapsedMs: ms,
        );
    tick(null);
    tick(-1);
    expect(taps, isEmpty);
    tick(0);
    tick(99);
    expect(taps, [const Offset(200, 100)]);
    tick(100);
    expect(taps.length, 2);
    controller.reset();
    tick(0);
    expect(taps.length, 3);
  });

  test('seeded human-mode replay ignores rejected intermediate frames', () {
    final controller = AutoTapController(
      enabled: true, benchmarkSeed: 42, mode: AutoTapMode.human,
    );
    List<Offset> run(bool extraFrames) {
      final taps = <Offset>[];
      void tick(int ms) => controller.update(
            canTap: true,
            lastSize: const Size(400, 800),
            balloons: balloons,
            onTapAt: taps.add,
            benchmarkElapsedMs: ms,
          );
      for (var ms = 0; ms < 2000; ms += 100) {
        tick(ms);
        if (extraFrames) tick(ms + 50);
      }
      return taps;
    }
    final first = run(false);
    expect(first, isNotEmpty);
    controller.reset();
    expect(run(true), first);
  });
}
