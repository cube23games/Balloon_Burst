import 'package:balloon_burst/game/game_state.dart' show GameState;
import 'package:balloon_burst/debug/debug_log.dart' show DebugEventType;
import 'package:balloon_burst/gameplay/balloon.dart';

import 'package:balloon_burst/engine/momentum/momentum_controller.dart';
import 'package:balloon_burst/engine/tier/tier_controller.dart';
import 'package:balloon_burst/engine/speed/speed_curve.dart';

/// ===============================================================
/// GameController (BalloonBurst)
/// ===============================================================
///
/// RESPONSIBILITY (Post-Engine Integration):
/// - Updates gameplay-related controllers (momentum/tier/speed)
/// - Tracks lightweight telemetry counters (misses/escapes/perfects)
/// - Logs gameplay signals
///
/// NON-RESPONSIBILITY:
/// - Run lifecycle authority (start/end) is owned by TJ Engine
/// - Fail conditions (miss limit, escape limit) are owned by TJ Engine
/// ===============================================================
class GameController {
  static const bool _verboseTapLogging = false;

  final MomentumController momentum;
  final TierController tier;
  final SpeedCurve speed;
  final GameState gameState;

  // Telemetry-only counters
  int _escapeCount = 0;
  int _missCount = 0;
  int _perfectHits = 0;
  int _perfectChain = 0;
  bool _lastTapPerfect = false;  

  int _timingChain = 0;
  bool _timingLockActive = false;

  DateTime? lastTapTime;
  DateTime? _lastSuccessfulTapTime;

  GameController({
    required this.momentum,
    required this.tier,
    required this.speed,
    required this.gameState,
  });

  /// Read-only telemetry
  int get escapeCount => _escapeCount;
  int get missCount => _missCount;
  int get perfectHits => _perfectHits;
  int get perfectChain => _perfectChain;
  bool get lastTapPerfect => _lastTapPerfect;

  int get timingChain => _timingChain;
  bool get timingLockActive => _timingLockActive;

  double get accuracy01 => momentum.accuracy01;

  void update(List<Balloon> balloons, double dt) {
    momentum.update(dt);
    tier.update(dt);
    gameState.framesSinceStart++;
  }

  void registerEscapes(int count) {
    _escapeCount += count;

    gameState.log(
      'WORLD: ESCAPE +$count total=$_escapeCount',
      type: DebugEventType.miss,
    );
  }

  void registerTap({required bool hit, bool perfect = false}) {
    final now = DateTime.now();
    lastTapTime = now;
    _lastTapPerfect = hit && perfect;

    momentum.registerTap(hit: hit);

    if (hit) {
      if (_lastSuccessfulTapTime != null) {
        final gapMs = now.difference(_lastSuccessfulTapTime!).inMilliseconds;
        final inRhythmWindow = gapMs >= 115 && gapMs <= 255;

        if (inRhythmWindow) {
          _timingChain++;
        } else {
          _timingChain = 1;
        }
      } else {
        _timingChain = 1;
      }

      _lastSuccessfulTapTime = now;
      final timingWasActive = _timingLockActive;
      _timingLockActive = _timingChain >= 3;

      if (_timingLockActive && !timingWasActive) {
        gameState.log(
          'TIMING LOCK x$_timingChain',
          type: DebugEventType.system,
        );
      }

      if (perfect) {
        _perfectHits++;
        _perfectChain++;

        if (_verboseTapLogging) {
          gameState.log(
            'PERFECT TAP total=$_perfectHits chain=$_perfectChain',
            type: DebugEventType.system,
          );
        }

        if (_perfectChain == 3 ||
            _perfectChain == 5 ||
            _perfectChain == 10 ||
            _perfectChain == 20) {
          gameState.log(
            'PERFECT CHAIN x$_perfectChain',
            type: DebugEventType.system,
          );
        }
      } else {
        _perfectChain = 0;
      }
    } else {
      _perfectChain = 0;
      _timingChain = 0;
      _timingLockActive = false;
      _lastSuccessfulTapTime = null;
      _missCount++;

      gameState.log(
        'MISS: count=$_missCount',
        type: DebugEventType.miss,
      );
    }
  }

  void clearDangerTelemetryForRevive() {
    _escapeCount = 0;
    _missCount = 0;
    _perfectChain = 0;
    _lastTapPerfect = false;

    _timingChain = 0;
    _timingLockActive = false;
    _lastSuccessfulTapTime = null;

    gameState.log(
      'SYSTEM: revive cleared local danger telemetry',
      type: DebugEventType.system,
    );
  }

  void reset() {
    _escapeCount = 0;
    _missCount = 0;
    _perfectHits = 0;
    _perfectChain = 0;
    _lastTapPerfect = false;

    _timingChain = 0;
    _timingLockActive = false;
    _lastSuccessfulTapTime = null;

    momentum.reset();
    tier.reset();

    gameState.log(
      'SYSTEM: controller reset (telemetry + controllers)',
      type: DebugEventType.system,
    );
  }
}
