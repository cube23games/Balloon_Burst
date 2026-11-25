import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';

/// TJ-45B V2: tighter, more defined balloon aura. Internal QA ONLY.
///
/// The original Gaussian renderer and the V1 gradient remain unchanged.
/// The v2 experiment is not an approved production replacement.
class QaTightAuraGlow {
  static const bool enabled = kEnableQaAutoTap &&
      bool.fromEnvironment('TJ45B_GLOW_AURA_V2', defaultValue: false);

  static const String variant = 'tightAuraV2';
  static const int maxCachedShaders = 96;
  static final Map<(double, double, int, double), ui.Shader> _shaderCache = {};
  static int get cachedShaderCount => _shaderCache.length;

  /// The V2 halo extends less than the V1 2.2-sigma outer radius.
  static double outerRadius(double glowRadius, double sigma) =>
      glowRadius + 1.35 * sigma;

  /// A brighter near-edge aura and fast outer fade rather than broad fog.
  ///
  /// The body and highlights are painted after this effect, so their shape
  /// remains sharp and unaffected by the chosen gradient.
  static List<double> gradientStops(double glowRadius, double sigma) {
    final outer = outerRadius(glowRadius, sigma);
    return <double>[
      0.0,
      ((glowRadius - 0.55 * sigma) / outer).clamp(0.0, 1.0),
      ((glowRadius - 0.04 * sigma) / outer).clamp(0.0, 1.0),
      ((glowRadius + 0.44 * sigma) / outer).clamp(0.0, 1.0),
      1.0,
    ];
  }

  static void paint({
    required Canvas canvas,
    required Offset center,
    required double glowRadius,
    required double sigma,
    required Color color,
    required double opacity,
  }) {
    assert(enabled, 'Tight aura renderer may run only in explicit internal QA.');
    final key = (glowRadius, sigma, color.value, opacity);
    var shader = _shaderCache[key];
    if (shader == null) {
      final outer = outerRadius(glowRadius, sigma);
      shader = RadialGradient(
        colors: <Color>[
          color.withOpacity(opacity * 0.65),
          color.withOpacity(opacity * 0.97),
          color.withOpacity(opacity * 0.82),
          color.withOpacity(opacity * 0.20),
          color.withOpacity(0.0),
        ],
        stops: gradientStops(glowRadius, sigma),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: outer));
      if (_shaderCache.length >= maxCachedShaders) _shaderCache.clear();
      _shaderCache[key] = shader;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.drawCircle(
      Offset.zero,
      outerRadius(glowRadius, sigma),
      Paint()..shader = shader,
    );
    canvas.restore();
  }
}
