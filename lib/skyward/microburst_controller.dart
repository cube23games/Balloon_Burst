import 'dart:math' as math;

/// A telegraphed, bounded horizontal sway for Skyward Journey wind levels.
///
/// The controller emits a warning before the gust and then a smooth
/// bell-shaped displacement. It never changes the underlying balloon spawn
/// position or vertical speed. No state is shared with Endless Arcade.
enum MicroburstPhase { calm, warning, gust }

class MicroburstController {
  static const double firstCalmSeconds = 4.0;
  static const double warningSeconds = 2.0;
  static const double gustSeconds = 3.0;
  static const double recoverySeconds = 7.0;

  /// Normalized offset: xOffset * (screenWidth / 2).
  /// 0.34 -> 68px on a 400px-wide phone at the gust midpoint.
  static const double maxSway = 0.34;
  static const double safeEdgeX = 0.88;

  MicroburstPhase _phase = MicroburstPhase.calm;
  double _remaining = firstCalmSeconds;
  int _direction = 1;
  int _gustCount = 0;

  MicroburstPhase get phase => _phase;
  double get secondsRemaining => _remaining;
  int get direction => _direction; // 1 = right, -1 = left
  int get gustCount => _gustCount;
  bool get warningSoon => _phase == MicroburstPhase.warning;
  bool get isGusting => _phase == MicroburstPhase.gust;

  double get normalizedSway {
    if (!isGusting) return 0.0;
    final progress =
        ((gustSeconds - _remaining) / gustSeconds).clamp(0.0, 1.0);
    return _direction * maxSway * math.sin(math.pi * progress);
  }

  /// Moves the controller forward using active gameplay seconds only.
  /// Returns true when the warning/gust/calm phase changes.
  bool update(double dt) {
    if (!dt.isFinite || dt <= 0) return false;
    _remaining -= dt;
    var changed = false;
    // Floating-point increments such as 3.9 + 0.1 can miss an exact
    // boundary by a fraction of a nanosecond. Treat that as elapsed.
    while (_remaining <= 1e-9) {
      final overflow = math.max(0.0, -_remaining);
      switch (_phase) {
        case MicroburstPhase.calm:
          _phase = MicroburstPhase.warning;
          _remaining = warningSeconds - overflow;
          break;
        case MicroburstPhase.warning:
          _phase = MicroburstPhase.gust;
          _remaining = gustSeconds - overflow;
          _gustCount++;
          break;
        case MicroburstPhase.gust:
          _phase = MicroburstPhase.calm;
          _remaining = recoverySeconds - overflow;
          _direction = -_direction;
          break;
      }
      changed = true;
    }
    return changed;
  }

  /// The wind cannot push a balloon farther toward an edge than its natural
  /// position if that natural position is already beyond the safe margin.
  /// This keeps outer balloons tappable and avoids snap-back when wind ends.
  double applySway(double naturalX) {
    if (!isGusting) return naturalX;
    final minX = math.min(-safeEdgeX, naturalX);
    final maxX = math.max(safeEdgeX, naturalX);
    return (naturalX + normalizedSway).clamp(minX, maxX).toDouble();
  }

  /// Shared horizontal wind offset for a linked group of balloons.
  ///
  /// Both balloons shift the same distance, preventing a gust from
  /// stretching their ribbon if one reaches the safe screen margin first.
  /// Each balloon keeps its independently calculated natural sway.
  /// The group's most restricted living member determines the cap.
  double boundedGroupSway(Iterable<double> naturalXs) {
    if (!isGusting) return 0.0;
    var shift = normalizedSway;
    var hasMember = false;
    for (final naturalX in naturalXs) {
      if (!naturalX.isFinite) return 0.0;
      hasMember = true;
      final minX = math.min(-safeEdgeX, naturalX);
      final maxX = math.max(safeEdgeX, naturalX);
      if (shift > 0) {
        shift = math.min(shift, math.max(0.0, maxX - naturalX));
      } else if (shift < 0) {
        shift = math.max(shift, math.min(0.0, minX - naturalX));
      }
    }
    return hasMember ? shift : 0.0;
  }

  void reset() {
    _phase = MicroburstPhase.calm;
    _remaining = firstCalmSeconds;
    _direction = 1;
    _gustCount = 0;
  }
}
