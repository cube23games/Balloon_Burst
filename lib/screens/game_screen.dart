import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:balloon_burst/game/game_state.dart';
import 'package:balloon_burst/debug/debug_log.dart';
import 'package:balloon_burst/game/game_controller.dart';
import 'package:balloon_burst/game/balloon_spawner.dart';
import 'package:balloon_burst/gameplay/balloon.dart';

import 'package:balloon_burst/engine/momentum/momentum_controller.dart';
import 'package:balloon_burst/engine/tier/tier_controller.dart';
import 'package:balloon_burst/engine/speed/speed_curve.dart';

import 'package:balloon_burst/screens/game/render/game_canvas.dart';
import 'package:balloon_burst/screens/game/effects/world_surge_pulse.dart';
import 'package:balloon_burst/screens/game/input/tap_handler.dart';

import 'package:balloon_burst/game/end/run_end_overlay.dart';
import 'package:balloon_burst/game/end/run_end_state.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;
  final BalloonSpawner spawner;
  final VoidCallback onRequestDebug;

  const GameScreen({
    super.key,
    required this.gameState,
    required this.spawner,
    required this.onRequestDebug,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  late final GameController _controller;
  late final WorldSurgePulse _surge;

  final List<Balloon> _balloons = [];

  Duration _lastTime = Duration.zero;
  Size _lastSize = Size.zero;

  bool _showHud = false;
  double _fps = 0.0;
  bool _canCountMisses = false;

  bool _isLifecyclePaused = false;
  DateTime? _resumeGraceUntil;

  static const Duration _resumeGraceDuration = Duration(milliseconds: 2500);

  static const double baseRiseSpeed = 120.0;
  static const double balloonRadius = 16.0;
  static const double hitForgiveness = 18.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    widget.gameState.log(
      'SYSTEM: GAME WIRED',
      type: DebugEventType.system,
    );

    _controller = GameController(
      momentum: MomentumController(),
      tier: TierController(),
      speed: SpeedCurve(),
      gameState: widget.gameState,
    );

    _surge = WorldSurgePulse(vsync: this);
    _ticker = createTicker(_onTick)..start();
  }

  int _resumeSecondsRemaining() {
    final until = _resumeGraceUntil;
    if (until == null) return 0;

    final remainingMs = until.difference(DateTime.now()).inMilliseconds;
    if (remainingMs <= 0) return 0;

    return (remainingMs / 1000).ceil().clamp(1, 3);
  }

  bool get _isInResumeGrace {
    final until = _resumeGraceUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _pauseForLifecycle(AppLifecycleState state) {
    if (_isLifecyclePaused) return;

    _isLifecyclePaused = true;
    _resumeGraceUntil = null;
    _lastTime = Duration.zero;

    if (_ticker.isActive) {
      _ticker.stop();
    }

    widget.gameState.log(
      'SYSTEM: lifecycle pause ($state)',
      type: DebugEventType.system,
    );

    if (mounted) setState(() {});
  }

  void _resumeWithGrace() {
    if (_controller.isEnded) return;

    _isLifecyclePaused = false;
    _resumeGraceUntil = DateTime.now().add(_resumeGraceDuration);
    _lastTime = Duration.zero;

    widget.gameState.log(
      'SYSTEM: lifecycle resume grace',
      type: DebugEventType.system,
    );

    if (!_ticker.isActive) {
      _ticker.start();
    }

    if (mounted) setState(() {});

    Future.delayed(_resumeGraceDuration + const Duration(milliseconds: 80), () {
      if (!mounted) return;
      if (_resumeGraceUntil != null && !_isInResumeGrace) {
        setState(() {
          _resumeGraceUntil = null;
          _lastTime = Duration.zero;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeWithGrace();
    } else {
      _pauseForLifecycle(state);
    }
  }

  void _onTick(Duration elapsed) {
    if (_controller.isEnded || _isLifecyclePaused) {
      _lastTime = elapsed;
      return;
    }

    if (_resumeGraceUntil != null) {
      if (_isInResumeGrace) {
        _lastTime = elapsed;
        if (mounted) setState(() {});
        return;
      }

      _resumeGraceUntil = null;
      _lastTime = elapsed;
      if (mounted) setState(() {});
      return;
    }

    final dt = (_lastTime == Duration.zero)
        ? 0.016
        : (elapsed - _lastTime).inMicroseconds / 1e6;
    _lastTime = elapsed;

    final instFps = dt > 0 ? (1.0 / dt) : 0.0;
    _fps = (_fps == 0.0) ? instFps : (_fps * 0.9 + instFps * 0.1);

    widget.spawner.update(
      dt: dt,
      tier: 0,
      balloons: _balloons,
      viewportHeight: _lastSize.height,
    );

    if (!_canCountMisses && _balloons.isNotEmpty) {
      _canCountMisses = true;
      widget.gameState.log(
        'SYSTEM: first balloons spawned',
        type: DebugEventType.system,
      );
    }

    for (int i = 0; i < _balloons.length; i++) {
      final b = _balloons[i];
      final speed = baseRiseSpeed *
          widget.spawner.speedMultiplier *
          b.riseSpeedMultiplier;
      _balloons[i] = b.movedBy(-speed * dt);
    }

    int escapedThisTick = 0;

    for (int i = _balloons.length - 1; i >= 0; i--) {
      final b = _balloons[i];
      if (b.y < -balloonRadius) {
        if (!b.isPopped) escapedThisTick++;
        _balloons.removeAt(i);
      }
    }

    if (escapedThisTick > 0) {
      _controller.registerEscapes(escapedThisTick);
      widget.gameState.log(
        'MISS: escaped=$escapedThisTick',
        type: DebugEventType.miss,
      );
    }

    _controller.update(_balloons, dt);

    if (widget.gameState.framesSinceStart % 120 == 0) {
      widget.gameState.log(
        'SPEED: mult=${widget.spawner.speedMultiplier.toStringAsFixed(2)} '
        'interval=${widget.spawner.spawnInterval.toStringAsFixed(2)} '
        'world=${widget.spawner.currentWorld}',
        type: DebugEventType.speed,
      );
    }

    _surge.maybeTrigger(
      totalPops: widget.spawner.totalPops,
      currentWorld: widget.spawner.currentWorld,
      world2Pops: BalloonSpawner.world2Pops,
      world3Pops: BalloonSpawner.world3Pops,
      world4Pops: BalloonSpawner.world4Pops,
    );

    setState(() {});
  }

  void _handleTap(TapDownDetails details) {
    if (_isLifecyclePaused || _resumeGraceUntil != null) return;

    if (_controller.isEnded) return;
    if (!_canCountMisses) return;

    TapHandler.handleTap(
      details: details,
      lastSize: _lastSize,
      balloons: _balloons,
      gameState: widget.gameState,
      spawner: widget.spawner,
      controller: _controller,
      surge: _surge,
      balloonRadius: balloonRadius,
      hitForgiveness: hitForgiveness,
    );

    if (_controller.isEnded) {
      setState(() {});
    }
  }

  void _handleLongPress() {
    setState(() => _showHud = !_showHud);
    widget.onRequestDebug();
  }

  void _replay() {
    _balloons.clear();
    _canCountMisses = false;

    _controller.reset();
    widget.spawner.resetForNewRun();
    _surge.reset();

    _isLifecyclePaused = false;
    _resumeGraceUntil = null;

    if (!_ticker.isActive) {
      _ticker.start();
    }

    widget.gameState.clearLogs();
    widget.gameState.log(
      'SYSTEM: run reset',
      type: DebugEventType.system,
    );

    _lastTime = Duration.zero;

    widget.spawner.update(
      dt: 0.0,
      tier: 0,
      balloons: _balloons,
      viewportHeight: _lastSize.height,
    );

    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _surge.dispose();
    _ticker.dispose();
    super.dispose();
  }

  Widget _buildLifecyclePauseOverlay() {
    if (!_isLifecyclePaused && _resumeGraceUntil == null) {
      return const SizedBox.shrink();
    }

    final paused = _isLifecyclePaused;
    final seconds = _resumeSecondsRemaining();

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withOpacity(0.48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xEE08121C),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0x6600D8FF),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    paused ? 'PAUSED' : 'GET READY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: 1.4,
                      shadows: [
                        Shadow(
                          color: Color(0xFF00D8FF),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    paused
                        ? 'Game paused while app is inactive'
                        : 'Resuming in $seconds',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _lastSize = constraints.biggest;

          final currentWorld = widget.spawner.currentWorld;
          final nextWorld = currentWorld + 1;

          final bgColor = _surge.showNextWorldColor
              ? _backgroundForWorld(nextWorld)
              : _backgroundForWorld(currentWorld);

          return Stack(
            children: [
              GameCanvas(
                currentWorld: currentWorld,
                nextWorld: nextWorld,
                backgroundColor: bgColor,
                pulseColor: _backgroundForWorld(nextWorld),
                surge: _surge,
                balloons: _balloons,
                gameState: widget.gameState,
                onTapDown: _handleTap,
                onLongPress: _handleLongPress,
                showHud: _showHud,
                fps: _fps,
                speedMultiplier: widget.spawner.speedMultiplier,
                recentAccuracy: _controller.accuracy01,
                recentMisses: widget.spawner.recentMisses,
              ),
              _buildLifecyclePauseOverlay(),
              if (_controller.isEnded)
                RunEndOverlay(
                  state: RunEndState.fromController(_controller),
                  onReplay: _replay,
                ),
            ],
          );
        },
      ),
    );
  }

  Color _backgroundForWorld(int world) {
    switch (world) {
      case 2:
        return const Color(0xFF2E86DE);
      case 3:
        return const Color(0xFF6C2EB9);
      case 4:
        return const Color(0xFF0B0F2F);
      default:
        return const Color(0xFF0A0A0F);
    }
  }
}
