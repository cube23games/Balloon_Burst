import 'dart:math';

import 'package:flutter/material.dart';
import 'package:balloon_burst/game/game_state.dart';
import 'package:balloon_burst/gameplay/balloon.dart';
import 'package:balloon_burst/game/balloon_type.dart';

class BalloonPainter extends CustomPainter {
  final List<Balloon> balloons;
  final GameState gameState;
  final int currentWorld;
  final int streak;

  BalloonPainter(
    this.balloons,
    this.gameState,
    this.currentWorld, {
    required this.streak,
  });

  static const double baseBalloonRadius = 17.5;

  @override
  void paint(Canvas canvas, Size size) {
    final dangerHeight = 40.0;
    final dangerRect = Rect.fromLTWH(
      0,
      size.height - dangerHeight,
      size.width,
      dangerHeight,
    );

    final dangerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Color.fromARGB(20, 255, 0, 0),
        ],
      ).createShader(dangerRect);

    canvas.drawRect(dangerRect, dangerPaint);

    if (gameState.framesSinceStart < 90) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Tap to Burst',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final offset = Offset(
        (size.width - textPainter.width) / 2,
        size.height * 0.25,
      );

      textPainter.paint(canvas, offset);
    }

    final centerX = size.width / 2;

    // Render linked ribbons behind the balloons themselves. The same
    // xOffset/y coordinates are used for paint and hit-testing.
    _paintRibbonLinks(canvas, size);

    for (final balloon in balloons) {
      if (balloon.isPopped) continue;

      final cfg = balloonTypeConfig[balloon.type]!;
      final seed = balloon.id.hashCode;
      final styleVariant = seed.abs() % 4;
      final paletteIndex = (seed.abs() ~/ 7) % _paletteForWorld(currentWorld).length;

      final sizeVariance = 0.85 + ((seed % 20).abs() / 100);
      final shadeVariance = 0.92 + ((seed % 10).abs() / 100);

      final radius =
          (baseBalloonRadius * cfg.visualScale * sizeVariance).roundToDouble();

      final x = centerX + (balloon.xOffset * size.width * 0.5);
      final y = balloon.y;
      final center = Offset(x, y);

      if (balloon.type == BalloonType.lead) {
        _paintLeadBalloon(canvas, center, radius);
        continue;
      }
      if (balloon.type == BalloonType.ribbon) {
        _paintRibbonBalloon(canvas, center, radius);
        continue;
      }

      _paintStreakGlow(canvas, center, radius);

      final paletteColor = _paletteForWorld(currentWorld)[paletteIndex];
      final baseColor = Color.lerp(
        paletteColor,
        Colors.white,
        (shadeVariance - 0.92) * 0.03,
      )!;

      final bodyPaint = Paint()
        ..color = baseColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.medium;

      canvas.drawCircle(center, radius, bodyPaint);

      final bodyShadowPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.4, 0.4),
          radius: 1.0,
          colors: [
            Colors.black.withOpacity(0.18),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: radius),
        );

      canvas.drawCircle(center, radius, bodyShadowPaint);

      switch (styleVariant) {
        case 0:
          _paintClassicHighlights(canvas, x, y, radius);
          break;
        case 1:
          _paintGlossyHighlights(canvas, x, y, radius);
          _paintSpecDot(canvas, x, y, radius);
          break;
        case 2:
          _paintArcadeRim(canvas, center, radius);
          _paintSideSheen(canvas, x, y, radius);
          _paintClassicHighlights(canvas, x, y, radius);
          break;
        case 3:
          _paintCarnivalStripe(canvas, center, radius);
          _paintCarnivalDoubleHighlight(canvas, x, y, radius);
          _paintBottomSheen(canvas, center, radius);
          break;
      }

      _paintKnot(canvas, x, y, radius, styleVariant);
      _paintString(canvas, balloon, x, y, radius, seed, styleVariant);
    }
  }

  /// High-contrast metallic target, not dependent on sound or color alone.
  /// Red downward arrow and Pb marking identify this descending lead balloon.
  void _paintRibbonLinks(Canvas canvas, Size size) {
    final firstByGroup = <String, Balloon>{};
    const ribbonRadius = baseBalloonRadius * 1.10;

    // The ends attach near the inner LOWER shoulders rather than between
    // balloon centers. A sagging fabric strip (not a straight line) makes
    // the link look loose as each balloon sways independently.
    for (final balloon in balloons) {
      if (balloon.isPopped || balloon.type != BalloonType.ribbon) continue;
      final group = balloon.ribbonGroupId;
      if (group == null) continue;
      final first = firstByGroup[group];
      if (first == null) {
        firstByGroup[group] = balloon;
        continue;
      }
      final left = first.xOffset < balloon.xOffset ? first : balloon;
      final right = identical(left, first) ? balloon : first;
      final centerLeft = Offset(
        size.width * (0.5 + left.xOffset * 0.5),
        left.y,
      );
      final centerRight = Offset(
        size.width * (0.5 + right.xOffset * 0.5),
        right.y,
      );
      final a = centerLeft + const Offset(ribbonRadius * 0.58, ribbonRadius * 0.55);
      final b = centerRight + const Offset(-ribbonRadius * 0.58, ribbonRadius * 0.55);
      final span = b.dx - a.dx;
      if (span <= 0) continue;

      final flutter = sin(left.age * 1.9 + left.phase) * 4.0;
      final sag = (14.0 + span * 0.28).clamp(16.0, 34.0) + flutter;
      final midX = (a.dx + b.dx) * 0.5 +
          sin(left.age * 1.3 + right.phase) * 3.0;
      final midY = max(a.dy, b.dy) + sag;

      final centerLine = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(midX, midY, b.dx, b.dy);

      // Soft shadow beneath a thin, curved strip; no heavy blur or
      // per-frame object allocation outside the existing CustomPainter.
      canvas.drawPath(
        centerLine,
        Paint()
          ..color = const Color(0x6656D4E9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9.0
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );

      // A closed, tapering silk band with a highlight. It flexes with the
      // positions of both balloons and an independent cloth flutter.
      final fabric = Path()
        ..moveTo(a.dx, a.dy - 3.2)
        ..quadraticBezierTo(midX - 2.5, midY - 4.2, b.dx, b.dy - 2.2)
        ..lineTo(b.dx, b.dy + 2.2)
        ..quadraticBezierTo(midX + 2.5, midY + 3.8, a.dx, a.dy + 3.2)
        ..close();
      canvas.drawPath(
        fabric,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFFFF7BF),
              Color(0xFFFFC955),
              Color(0xFFE59B35),
            ],
          ).createShader(fabric.getBounds())
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        centerLine,
        Paint()
          ..color = const Color(0x99FFF4C2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
    }
  }

  void _paintRibbonBalloon(Canvas canvas, Offset center, double radius) {
    // A slightly tapered balloon silhouette + knot, not a circular disc.
    // Keep roughly the original visual/hit radius to preserve tap fairness.
    final x = center.dx;
    final y = center.dy;
    final body = Path()
      ..moveTo(x, y - radius * 1.04)
      ..cubicTo(
        x + radius * 0.96, y - radius * 1.13,
        x + radius * 1.11, y - radius * 0.15,
        x + radius * 0.78, y + radius * 0.56,
      )
      ..quadraticBezierTo(
        x + radius * 0.42, y + radius * 1.01,
        x, y + radius * 1.04,
      )
      ..quadraticBezierTo(
        x - radius * 0.42, y + radius * 1.01,
        x - radius * 0.78, y + radius * 0.56,
      )
      ..cubicTo(
        x - radius * 1.11, y - radius * 0.15,
        x - radius * 0.96, y - radius * 1.13,
        x, y - radius * 1.04,
      )
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.38, -0.38),
          radius: 1.15,
          colors: <Color>[
            Color(0xFFAEFFFF),
            Color(0xFF1CCAD8),
            Color(0xFF066198),
          ],
        ).createShader(body.getBounds())
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFFFFE79A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..isAntiAlias = true,
    );

    // Fabric marker remains visible even when a normal balloon overlaps.
    final stripe = Path()
      ..moveTo(x - radius * 0.47, y - radius * 0.71)
      ..quadraticBezierTo(
        x + radius * 0.03,
        y,
        x + radius * 0.43,
        y + radius * 0.70,
      );
    canvas.drawPath(
      stripe,
      Paint()
        ..color = const Color(0xFFFFF0AD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.7
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      Offset(x - radius * 0.36, y - radius * 0.38),
      radius * 0.16,
      Paint()..color = Colors.white.withOpacity(0.82),
    );

    final knot = Path()
      ..moveTo(x - radius * 0.16, y + radius * 0.99)
      ..lineTo(x + radius * 0.16, y + radius * 0.99)
      ..lineTo(x, y + radius * 1.24)
      ..close();
    canvas.drawPath(knot, Paint()..color = const Color(0xFFFFD778));
    final string = Path()
      ..moveTo(x, y + radius * 1.23)
      ..quadraticBezierTo(
        x + radius * 0.22, y + radius * 1.59,
        x - radius * 0.04, y + radius * 1.88,
      );
    canvas.drawPath(
      string,
      Paint()
        ..color = const Color(0xAAE9F3FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true,
    );
  }

  void _paintLeadBalloon(Canvas canvas, Offset center, double radius) {
    final outline = Paint()
      ..color = const Color(0xFFFFCA55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..isAntiAlias = true;

    final body = Paint()
      ..isAntiAlias = true
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.55),
        radius: 1.1,
        colors: [
          Color(0xFFCCD6DF),
          Color(0xFF8798A9),
          Color(0xFF324152),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, body);
    canvas.drawCircle(center, radius + 2, outline);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.7),
      -0.2,
      1.7,
      false,
      Paint()
        ..color = const Color(0x66384858)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final arrow = Path()
      ..moveTo(center.dx - radius * 0.22, center.dy + radius * 0.20)
      ..lineTo(center.dx + radius * 0.22, center.dy + radius * 0.20)
      ..lineTo(center.dx, center.dy + radius * 0.58)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFFFF4757));

    final label = TextPainter(
      text: const TextSpan(
        text: 'Pb',
        style: TextStyle(
          color: Color(0xFF152435),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(center.dx - label.width / 2, center.dy - radius * 0.56),
    );

    // Downward streaks signal unusual movement from a distance.
    final streak = Paint()
      ..color = const Color(0x99FFCA55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - radius * 0.4, center.dy - radius * 1.8),
      Offset(center.dx - radius * 0.4, center.dy - radius * 1.15),
      streak,
    );
    canvas.drawLine(
      Offset(center.dx + radius * 0.35, center.dy - radius * 1.55),
      Offset(center.dx + radius * 0.35, center.dy - radius * 1.1),
      streak,
    );
  }

  void _paintStreakGlow(Canvas canvas, Offset center, double radius) {
    if (streak < 10) return;

    final glowOpacity = streak >= 30
        ? 0.44
        : streak >= 20
            ? 0.32
            : 0.20;

    final glowBlur = streak >= 30
        ? 20.0
        : streak >= 20
            ? 15.0
            : 10.5;

    final glowRadius = streak >= 30
        ? radius + 11
        : streak >= 20
            ? radius + 8.5
            : radius + 6.5;

    final glowColor = streak >= 30
        ? (currentWorld == 1
            ? const Color(0xFFFFD54F)
            : const Color(0xFF00E5FF))
        : streak >= 20
            ? const Color(0xFFFFC107)
            : const Color(0xFFFFF59D);

    final glowPaint = Paint()
      ..color = glowColor.withOpacity(glowOpacity)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur);

    canvas.drawCircle(center, glowRadius, glowPaint);
  }

  void _paintClassicHighlights(
    Canvas canvas,
    double x,
    double y,
    double radius,
  ) {
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.36)
      ..isAntiAlias = true;

    canvas.drawCircle(
      Offset(
        (x - radius * 0.34).roundToDouble(),
        (y - radius * 0.34).roundToDouble(),
      ),
      radius * 0.24,
      highlightPaint,
    );
  }

  void _paintGlossyHighlights(
    Canvas canvas,
    double x,
    double y,
    double radius,
  ) {
    final mainHighlight = Paint()
      ..color = Colors.white.withOpacity(0.48)
      ..isAntiAlias = true;

    final elongatedHighlight = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..isAntiAlias = true;

    canvas.drawCircle(
      Offset(
        (x - radius * 0.32).roundToDouble(),
        (y - radius * 0.38).roundToDouble(),
      ),
      radius * 0.30,
      mainHighlight,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          (x - radius * 0.05).roundToDouble(),
          (y - radius * 0.48).roundToDouble(),
        ),
        width: radius * 0.26,
        height: radius * 0.12,
      ),
      elongatedHighlight,
    );
  }

  void _paintSpecDot(Canvas canvas, double x, double y, double radius) {
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.32)
      ..isAntiAlias = true;

    canvas.drawCircle(
      Offset(
        (x + radius * 0.10).roundToDouble(),
        (y - radius * 0.52).roundToDouble(),
      ),
      radius * 0.07,
      dotPaint,
    );
  }

  void _paintArcadeRim(Canvas canvas, Offset center, double radius) {
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withOpacity(0.22)
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius - 1.0, rimPaint);
  }

  void _paintSideSheen(Canvas canvas, double x, double y, double radius) {
    final sheenPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..isAntiAlias = true;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          (x + radius * 0.22).roundToDouble(),
          y.roundToDouble(),
        ),
        width: radius * 0.18,
        height: radius * 0.62,
      ),
      sheenPaint,
    );
  }

  void _paintCarnivalDoubleHighlight(
    Canvas canvas,
    double x,
    double y,
    double radius,
  ) {
    final strongHighlight = Paint()
      ..color = Colors.white.withOpacity(0.36)
      ..isAntiAlias = true;

    final softHighlight = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..isAntiAlias = true;

    canvas.drawCircle(
      Offset(
        (x - radius * 0.32).roundToDouble(),
        (y - radius * 0.34).roundToDouble(),
      ),
      radius * 0.22,
      strongHighlight,
    );

    canvas.drawCircle(
      Offset(
        (x + radius * 0.08).roundToDouble(),
        (y - radius * 0.16).roundToDouble(),
      ),
      radius * 0.11,
      softHighlight,
    );
  }

  void _paintCarnivalStripe(Canvas canvas, Offset center, double radius) {
    final stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..isAntiAlias = true;

    final stripeRect = Rect.fromCenter(
      center: center,
      width: radius * 0.34,
      height: radius * 1.65,
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawRect(stripeRect, stripePaint);
    canvas.restore();
  }

  void _paintBottomSheen(Canvas canvas, Offset center, double radius) {
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.14),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, sheenPaint);
  }

  void _paintKnot(
    Canvas canvas,
    double x,
    double y,
    double radius,
    int styleVariant,
  ) {
    final knotPaint = Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..isAntiAlias = true;

    final knotWidth = styleVariant == 3 ? 6.0 : 5.0;
    final knotHeight = styleVariant == 3 ? 4.0 : 3.0;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + radius + 1.5),
        width: knotWidth,
        height: knotHeight,
      ),
      knotPaint,
    );
  }

  void _paintString(
    Canvas canvas,
    Balloon balloon,
    double x,
    double y,
    double radius,
    int seed,
    int styleVariant,
  ) {
    if (seed % 3 != 0) return;

    final stringPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..strokeWidth = styleVariant == 2 ? 1.35 : 1.2
      ..isAntiAlias = true;

    final stringLength =
        18.0 + ((seed % 4).abs() * 1.8) + (styleVariant == 3 ? 2.0 : 0.0);

    final swayX =
        sin(balloon.phase + balloon.age * 1.10) * (styleVariant == 2 ? 4.8 : 4.0);
    final swayY = sin(balloon.phase + balloon.age * 0.62) * 1.2;

    canvas.drawLine(
      Offset(x, y + radius + 1.5),
      Offset(x + swayX, y + radius + stringLength + swayY),
      stringPaint,
    );
  }

  List<Color> _paletteForWorld(int world) {
    switch (world) {
      case 2:
        return const [
          Color(0xFF1E90FF), // blue
          Color(0xFFFF2D55), // bright pink
          Color(0xFFFFC400), // yellow
          Color(0xFF00C853), // green
          Color(0xFF7C4DFF), // purple
          Color(0xFFFF6D00), // orange
          Color(0xFF00B8D4), // teal
        ];
      case 3:
        return const [
          Color(0xFFB026FF), // electric violet
          Color(0xFFFF2E88), // hot pink
          Color(0xFFFFD600), // neon yellow
          Color(0xFF00E676), // neon green
          Color(0xFF00B0FF), // cyan-blue
          Color(0xFFFF6E40), // orange coral
          Color(0xFFE040FB), // magenta
        ];
      case 4:
        return const [
          Color(0xFF64B5F6), // icy blue
          Color(0xFFFFC400), // gold
          Color(0xFFFF5252), // coral red
          Color(0xFF18FFFF), // electric cyan
          Color(0xFFEA80FC), // orchid
          Color(0xFF69F0AE), // mint
        ];
      default:
        return const [
          Color(0xFFFF2A2A), // true red
          Color(0xFFFF7A00), // orange
          Color(0xFFFFE000), // yellow
          Color(0xFF00C853), // green
          Color(0xFF2979FF), // blue
          Color(0xFFFF2E88), // carnival pink
        ];
    }
  }

  @override
  bool shouldRepaint(covariant BalloonPainter oldDelegate) => true;
}
