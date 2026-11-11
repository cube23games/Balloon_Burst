import 'dart:math';
import 'package:balloon_burst/game/balloon_type.dart';

/// Balloon
///
/// Immutable value object representing a single balloon.
/// Rising Worlds version: balloons spawn BELOW the screen and rise upward.
class Balloon {
  final String id;
  final bool isPopped;

  /// Vertical position
  final double y;

  /// Horizontal render offset
  final double xOffset;

  /// Spawn/base offset
  final double baseXOffset;

  /// Unique deterministic phase
  final double phase;

  /// Balloon type
  final BalloonType type;

  /// Non-null only for ribbon balloons linked within one Skyward chain group.
  final String? ribbonGroupId;

  /// Age in seconds (used for smooth motion)
  final double age;

  const Balloon({
    required this.id,
    this.isPopped = false,
    required this.y,
    this.xOffset = 0.0,
    this.baseXOffset = 0.0,
    this.phase = 0.0,
    this.type = BalloonType.standard,
    this.ribbonGroupId,
    this.age = 0.0,
  });

  Balloon pop() => Balloon(
        id: id,
        isPopped: true,
        y: y,
        xOffset: xOffset,
        baseXOffset: baseXOffset,
        phase: phase,
        type: type,
        ribbonGroupId: ribbonGroupId,
        age: age,
      );

  Balloon movedBy(double dy) => Balloon(
        id: id,
        isPopped: isPopped,
        y: y + dy,
        xOffset: xOffset,
        baseXOffset: baseXOffset,
        phase: phase,
        type: type,
        ribbonGroupId: ribbonGroupId,
        age: age + 0.016, // ~60fps time step
      );

  Balloon withXOffset(double newX) => Balloon(
        id: id,
        isPopped: isPopped,
        y: y,
        xOffset: newX,
        baseXOffset: baseXOffset,
        phase: phase,
        type: type,
        ribbonGroupId: ribbonGroupId,
        age: age,
      );

  /// Micro speed variance
  double get riseSpeedMultiplier {
    final m = 1.0 + sin(phase) * 0.10;
    return m.clamp(0.92, 1.08);
  }

  /// 🎈 Arcade Balloon Motion Model
  ///
  /// vertical rise handled by engine
  /// + sine drift
  /// + buoyancy wobble
  /// + slight rotation illusion
  double driftedX({
    required double amplitude,
    required double frequency,
  }) {
    /// horizontal drift
    final drift = sin(phase + y * frequency) * amplitude;

    /// buoyancy wobble (time based)
    final wobble = sin(phase + age * 3.2) * amplitude * 0.35;

    /// subtle tilt illusion
    final tilt = sin(phase + age * 1.3) * amplitude * 0.15;

    return baseXOffset + drift + wobble + tilt;
  }

  /// Spawn helper
  static Balloon spawnAt(
    int index, {
    required int total,
    required int tier,
    required double viewportHeight,
    BalloonType type = BalloonType.standard,
  }) {
    final rand = Random(index * 997 + tier * 7919);

    final clusterSpread = 0.22;
    final baseX = (rand.nextDouble() * 2 - 1) * clusterSpread;

    final spacing = max(40.0, 70.0 - tier * 3.0);

    final startY = viewportHeight - (index * spacing);

    final phase = rand.nextDouble() * pi * 2;

    return Balloon(
      id: 'balloon_$index',
      y: startY,
      xOffset: baseX,
      baseXOffset: baseX,
      phase: phase,
      type: type,
      age: 0.0,
    );
  }
}
