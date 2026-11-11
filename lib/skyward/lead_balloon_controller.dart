import 'package:balloon_burst/game/balloon_type.dart';
import 'package:balloon_burst/gameplay/balloon.dart';

/// Isolated descending-lead schedule for Skyward Journey, introduced in
/// World 1 Level 3. Never called by Endless Arcade's normal spawner.
class LeadBalloonController {
  static const double firstDelaySeconds = 3.0;
  static const double repeatDelaySeconds = 6.5;
  static const double warningWindowSeconds = 1.5;
  static const double descentPixelsPerSecond = 105.0;
  static const double spawnY = -50.0;

  double _remaining = firstDelaySeconds;
  int _sequence = 0;

  double get secondsUntilNext => _remaining;
  bool get warningSoon =>
      _remaining > 0 && _remaining <= warningWindowSeconds;

  int get spawnedCount => _sequence;

  /// Called only while the Skyward level is playing and viewport is valid.
  /// At most one unpopped lead balloon may occupy the screen.
  bool update({required double dt, required bool hasActiveLead}) {
    if (hasActiveLead) return false;
    if (dt <= 0) return false;
    _remaining -= dt;
    if (_remaining > 0) return false;
    _remaining = repeatDelaySeconds;
    return true;
  }

  Balloon createLead() {
    const offsets = <double>[-0.60, 0.58, 0.0, -0.28, 0.34];
    final index = _sequence++;
    final x = offsets[index % offsets.length];
    return Balloon(
      id: 'skyward_lead_$index',
      y: spawnY,
      xOffset: x,
      baseXOffset: x,
      phase: (index % 7) * 0.9,
      type: BalloonType.lead,
    );
  }

  static bool isBeyondExit({
    required Balloon balloon,
    required double viewportHeight,
    required double margin,
  }) {
    return balloon.type == BalloonType.lead
        ? balloon.y > viewportHeight + margin
        : balloon.y < -margin;
  }

  void reset() {
    _remaining = firstDelaySeconds;
    _sequence = 0;
  }
}
