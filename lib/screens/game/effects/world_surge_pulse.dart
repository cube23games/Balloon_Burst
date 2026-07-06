import 'dart:math';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:balloon_burst/audio/audio_player.dart';

/// World Surge Pulse v1.3
/// - Fires shortly before world transition
/// - Fake-out flash: current → next → current
/// - Vertical micro-shake
/// - Lightning strike (visual-only, transition-only)
/// - Haptics: toggle-ready, default ON
class WorldSurgePulse {
  final AnimationController _pulseCtrl;
  final AnimationController _shakeCtrl;
  final AnimationController _lightningCtrl;

  int _lastSurgeWorld = 0;
  bool _invertColors = false;

  // Lightning state
  int _lightningSeed = 1;

  // Haptics (toggle-ready)
  bool _hapticsEnabled = true;

  static const double pulseMaxOpacity = 0.34;
  static const double shakeAmpPx = 11.0;

  WorldSurgePulse({
    required TickerProvider vsync,
    bool hapticsEnabled = true,
  })  : _pulseCtrl = AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 220),
        ),
        _shakeCtrl = AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 160),
        ),
        _lightningCtrl = AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 520),
        ) {
    _hapticsEnabled = hapticsEnabled;

    // ✅ Listener added ONCE (fixes stacking)
    _pulseCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _invertColors = false;
      }
    });

    // Keep lightning controller clean between triggers.
    // Important: leaving it at 1.0 can leave a faint afterimage in later worlds.
    _lightningCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _lightningCtrl.reset();
      }
    });
  }

  void dispose() {
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _lightningCtrl.dispose();
  }

  /// 🔑 Toggle-ready haptics (UI can call this later)
  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
  }

  bool get hapticsEnabled => _hapticsEnabled;

  /// 🔑 Reset surge state for a brand-new run (Retry)
  void reset() {
    _lastSurgeWorld = 0;
    _invertColors = false;
    _lightningSeed = 1;

    _pulseCtrl.reset();
    _shakeCtrl.reset();
    _lightningCtrl.reset();
  }

  void maybeTrigger({
    required int totalPops,
    required int currentWorld,
    required int world2Pops,
    required int world3Pops,
    required int world4Pops,
  }) {
    // Only fire once per world per run
    if (_lastSurgeWorld == currentWorld) return;

    final int? triggerAt = switch (currentWorld) {
      1 => world2Pops - 3,
      2 => world3Pops - 4,
      3 => world4Pops - 5,
      _ => null,
    };

    if (triggerAt != null && totalPops == triggerAt) {
      _lastSurgeWorld = currentWorld;

      AudioPlayerService.playSurge(); // 🔊 anticipation cue

      // Haptic bump (toggle-ready, default ON)
      if (_hapticsEnabled) {
        // Medium impact is a nice "thunder rumble" without being too aggressive.
        HapticFeedback.mediumImpact();
      }

      // Color fake-out pulse
      _invertColors = true;
      _pulseCtrl
        ..reset()
        ..forward();

      // Micro shake
      _shakeCtrl
        ..reset()
        ..forward();

      // Lightning (visual-only, transition-only)
      _lightningSeed = DateTime.now().microsecondsSinceEpoch;
      _lightningCtrl
        ..reset()
        ..forward();
    }
  }

  // --- Pulse ---
  bool get showNextWorldColor => _invertColors;

  bool get isPulseActive => _pulseCtrl.isAnimating || _pulseCtrl.value > 0.0;

  double get pulseOpacity {
    final t = _pulseCtrl.value.clamp(0.0, 1.0);
    final eased = 1.0 - t;
    return pulseMaxOpacity * eased * eased;
  }

  // --- Shake ---
  double get shakeYOffset {
    final t = _shakeCtrl.value.clamp(0.0, 1.0);
    return sin(pi * t) * shakeAmpPx;
  }

  // --- Lightning ---
  bool get isLightningActive =>
      _lightningCtrl.isAnimating || _lightningCtrl.value > 0.0;

  double get lightningT => _lightningCtrl.value.clamp(0.0, 1.0);

  int get lightningSeed => _lightningSeed;

  /// Darken before strike (psych bump). Peaks early, fades quickly.
  double get lightningDarkenOpacity {
    final t = lightningT;
    final peak = (1.0 - (t / 0.35)).clamp(0.0, 1.0);
    return 0.40 * peak * peak;
  }

  /// Flash bloom during strike (no strobe). Short and controlled.
  double get lightningFlashOpacity {
    final t = lightningT;
    // Bell curve around ~0.35
    final x = (t - 0.35) / 0.18;
    final bell = exp(-x * x);
    return (0.34 * bell).clamp(0.0, 0.34);
  }

  /// Lightning shake amplifier (adds to existing surge shake, very slight)
  double get lightningShakeAmp {
    final t = lightningT;
    final x = (t - 0.35) / 0.22;
    final bell = exp(-x * x);
    return 4.5 * bell; // px
  }

  // Single listenable for AnimatedBuilder
  Listenable get listenable => Listenable.merge([
        _pulseCtrl,
        _shakeCtrl,
        _lightningCtrl,
      ]);
}
