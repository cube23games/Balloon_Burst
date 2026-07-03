import 'dart:math';
import 'package:flutter/material.dart';

import 'package:balloon_burst/game/game_state.dart';
import 'package:balloon_burst/game/balloon_painter.dart';
import 'package:balloon_burst/gameplay/balloon.dart';
import 'package:balloon_burst/screens/game/effects/miss_popup.dart';
import 'package:balloon_burst/screens/game/effects/pop_particle.dart';
import 'package:balloon_burst/screens/game/effects/pop_shockwave.dart';
import 'package:balloon_burst/tj_engine/juice/models/score_burst.dart';

import '../effects/world_surge_pulse.dart';
import '../effects/lightning_painter.dart';
import '../debug/debug_hud.dart';

class GameCanvas extends StatefulWidget {
  final int currentWorld;
  final int nextWorld;

  final Color backgroundColor;
  final Color pulseColor;

  final WorldSurgePulse surge;
  final List<Balloon> balloons;
  final List<PopParticle> particles;
  final List<ScoreBurst> scoreBursts;
  final List<PopShockwave> shockwaves;
  final List<MissPopup> missPopups;
  final double popShake;
  final GameState gameState;

  final VoidCallback onLongPress;
  final GestureTapDownCallback onTapDown;

  final bool showHud;
  final double fps;
  final double speedMultiplier;
  final double recentAccuracy;
  final double runAccuracy;
  final int recentMisses;
  final int streak;

  const GameCanvas({
    super.key,
    required this.currentWorld,
    required this.nextWorld,
    required this.backgroundColor,
    required this.pulseColor,
    required this.surge,
    required this.balloons,
    required this.particles,
    required this.scoreBursts,
    required this.shockwaves,
    required this.missPopups,
    required this.popShake,
    required this.gameState,
    required this.onLongPress,
    required this.onTapDown,
    required this.showHud,
    required this.fps,
    required this.speedMultiplier,
    required this.recentAccuracy,
    required this.runAccuracy,
    required this.recentMisses,
    required this.streak,
  });

  @override
  State<GameCanvas> createState() => _GameCanvasState();
}

