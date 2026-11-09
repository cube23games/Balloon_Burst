import 'package:balloon_burst/game/balloon_type.dart';
import 'package:balloon_burst/gameplay/balloon.dart';

/// Skyward-exclusive ribbon pairs. One successful tap on either linked
/// balloon pops its living partner, but still counts as exactly one tap.
/// Endless Arcade never instantiates or ticks this controller.
class RibbonChainController {
  static const double firstDelaySeconds = 4.0;
  static const double repeatDelaySeconds = 5.5;
  static const double entryPaddingY = 60.0;

  double _remaining = firstDelaySeconds;
  int _sequence = 0;
  final Set<String> _escapedGroups = <String>{};

  double get secondsUntilNext => _remaining;
  int get spawnedGroups => _sequence;

  /// Do not spawn another pair while a previous linked member is alive.
  /// The timer only advances during active Skyward gameplay.
  bool update({required double dt, required bool hasActiveRibbon}) {
    if (hasActiveRibbon || !dt.isFinite || dt <= 0) return false;
    _remaining -= dt;
    if (_remaining > 1e-9) return false;
    _remaining = repeatDelaySeconds;
    return true;
  }

  List<Balloon> createPair({required double viewportHeight}) {
    if (!viewportHeight.isFinite || viewportHeight <= 0) {
      throw ArgumentError.value(viewportHeight, 'viewportHeight');
    }
    // Each pair enters as a readable, horizontally connected duo.
    // Both members share phase and y so their sway stays in sync.
    const centers = <double>[-0.24, 0.22, 0.0, -0.10, 0.14];
    const spacing = 0.17; // normalized half-width of the connector
    final groupIndex = _sequence++;
    final center = centers[groupIndex % centers.length];
    final groupId = 'skyward_ribbon_$groupIndex';
    final phase = (groupIndex % 7) * 0.72;
    final y = viewportHeight + entryPaddingY;
    return List<Balloon>.generate(2, (slot) {
      final x = center + (slot == 0 ? -spacing : spacing);
      return Balloon(
        id: '${groupId}_$slot',
        y: y,
        xOffset: x,
        baseXOffset: x,
        phase: phase,
        type: BalloonType.ribbon,
        ribbonGroupId: groupId,
      );
    }, growable: false);
  }

  /// Called AFTER the normal hit handler marked the directly tapped balloon
  /// as popped. Returns only OTHER living members in the identical group.
  /// No proximity-based or transitive unlinked pops are allowed.
  static List<Balloon> linkedPeers({
    required Balloon tapped,
    required Iterable<Balloon> balloons,
  }) {
    final groupId = tapped.ribbonGroupId;
    if (tapped.type != BalloonType.ribbon ||
        groupId == null ||
        groupId.isEmpty) {
      return const <Balloon>[];
    }
    return balloons
        .where((balloon) =>
            !balloon.isPopped &&
            balloon.id != tapped.id &&
            balloon.type == BalloonType.ribbon &&
            balloon.ribbonGroupId == groupId)
        .toList(growable: false);
  }

  /// A linked pair reaching the exit is one missed opportunity, not two
  /// simultaneous escape penalties. Retain group IDs for the whole attempt
  /// in case partners cross the exit on adjacent frames.
  bool shouldCountEscape(Balloon balloon) {
    if (balloon.type != BalloonType.ribbon || balloon.ribbonGroupId == null) {
      return true;
    }
    return _escapedGroups.add(balloon.ribbonGroupId!);
  }

  void reset() {
    _remaining = firstDelaySeconds;
    _sequence = 0;
    _escapedGroups.clear();
  }
}
