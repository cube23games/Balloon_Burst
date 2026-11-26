import 'package:balloon_burst/game/qa_tight_aura_glow.dart';
import 'package:balloon_burst/game/qa_gradient_balloon_glow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 is disabled by default, leaving original V1 and public unaffected', () {
    expect(QaTightAuraGlow.enabled, isFalse);
    expect(QaGradientBalloonGlow.enabled, isFalse);
    expect(QaGradientBalloonGlow.variant, 'originalBlur');
    expect(QaTightAuraGlow.variant, 'tightAuraV2');
    expect(QaTightAuraGlow.maxCachedShaders, 96);
  });

  test('V2 halo is narrower than V1 at every streak glow tier', () {
    for (final radius in <double>[16, 18, 22, 28, 34, 42]) {
      for (final sigma in <double>[10.5, 15, 20]) {
        expect(
          QaTightAuraGlow.outerRadius(radius, sigma),
          lessThan(radius + 2.2 * sigma),
        );
        expect(
          QaTightAuraGlow.outerRadius(radius, sigma),
          greaterThan(radius),
        );
      }
    }
  });

  test('V2 stops stay ordered for supported radii/blur tiers', () {
    for (final radius in <double>[16, 18, 22, 28, 34, 42]) {
      for (final sigma in <double>[10.5, 15, 20]) {
        final stops = QaTightAuraGlow.gradientStops(radius, sigma);
        expect(stops, hasLength(5));
        expect(stops.first, 0.0);
        expect(stops.last, 1.0);
        for (var i = 1; i < stops.length; i++) {
          expect(stops[i], inInclusiveRange(0, 1));
          expect(stops[i], greaterThan(stops[i - 1]));
        }
      }
    }
  });
}