class _GameCanvasState extends State<GameCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _milestoneController;
  late final Animation<double> _milestoneScale;

  int _currentMilestone = 0;

  Color _burstColor() {
    if (widget.streak >= 100) {
      return const Color(0xFFFFF176);
    }

    if (widget.streak >= 30) {
      return const Color(0xFF00E5FF);
    }

    if (widget.streak >= 20) {
      return const Color(0xFFFFD54F);
    }

    if (widget.streak >= 10) {
      return const Color(0xFFFFF176);
    }

    return Colors.white;
  }

  List<Shadow> _burstShadows() {
    if (widget.streak >= 100) {
      return const [
        Shadow(color: Colors.black, blurRadius: 6),
        Shadow(color: Colors.orange, blurRadius: 18),
        Shadow(color: Colors.yellow, blurRadius: 32),
      ];
    }

    if (widget.streak >= 30) {
      return const [
        Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
        Shadow(color: Color(0xFF00E5FF), blurRadius: 10),
      ];
    }

    if (widget.streak >= 20) {
      return const [
        Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
        Shadow(color: Color(0xFFFFC107), blurRadius: 10),
      ];
    }

    if (widget.streak >= 10) {
      return const [
        Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
        Shadow(color: Color(0xFFFFE082), blurRadius: 6),
      ];
    }

    return const [
      Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
    ];
  }

  Color _perfectBurstColor() {
    if (widget.streak >= 30) {
      return const Color(0xFFFFF59D);
    }

    if (widget.streak >= 20) {
      return const Color(0xFFFFF176);
    }

    return const Color(0xFFFFF9C4);
  }

  List<Shadow> _perfectBurstShadows() {
    return const [
      Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
      Shadow(color: Color(0xFFFFC107), blurRadius: 10),
      Shadow(color: Color(0xFFFFE082), blurRadius: 20),
    ];
  }

  List<Shadow> _missPopupShadows() {
    return const [
      Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
      Shadow(color: Color(0xFF8E0000), blurRadius: 12),
      Shadow(color: Color(0xFFFF5252), blurRadius: 18),
    ];
  }

  @override
  void initState() {
    super.initState();

    _currentMilestone = _milestoneFor(widget.streak);

    _milestoneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );

    _milestoneScale = Tween<double>(begin: 1.25, end: 1.0).animate(
      CurvedAnimation(
        parent: _milestoneController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant GameCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    final prevMilestone = _milestoneFor(oldWidget.streak);
    final nextMilestone = _milestoneFor(widget.streak);

    if (widget.streak <= 0) {
      _currentMilestone = 0;
      _milestoneController.value = 1.0;
      return;
    }

    _currentMilestone = nextMilestone;

    if (nextMilestone > prevMilestone) {
      _milestoneController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _milestoneController.dispose();
    super.dispose();
  }

  int _milestoneFor(int streak) {
    if (streak >= 100) return 4;
    if (streak >= 30) return 3;
    if (streak >= 20) return 2;
    if (streak >= 10) return 1;
    return 0;
  }

  bool get _isBrightWorld => widget.currentWorld == 1;

  Color _streakTierAccent(int milestone) {
    switch (milestone) {
      case 4:
        return Colors.amber;
      case 3:
        return _isBrightWorld
            ? const Color(0xFFFFC107)
            : const Color(0xFF00E5FF);
      case 2:
        return const Color(0xFFFFC107);
      case 1:
        return const Color(0xFFFFD54F);
      default:
        return Colors.white;
    }
  }

  Color _streakBannerBg(int milestone) {
    if (milestone >= 3) return Colors.black.withOpacity(0.72);
    if (milestone >= 1) return Colors.black.withOpacity(0.42);
    return Colors.black.withOpacity(0.30);
  }

  TextStyle _streakStyleFor(int milestone) {
    if (milestone == 4) {
      return const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 1.0,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 8),
          Shadow(color: Colors.orange, blurRadius: 18),
          Shadow(color: Colors.yellow, blurRadius: 32),
        ],
      );
    }

    switch (milestone) {
      case 3:
        return TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: Colors.white,
          shadows: [
            const Shadow(color: Colors.black, blurRadius: 5, offset: Offset(0, 2)),
            Shadow(color: _streakTierAccent(3), blurRadius: 8),
          ],
        );
      case 2:
        return TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: const Color(0xFFFFEEA8),
          shadows: [
            const Shadow(color: Colors.black54, blurRadius: 10),
            Shadow(color: _streakTierAccent(2), blurRadius: 12),
          ],
        );
      case 1:
        return TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: const Color(0xFFFFF1BF),
          shadows: [
            const Shadow(color: Colors.black54, blurRadius: 9),
            Shadow(color: _streakTierAccent(1), blurRadius: 9),
          ],
        );
      default:
        return const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black45, blurRadius: 6),
          ],
        );
    }
  }

  Widget _buildStreakOverlay() {
    if (widget.streak <= 0) return const SizedBox.shrink();

    final style = _streakStyleFor(_currentMilestone);

    final label = widget.streak >= 100
        ? 'ULTRA STREAK ×${widget.streak}'
        : 'STREAK ×${widget.streak}';

    return Positioned(
      top: 18,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: ScaleTransition(
          scale: _milestoneScale,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _streakBannerBg(_currentMilestone),
                borderRadius: BorderRadius.circular(16),
                border: _currentMilestone >= 4
                    ? Border.all(color: Colors.amber, width: 2)
                    : _currentMilestone >= 3
                        ? Border.all(
                            color: _streakTierAccent(3),
                            width: 1.8,
                          )
                        : _currentMilestone >= 2
                            ? Border.all(
                                color: _streakTierAccent(2).withOpacity(0.70),
                                width: 1.2,
                              )
                            : null,
                boxShadow: _currentMilestone >= 3
                    ? [
                        BoxShadow(
                          color: _streakTierAccent(3).withOpacity(
                            _isBrightWorld ? 0.22 : 0.16,
                          ),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Text(label, style: style),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticlesOverlay() {
    if (widget.particles.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: widget.particles.map((p) {
          return Positioned(
            left: p.x,
            top: p.y,
            child: Opacity(
              opacity: p.opacity,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: p.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScoreBurstsOverlay() {
    if (widget.scoreBursts.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: widget.scoreBursts.map((b) {
          final t = b.t01;
          final rise = b.isPerfect
              ? 52.0 * Curves.easeOut.transform(t)
              : 44.0 * Curves.easeOut.transform(t);
          final fade = 1.0 - Curves.easeIn.transform(t);

          return Positioned(
            left: b.isPerfect ? b.x - 34 : b.x - 10,
            top: (b.y - rise) - (b.isPerfect ? 22 : 18),
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: b.isPerfect ? (1.0 + ((1.0 - t) * 0.12)) : 1.0,
                child: Text(
                  b.isPerfect ? 'PERFECT!' : '+${b.value}',
                  style: TextStyle(
                    color: b.isPerfect ? _perfectBurstColor() : _burstColor(),
                    fontSize: b.isPerfect ? 24 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: b.isPerfect ? 1.1 : 0.0,
                    shadows:
                        b.isPerfect ? _perfectBurstShadows() : _burstShadows(),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMissPopupsOverlay() {
    if (widget.missPopups.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: widget.missPopups.map((m) {
          final t = m.t01;
          final rise = 26.0 * Curves.easeOut.transform(t);
          final drift = 6.0 * Curves.easeOut.transform(t);

          return Positioned(
            left: m.x - 22 + drift,
            top: (m.y + 18) - rise,
            child: Opacity(
              opacity: (m.opacity * 0.95).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.96 + ((1.0 - t) * 0.08),
                child: Text(
                  m.label,
                  style: TextStyle(
                    color: const Color(0xFFFF5A5A),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    shadows: _missPopupShadows(),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildShockwaveOverlay() {
    if (widget.shockwaves.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _ShockwavePainter(widget.shockwaves),
        size: Size.infinite,
      ),
    );
  }


  Widget _buildComboGlowOverlay() {
    if (widget.streak < 10) return const SizedBox.shrink();

    double opacity;
    double radius;
    List<Color> colors;

    if (widget.streak >= 100) {
      opacity = 0.34;
      radius = 0.48;
      colors = const [
        Color(0xAAFFF59D),
        Color(0x55FFE082),
        Color(0x18FFFFFF),
        Colors.transparent,
      ];
    } else if (widget.streak >= 30) {
      opacity = 0.28;
      radius = 0.52;
      colors = const [
        Color(0x8800E5FF),
        Color(0x4400B8D4),
        Color(0x1400E5FF),
        Colors.transparent,
      ];
    } else if (widget.streak >= 20) {
      opacity = 0.22;
      radius = 0.56;
      colors = const [
        Color(0x66FFD54F),
        Color(0x30FFB300),
        Color(0x1200E5FF),
        Colors.transparent,
      ];
    } else {
      opacity = 0.16;
      radius = 0.60;
      colors = const [
        Color(0x44FFF59D),
        Color(0x1800E5FF),
        Colors.transparent,
        Colors.transparent,
      ];
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.92),
                radius: radius,
                colors: colors,
                stops: const [0.0, 0.28, 0.62, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildWorld4StarsOverlay() {
    if (widget.currentWorld != 4) return const SizedBox.shrink();

    const stars = <Offset>[
      Offset(0.08, 0.10),
      Offset(0.16, 0.18),
      Offset(0.25, 0.08),
      Offset(0.34, 0.15),
      Offset(0.45, 0.11),
      Offset(0.56, 0.07),
      Offset(0.66, 0.16),
      Offset(0.78, 0.09),
      Offset(0.89, 0.14),
      Offset(0.12, 0.28),
      Offset(0.23, 0.24),
      Offset(0.37, 0.31),
      Offset(0.49, 0.27),
      Offset(0.61, 0.34),
      Offset(0.74, 0.26),
      Offset(0.86, 0.30),
      Offset(0.18, 0.42),
      Offset(0.31, 0.47),
      Offset(0.47, 0.41),
      Offset(0.59, 0.46),
      Offset(0.73, 0.40),
      Offset(0.84, 0.44),
    ];

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _World4StarsPainter(stars),
          size: Size.infinite,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTapDown,
        child: AnimatedBuilder(
          animation: widget.surge.listenable,
          builder: (context, _) {
            final Color effectiveBg = widget.surge.showNextWorldColor
                ? widget.pulseColor
                : widget.backgroundColor;

            final bool paintBaseBg = effectiveBg.opacity > 0.0;

            final Color pulseOverlayColor = widget.surge.showNextWorldColor
                ? widget.backgroundColor
                : widget.pulseColor;

            final bool paintPulseOverlay = widget.surge.isPulseActive &&
                widget.surge.pulseOpacity > 0.0 &&
                pulseOverlayColor.opacity > 0.0;

            final bool lightningActive = widget.surge.isLightningActive;

            final double atmosphereShakeY =
                widget.surge.shakeYOffset + widget.surge.lightningShakeAmp;

            return Stack(
              children: [
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, atmosphereShakeY),
                    child: Stack(
                      children: [
                        if (paintBaseBg)
                          Positioned.fill(
                            child: ColoredBox(color: effectiveBg),
                          ),
                        if (paintPulseOverlay)
                          Positioned.fill(
                            child: Opacity(
                              opacity: widget.surge.pulseOpacity,
                              child: ColoredBox(color: pulseOverlayColor),
                            ),
                          ),
                        if (lightningActive &&
                            widget.surge.lightningDarkenOpacity > 0.0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: widget.surge.lightningDarkenOpacity,
                                child: const ColoredBox(color: Colors.black),
                              ),
                            ),
                          ),
                        if (lightningActive && widget.surge.lightningT > 0.0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: LightningPainter(
                                  t: widget.surge.lightningT,
                                  currentWorld: widget.currentWorld,
                                  seed: widget.surge.lightningSeed,
                                ),
                              ),
                            ),
                          ),
                        _buildWorld4StarsOverlay(),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      isComplex: true,
                      willChange: true,
                      painter: BalloonPainter(
                        widget.balloons,
                        widget.gameState,
                        widget.currentWorld,
                        streak: widget.streak,
                      ),
                    ),
                  ),
                ),
                if (lightningActive && widget.surge.lightningFlashOpacity > 0.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: widget.surge.lightningFlashOpacity,
                        child: const ColoredBox(color: Colors.white),
                      ),
                    ),
                  ),
                _buildComboGlowOverlay(),
                _buildShockwaveOverlay(),
                _buildParticlesOverlay(),
                _buildScoreBurstsOverlay(),
                _buildMissPopupsOverlay(),
                _buildStreakOverlay(),
                if (widget.showHud)
                  DebugHud(
                    fps: widget.fps,
                    speedMultiplier: widget.speedMultiplier,
                    world: widget.currentWorld,
                    balloonCount: widget.balloons.length,
                    recentAccuracy: widget.recentAccuracy,
                    runAccuracy: widget.runAccuracy,
                    recentMisses: widget.recentMisses,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShockwavePainter extends CustomPainter {
  final List<PopShockwave> waves;

  _ShockwavePainter(this.waves);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..blendMode = BlendMode.plus;

    for (final w in waves) {
      paint.color = Colors.white.withOpacity(w.opacity * 0.8);

      canvas.drawCircle(
        Offset(w.x, w.y),
        w.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter oldDelegate) => true;
}

class _World4StarsPainter extends CustomPainter {
  final List<Offset> stars;

  _World4StarsPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final softPaint = Paint()
      ..color = Colors.white.withOpacity(0.26)
      ..isAntiAlias = true;

    final brightPaint = Paint()
      ..color = const Color(0xFFDDF4FF).withOpacity(0.42)
      ..isAntiAlias = true;

    for (int i = 0; i < stars.length; i++) {
      final p = stars[i];
      final x = size.width * p.dx;
      final y = size.height * p.dy;

      final isBright = i % 4 == 0;
      final radius = isBright ? 1.8 : 1.1;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        isBright ? brightPaint : softPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _World4StarsPainter oldDelegate) => false;
}
