import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:balloon_burst/gameplay/balloon.dart';

const bool kEnableQaAutoTap =
    bool.fromEnvironment('ENABLE_QA_AUTOTAP', defaultValue: false);

enum AutoTapMode {
  clean,
  human,
  fail,
}

extension AutoTapModeX on AutoTapMode {
  String get label {
    switch (this) {
      case AutoTapMode.clean:
        return 'CLEAN';
      case AutoTapMode.human:
        return 'HUMAN';
      case AutoTapMode.fail:
        return 'FAIL';
    }
  }

  AutoTapMode get next {
    switch (this) {
      case AutoTapMode.clean:
        return AutoTapMode.human;
      case AutoTapMode.human:
        return AutoTapMode.fail;
      case AutoTapMode.fail:
        return AutoTapMode.clean;
    }
  }
}

class AutoTapController {
  AutoTapController({
    this.enabled = false,
    this.mode = AutoTapMode.clean,
    this.benchmarkSeed,
  });

  bool enabled;
  AutoTapMode mode;

  final int? benchmarkSeed;
  late Random _random = Random(benchmarkSeed);
  int? _lastBenchmarkTapMs;
  DateTime? _lastTapAt;

  void reset() {
    _lastTapAt = null;
    _lastBenchmarkTapMs = null;
    if (benchmarkSeed != null) _random = Random(benchmarkSeed);
  }

  void update({
    required bool canTap,
    required Size lastSize,
    required List<Balloon> balloons,
    required ValueChanged<Offset> onTapAt,
    int? benchmarkElapsedMs,
  }) {
    if (!kDebugMode && !kEnableQaAutoTap) return;
    if (!enabled) return;
    if (!canTap) return;
    if (lastSize == Size.zero) return;
    if (balloons.isEmpty) return;

    final benchmark = benchmarkSeed != null;
    if (benchmark && (benchmarkElapsedMs == null || benchmarkElapsedMs < 0)) return;
    final now = DateTime.now();
    // Fixed cadence avoids consuming random numbers on rejected frames.
    final reactionMs = benchmark ? 100 : _reactionMs();
    if (benchmark && _lastBenchmarkTapMs != null &&
        benchmarkElapsedMs! - _lastBenchmarkTapMs! < reactionMs) return;

    if (!benchmark && _lastTapAt != null &&
        now.difference(_lastTapAt!).inMilliseconds < reactionMs) {
      return;
    }

    final target = _pickTarget(balloons);
    if (target == null) return;

    if (_shouldSkipTap()) {
      _lastTapAt = now;
      if (benchmark) _lastBenchmarkTapMs = benchmarkElapsedMs;
      return;
    }

    final tapPoint = _tapPointFor(
      balloon: target,
      lastSize: lastSize,
    );

    onTapAt(tapPoint);
    _lastTapAt = now;
    if (benchmark) _lastBenchmarkTapMs = benchmarkElapsedMs;
  }

  Balloon? _pickTarget(List<Balloon> balloons) {
    final active = balloons.where((b) => !b.isPopped).toList();
    if (active.isEmpty) return null;

    active.sort((a, b) => a.y.compareTo(b.y));

    switch (mode) {
      case AutoTapMode.clean:
        return active.first;
      case AutoTapMode.human:
        final pickFrom = active.length >= 2 ? 2 : 1;
        return active[_random.nextInt(pickFrom)];
      case AutoTapMode.fail:
        if (active.length >= 3) {
          return active[min(active.length - 1, 2)];
        }
        return active.last;
    }
  }

  bool _shouldSkipTap() {
    switch (mode) {
      case AutoTapMode.clean:
        return false;
      case AutoTapMode.human:
        return _random.nextDouble() < 0.06;
      case AutoTapMode.fail:
        return _random.nextDouble() < 0.35;
    }
  }

  int _reactionMs() {
    switch (mode) {
      case AutoTapMode.clean:
        return 55 + _random.nextInt(16);
      case AutoTapMode.human:
        return 80 + _random.nextInt(51);
      case AutoTapMode.fail:
        return 120 + _random.nextInt(81);
    }
  }

  double _jitterPx() {
    switch (mode) {
      case AutoTapMode.clean:
        return 0.0;
      case AutoTapMode.human:
        return 3.0;
      case AutoTapMode.fail:
        return 8.0;
    }
  }

  Offset _tapPointFor({
    required Balloon balloon,
    required Size lastSize,
  }) {
    final centerX = lastSize.width * 0.5;
    final widthHalf = lastSize.width * 0.5;

    final bx = centerX + (balloon.xOffset * widthHalf);
    final by = balloon.y;
    final jitter = _jitterPx();

    return Offset(
      bx + _randomSigned(jitter),
      by + _randomSigned(jitter),
    );
  }

  double _randomSigned(double maxAbs) {
    if (maxAbs <= 0) return 0;
    return (_random.nextDouble() * 2.0 - 1.0) * maxAbs;
  }
}
