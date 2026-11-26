import 'package:balloon_burst/game/qa_gradient_balloon_glow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Default and public builds retain the original glow', () {
    expect(QaGradientBalloonGlow.enabled, false);
    expect(QaGradientBalloonGlow.variant, 'originalBlur');
    expect(QaGradientBalloonGlow.maxCachedShaders, 96);
  });
  test('Experimental gradient stops stay ordered for all streak tiers', () {
    for (final radius in <double>[23.5, 27, 29.5, 33]) {
      for (final sigma in <double>[10.5, 15, 20]) {
        final stops = QaGradientBalloonGlow.gradientStops(radius, sigma);
        expect(stops.length, 5);
        expect(stops.first, 0);
        expect(stops.last, 1);
        for (var i = 0; i < stops.length; i++) {
          expect(stops[i], inInclusiveRange(0, 1));
          if (i > 0) expect(stops[i], greaterThanOrEqualTo(stops[i - 1]));
        }
      }
    }
  });
}
