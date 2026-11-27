import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';

/// QA-only alternative; public/default remains the original Gaussian halo.
class QaGradientBalloonGlow {
  static const bool enabled = kEnableQaAutoTap &&
      bool.fromEnvironment('TJ45B_GLOW_GRADIENT', defaultValue: false);
  static const String variant = enabled ? 'gradientExperiment' : 'originalBlur';
  static const int maxCachedShaders = 96;
  static final Map<(double, double, int, double), ui.Shader> _shaderCache = {};
  static int get cachedShaderCount => _shaderCache.length;

  /// Five-stop approximation; NOT an exact Gaussian or approved visual match.
  static List<double> gradientStops(double glowRadius, double sigma) {
    final outer = glowRadius + 2.2 * sigma;
    return <double>[
      0,
      ((glowRadius - sigma * 0.35) / outer).clamp(0.0, 1.0),
      (glowRadius / outer).clamp(0.0, 1.0),
      ((glowRadius + sigma * 0.75) / outer).clamp(0.0, 1.0),
      1,
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
    assert(enabled, 'The alternate renderer must only run in QA.');
    final key = (glowRadius, sigma, color.value, opacity);
    var shader = _shaderCache[key];
    if (shader == null) {
      final outer = glowRadius + 2.2 * sigma;
      shader = RadialGradient(
        colors: <Color>[
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.96),
          color.withOpacity(opacity * 0.68),
          color.withOpacity(opacity * 0.23),
          color.withOpacity(0.0),
        ],
        stops: gradientStops(glowRadius, sigma),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: outer));
      if (_shaderCache.length >= maxCachedShaders) _shaderCache.clear();
      _shaderCache[key] = shader;
    }
    final outer = glowRadius + 2.2 * sigma;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.drawCircle(Offset.zero, outer, Paint()..shader = shader);
    canvas.restore();
  }
}
