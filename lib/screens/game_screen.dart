import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:balloon_burst/audio/audio_player.dart';
import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';
import 'package:balloon_burst/debug/debug_log.dart';
import 'package:balloon_burst/engine/momentum/momentum_controller.dart';
import 'package:balloon_burst/engine/speed/speed_curve.dart';
import 'package:balloon_burst/engine/tier/tier_controller.dart';
import 'package:balloon_burst/game/balloon_spawner.dart';
import 'package:balloon_burst/game/balloon_type.dart';
import 'package:balloon_burst/game/game_controller.dart';
import 'package:balloon_burst/game/game_state.dart';
import 'package:balloon_burst/game/end/run_end_overlay.dart';
import 'package:balloon_burst/game/end/run_end_state.dart';
import 'package:balloon_burst/gameplay/balloon.dart';
import 'package:balloon_burst/screens/game/effects/miss_popup.dart';
import 'package:balloon_burst/screens/game/effects/pop_particle.dart';
import 'package:balloon_burst/screens/game/effects/pop_shockwave.dart';
import 'package:balloon_burst/screens/game/effects/world_surge_pulse.dart';
import 'package:balloon_burst/screens/game/input/tap_handler.dart';
import 'package:balloon_burst/screens/game/intro/carnival_intro_overlay.dart';
import 'package:balloon_burst/screens/game/render/game_canvas.dart';
import 'package:balloon_burst/screens/leaderboard_screen.dart';
import 'package:balloon_burst/tj_engine/engine/run/models/run_event.dart';
import 'package:balloon_burst/tj_engine/engine/run/models/run_state.dart';
import 'package:balloon_burst/tj_engine/engine/tj_engine.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;
  final BalloonSpawner spawner;
  final TJEngine engine;
  final VoidCallback onRequestDebug;

  const GameScreen({
    super.key,
    required this.gameState,
    required this.spawner,
    required this.engine,
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

  Timer? _shieldFlashTimer;
  Timer? _reviveProtectionTimer;

  late final AnimationController _walletPulse;
  late final Animation<double> _walletScale;
  int _lastWalletBalance = 0;

  final List<Balloon> _balloons = [];
  final List<PopParticle> _particles = [];
  final List<PopShockwave> _shockwaves = [];
  final List<MissPopup> _missPopups = [];

  double _popShake = 0.0;

  Duration _lastTime = Duration.zero;
  Size _lastSize = Size.zero;

  bool _showHud = false;
  bool _showIntro = true;
  bool _canCountMisses = false;

  bool _reviveProtectionActive = false;
  bool _reviveFlashActive = false;
  bool _dangerMode = false;
  double _dangerPulseT = 0.0;

  bool _previousShieldState = false;
  bool _showShieldFlash = false;

  double _fps = 0.0;
  int _lagForgivenessTicks = 0;
  double _perfTraceClock = 0.0;
  int _perfHitchCount = 0;

  bool _leaderboardSubmitted = false;
  int? _leaderboardPlacement;
  int _lastReportedWorld = 1;

  bool _isLifecyclePaused = false;
  bool _showLifecyclePauseOverlay = false;
  DateTime? _resumeGraceUntil;

  late final AutoTapController _autoTapController;

  static const double baseRiseSpeed = 120.0;
  static const double balloonRadius = 16.0;
  static const double hitForgiveness = 18.0;
  static const double _lagHitForgiveness = 32.0;
  static const double _maxGameplayDt = 1.0 / 30.0;
  static const double _lagFrameDt = 1.0 / 24.0;
  static const int _lagForgivenessTickWindow = 8;
  static const bool _perfHitchLoggingEnabled = true;
  static const bool _perfSnapshotLoggingEnabled = false;
  static const bool _tapTraceLoggingEnabled = false;
  static const bool _skipPopAudioDuringLagForgiveness = false;
  static const double _perfTraceInterval = 0.50;
  static const double _perfHitchDt = 1.0 / 28.0;
  static const Duration _mercyWindow = Duration(milliseconds: 120);
  static const Duration _resumeGraceDuration = Duration(milliseconds: 2500);

  static const int _reviveCost = 50;
  static const int _tapJunkieVictoryPops = 500;

  static const int _maxParticles = 96;
  static const int _maxShockwaves = 14;
  static const int _maxMissPopups = 6;

  static const MethodChannel _nativeLifecycleChannel =
      MethodChannel('com.cube23.balloonburst/lifecycle');

  bool get _isRunEnded => widget.engine.runLifecycle.state == RunState.ended;

  bool get _isGameplayFrozenByLifecycle =>
      _isLifecyclePaused || _resumeGraceUntil != null;

  double get _effectiveHitForgiveness =>
      _lagForgivenessTicks > 0 ? _lagHitForgiveness : hitForgiveness;

  void _logPerfTrace({
    required String label,
    required double rawDt,
    required double dt,
  }) {
    final isHitchLabel = label == 'HITCH';

    if (isHitchLabel) {
      if (!_perfHitchLoggingEnabled) return;
    } else if (!_perfSnapshotLoggingEnabled) {
      return;
    }

    int activeCount = 0;
    double minY = 0.0;
    double maxY = 0.0;

    for (final b in _balloons) {
      if (b.isPopped) continue;

      if (activeCount == 0) {
        minY = b.y;
        maxY = b.y;
      } else {
        minY = min(minY, b.y);
        maxY = max(maxY, b.y);
      }

      activeCount++;
    }

    widget.gameState.log(
      'PERF $label '
      'rawMs=${(rawDt * 1000).toStringAsFixed(1)} '
      'gameMs=${(dt * 1000).toStringAsFixed(1)} '
      'fps=${_fps.toStringAsFixed(1)} '
      'hitches=$_perfHitchCount '
      'world=${widget.spawner.currentWorld} '
      'pops=${widget.spawner.totalPops} '
      'active=$activeCount/${_balloons.length} '
      'y=${minY.toStringAsFixed(1)}..${maxY.toStringAsFixed(1)} '
      'particles=${_particles.length} '
      'shock=${_shockwaves.length} '
      'score=${widget.engine.juice.scoreBursts.length} '
      'missPop=${_missPopups.length} '
      'speed=${widget.spawner.speedMultiplier.toStringAsFixed(2)} '
      'spawn=${widget.spawner.spawnInterval.toStringAsFixed(2)} '
      'audio=${AudioPlayerService.muted ? 'muted' : 'on'} '
      'lagForgive=$_lagForgivenessTicks',
      type: DebugEventType.perf,
    );
  }

  Future<void> _logDeviceDiagnostics() async {
    try {
      final diag = await _nativeLifecycleChannel
          .invokeMethod<Map<dynamic, dynamic>>('getDeviceDiagnostics');

      if (!mounted || diag == null) return;

      String value(String key) => '${diag[key] ?? '?'}';

      widget.gameState.log(
        'SYSTEM: DEVICE DIAG '
        'model=${value('model')} '
        'sdk=${value('sdkInt')} '
        'refreshHz=${value('refreshHz')} '
        'appHeap=${value('appHeapUsedMb')}/${value('appHeapMaxMb')}MB '
        'systemAvail=${value('systemAvailMb')}MB '
        'systemTotal=${value('systemTotalMb')}MB '
        'threshold=${value('systemThresholdMb')}MB '
        'lowMemory=${value('lowMemory')}',
        type: DebugEventType.system,
      );
    } catch (_) {
      if (!mounted) return;

      widget.gameState.log(
        'SYSTEM: DEVICE DIAG unavailable',
        type: DebugEventType.system,
      );
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _nativeLifecycleChannel.setMethodCallHandler(_handleNativeLifecycleCall);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    widget.gameState.log(
      'SYSTEM: GAME WIRED',
      type: DebugEventType.system,
    );

    unawaited(_logDeviceDiagnostics());

    AudioPlayerService.warmUpPop();

    widget.engine.difficulty.reset();
    widget.engine.runLifecycle.startRun(
      runId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    _lastReportedWorld = widget.spawner.currentWorld;

    _controller = GameController(
      momentum: MomentumController(),
      tier: TierController(),
      speed: SpeedCurve(),
      gameState: widget.gameState,
    );

    _surge = WorldSurgePulse(vsync: this);
    _autoTapController = AutoTapController();

    _lastWalletBalance = widget.engine.wallet.balance;
    _walletPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _walletScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 50,
      ),
    ]).animate(_walletPulse);

    _ticker = createTicker(_onTick)..start();
  }

  void _triggerShieldBreakFeedback() {
    _showShieldFlash = true;

    _shieldFlashTimer?.cancel();
    _shieldFlashTimer = Timer(
      const Duration(milliseconds: 250),
      () {
        if (!mounted) return;
        setState(() {
          _showShieldFlash = false;
        });
      },
    );

    AudioPlayerService.playShieldBreak();
    if (mounted) setState(() {});
  }

  void _trimVisualEffects() {
    _trimOldest(_particles, _maxParticles);
    _trimOldest(_shockwaves, _maxShockwaves);
    _trimOldest(_missPopups, _maxMissPopups);
  }

  void _trimOldest<T>(List<T> items, int maxItems) {
    if (items.length <= maxItems) return;

    items.removeRange(0, items.length - maxItems);
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

  Future<void> _handleNativeLifecycleCall(MethodCall call) async {
    switch (call.method) {
      case 'nativePause':
        _pauseForNativeLifecycle('${call.arguments ?? 'native'}');
        return;
      case 'nativeResume':
        _resumeFromLifecyclePause();
        return;
      case 'nativeResumeSilent':
        _resumeFromNativeLifecycleSilently();
        return;
      case 'nativeDebug':
        widget.gameState.log(
          'SYSTEM: native debug ${call.arguments ?? ''}',
          type: DebugEventType.system,
        );
        return;
      default:
        return;
    }
  }

  void _pauseForNativeLifecycle(String reason) {
    if (_isRunEnded) return;

    if (_isLifecyclePaused) {
      if (!_showLifecyclePauseOverlay) {
        setState(() {
          _showLifecyclePauseOverlay = true;
        });
      }
      return;
    }

    _isLifecyclePaused = true;
    _showLifecyclePauseOverlay = true;
    _resumeGraceUntil = null;
    _lastTime = Duration.zero;

    if (_ticker.isActive) {
      _ticker.stop();
    }

    widget.gameState.log(
      'SYSTEM: native lifecycle pause ($reason)',
      type: DebugEventType.system,
    );

    if (mounted) setState(() {});
  }

  void _pauseForLifecycle(
    AppLifecycleState state, {
    required bool showOverlayImmediately,
  }) {
    if (_isRunEnded) return;

    if (_isLifecyclePaused) {
      if (showOverlayImmediately && !_showLifecyclePauseOverlay) {
        setState(() {
          _showLifecyclePauseOverlay = true;
        });
      }
      return;
    }

    _isLifecyclePaused = true;
    _showLifecyclePauseOverlay = showOverlayImmediately;
    _resumeGraceUntil = null;
    _lastTime = Duration.zero;

    if (_ticker.isActive) {
      _ticker.stop();
    }

    widget.gameState.log(
      showOverlayImmediately
          ? 'SYSTEM: lifecycle visible pause ($state)'
          : 'SYSTEM: lifecycle silent freeze ($state)',
      type: DebugEventType.system,
    );

    if (mounted) setState(() {});
  }

  void _resumeFromLifecyclePause() {
    if (!_isLifecyclePaused || _isRunEnded) {
      return;
    }

    final shouldUseGrace = _showLifecyclePauseOverlay;

    _isLifecyclePaused = false;
    _showLifecyclePauseOverlay = false;
    _resumeGraceUntil =
        shouldUseGrace ? DateTime.now().add(_resumeGraceDuration) : null;
    _lastTime = Duration.zero;

    widget.gameState.log(
      shouldUseGrace
          ? 'SYSTEM: lifecycle resume grace'
          : 'SYSTEM: lifecycle silent resume',
      type: DebugEventType.system,
    );

    if (!_ticker.isActive) {
      _ticker.start();
    }

    if (mounted) setState(() {});
  }

  void _resumeFromNativeLifecycleSilently() {
    if (_isRunEnded) return;

    _isLifecyclePaused = false;
    _showLifecyclePauseOverlay = false;
    _resumeGraceUntil = null;
    _lastTime = Duration.zero;

    widget.gameState.log(
      'SYSTEM: native lifecycle silent resume',
      type: DebugEventType.system,
    );

    if (!_ticker.isActive) {
      _ticker.start();
    }

    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeFromLifecyclePause();
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Ignore focus-loss blips entirely.
      // Screenshots, tiny system overlays, and some notification flashes can
      // report inactive even though the game is still visible.
      return;
    }

    _pauseForLifecycle(state, showOverlayImmediately: true);
  }

  void _onTick(Duration elapsed) {
    if (_isRunEnded) {
      _lastTime = elapsed;
      _maybeSubmitLeaderboard();
      if (mounted) setState(() {});
      return;
    }

    if (_isLifecyclePaused) {
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
      _lastTime = Duration.zero;
      if (mounted) setState(() {});
      return;
    }

    final rawDt = (_lastTime == Duration.zero)
        ? 0.016
        : (elapsed - _lastTime).inMicroseconds / 1e6;

    _lastTime = elapsed;

    final dt = rawDt.clamp(0.0, _maxGameplayDt).toDouble();

    if (rawDt >= _lagFrameDt) {
      _lagForgivenessTicks = _lagForgivenessTickWindow;
    } else if (_lagForgivenessTicks > 0) {
      _lagForgivenessTicks--;
    }

    final instFps = rawDt > 0 ? (1.0 / rawDt) : 0.0;
    _fps = (_fps == 0.0) ? instFps : (_fps * 0.9 + instFps * 0.1);
    _perfTraceClock += rawDt;
    final isPerfHitch = rawDt >= _perfHitchDt;
    if (isPerfHitch) {
      _perfHitchCount++;
    }
    widget.gameState.viewportHeight = _lastSize.height;

    widget.engine.update(dt);

    final shieldNow = widget.engine.runLifecycle.isShieldActive;
    if (_previousShieldState && !shieldNow) {
      _triggerShieldBreakFeedback();
    }
    _previousShieldState = shieldNow;

    final currentBalance = widget.engine.wallet.balance;
    if (currentBalance < _lastWalletBalance) {
      _walletPulse.forward(from: 0);
    }
    _lastWalletBalance = currentBalance;

    final accuracy = _controller.accuracy01;

    double adaptiveFactor = 1.0;

    if (accuracy > 0.93) {
      adaptiveFactor = 0.94;
    } else if (accuracy < 0.75) {
      adaptiveFactor = 1.08;
    }

    final adaptiveSpawnInterval =
        widget.engine.difficulty.snapshot.spawnInterval * adaptiveFactor;

    widget.spawner.update(
      dt: dt,
      tier: 0,
      balloons: _balloons,
      viewportHeight: _lastSize.height,
      engineSpawnInterval: adaptiveSpawnInterval,
      engineMaxSimultaneousSpawns:
          widget.engine.difficulty.snapshot.maxSimultaneousSpawns,
    );

    final currentWorld = widget.spawner.currentWorld;
    if (currentWorld != _lastReportedWorld) {
      _lastReportedWorld = currentWorld;
      widget.engine.runLifecycle.report(
        WorldTransitionEvent(newWorldLevel: currentWorld),
      );
    }

    if (widget.spawner.totalPops >= _tapJunkieVictoryPops &&
        widget.engine.runLifecycle.state == RunState.running) {
      widget.engine.runLifecycle.endRun(EndReason.victory);
      _maybeSubmitLeaderboard();
      if (mounted) setState(() {});
      return;
    }

    if (!_canCountMisses && _balloons.isNotEmpty) {
      _canCountMisses = true;
    }

    for (int i = 0; i < _balloons.length; i++) {
      final b = _balloons[i];

      final engineSpeed = widget.engine.difficulty.snapshot.speedMultiplier;

      final speed = baseRiseSpeed *
          widget.spawner.speedMultiplier *
          engineSpeed *
          b.riseSpeedMultiplier;

      final moved = b.movedBy(-speed * dt);
      final driftX = moved.driftedX(
        amplitude: 0.035,
        frequency: 0.015,
      );

      _balloons[i] = moved.withXOffset(driftX);
    }

    for (int i = 0; i < _particles.length; i++) {
      _particles[i] = _particles[i].advance(dt);
    }
    _particles.removeWhere((p) => !p.alive);

    for (int i = 0; i < _shockwaves.length; i++) {
      _shockwaves[i] = _shockwaves[i].advance(dt);
    }
    _shockwaves.removeWhere((w) => !w.alive);

    for (int i = 0; i < _missPopups.length; i++) {
      _missPopups[i] = _missPopups[i].advance(dt);
    }
    _missPopups.removeWhere((m) => !m.alive);
    _trimVisualEffects();

    _popShake *= 0.85;
    if (_popShake < 0.1) {
      _popShake = 0;
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
      final tapTime = _controller.lastTapTime;

      if (tapTime != null &&
          DateTime.now().difference(tapTime) < _mercyWindow) {
        widget.gameState.log(
          'MERCY POP PREVENTED ESCAPE',
          type: DebugEventType.system,
        );
        escapedThisTick = 0;
      }

      if (escapedThisTick > 0 && !_reviveProtectionActive) {
        _controller.registerEscapes(escapedThisTick);
        widget.engine.runLifecycle.report(
          EscapeEvent(count: escapedThisTick),
        );
      }
    }

    _balloons.sort((a, b) =>
        balloonTypeConfig[a.type]!.zLayer.compareTo(
          balloonTypeConfig[b.type]!.zLayer,
        ));

    _controller.update(_balloons, dt);

    _autoTapController
      ..enabled = widget.gameState.autoTapEnabled
      ..mode = _autoTapModeFromIndex(widget.gameState.autoTapModeIndex);

    _autoTapController.update(
      canTap:
          !_showIntro && !_isRunEnded && !_isGameplayFrozenByLifecycle && _canCountMisses,
      lastSize: _lastSize,
      balloons: _balloons,
      onTapAt: _handleAutoTapAt,
    );

    final escapesNow = widget.engine.runLifecycle.getSnapshot().escapes;

    _dangerMode = _controller.missCount >= 9 || escapesNow >= 2;

    if (_dangerMode) {
      _dangerPulseT += dt * 1.45;
    } else {
      _dangerPulseT = 0.0;
    }

    _surge.maybeTrigger(
      totalPops: widget.spawner.totalPops,
      currentWorld: widget.spawner.currentWorld,
      world2Pops: BalloonSpawner.world2Pops,
      world3Pops: BalloonSpawner.world3Pops,
      world4Pops: BalloonSpawner.world4Pops,
    );

    if (isPerfHitch || _perfTraceClock >= _perfTraceInterval) {
      _logPerfTrace(
        label: isPerfHitch ? 'HITCH' : 'SNAP',
        rawDt: rawDt,
        dt: dt,
      );

      if (_perfTraceClock >= _perfTraceInterval) {
        _perfTraceClock = 0.0;
      }
    }

    setState(() {});
  }

  void _maybeSubmitLeaderboard() {
    if (_leaderboardSubmitted) return;

    _leaderboardSubmitted = true;
    final summary = widget.engine.runLifecycle.latestSummary;

    if (summary != null) {
      widget.engine.creditRunCoins(summary);
    }

    widget.engine.submitLatestRunToLeaderboard().then((placement) {
      if (!mounted) return;
      setState(() {
        _leaderboardPlacement = placement;
      });
    });
  }

  int _milestoneForStreak(int streak) {
    if (streak >= 30) return 3;
    if (streak >= 20) return 2;
    if (streak >= 10) return 1;
    return 0;
  }

  void _handleAutoTapAt(Offset localPosition) {
    _handleTap(
      TapDownDetails(
        localPosition: localPosition,
        globalPosition: localPosition,
      ),
    );
  }

  AutoTapMode _autoTapModeFromIndex(int index) {
    switch (index) {
      case 1:
        return AutoTapMode.human;
      case 2:
        return AutoTapMode.fail;
      default:
        return AutoTapMode.clean;
    }
  }

  void _toggleAutoTap() {
    setState(() {
      widget.gameState.toggleAutoTap();
    });

    if (!widget.gameState.autoTapEnabled) {
      _autoTapController.reset();
    }
  }

  void _cycleAutoTapMode() {
    setState(() {
      widget.gameState.cycleAutoTapMode();
    });
  }

  Widget _buildDebugHudChip({
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? Colors.amberAccent.withOpacity(0.16)
                : Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? Colors.amberAccent.withOpacity(0.55)
                  : Colors.white.withOpacity(0.10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.amberAccent : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    if (_showIntro) return;
    if (_isGameplayFrozenByLifecycle) return;
    if (_isRunEnded || !_canCountMisses) return;

    final prevStreak = widget.engine.runLifecycle.getSnapshot().streak;
    final missesBefore = _controller.missCount;
    final popsBefore = widget.spawner.totalPops;
    final activeBefore = _balloons.where((b) => !b.isPopped).length;
    final p = details.localPosition;

    if (_tapTraceLoggingEnabled) {
      widget.gameState.log(
        'TAP DOWN '
        'x=${p.dx.toStringAsFixed(1)} '
        'y=${p.dy.toStringAsFixed(1)} '
        'world=${widget.spawner.currentWorld} '
        'active=$activeBefore/${_balloons.length} '
        'particles=${_particles.length} '
        'shock=${_shockwaves.length} '
        'score=${widget.engine.juice.scoreBursts.length} '
        'audio=${AudioPlayerService.muted ? 'muted' : 'on'}',
        type: DebugEventType.perf,
      );
    }

    widget.engine.input.registerTap();
    TapHandler.handleTap(
      details: details,
      lastSize: _lastSize,
      balloons: _balloons,
      gameState: widget.gameState,
      spawner: widget.spawner,
      controller: _controller,
      surge: _surge,
      balloonRadius: balloonRadius,
      hitForgiveness: _effectiveHitForgiveness,
    );

    final missesAfter = _controller.missCount;

    if (missesAfter > missesBefore) {
      _missPopups.add(
        MissPopup(
          x: p.dx,
          y: p.dy,
          age: 0,
          life: 0.42,
          label: 'MISS',
          color: const Color(0xFFFF6B6B),
        ),
      );

      for (final b in _balloons) {
        if (b.isPopped) continue;

        final bx = (_lastSize.width / 2) + b.xOffset * _lastSize.width * 0.5;
        final by = b.y;

        final dx = p.dx - bx;
        final dy = p.dy - by;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < balloonRadius + 32 && dist > balloonRadius) {
          final nearMissBurst = PopParticle.burst(p.dx, p.dy);

          _particles.addAll(
            nearMissBurst
                .map((p) => PopParticle(
                      x: p.x,
                      y: p.y,
                      vx: p.vx * 0.55,
                      vy: p.vy * 0.55,
                      age: p.age,
                      life: 0.24,
                      color: const Color(0xFFEAF7FF),
                    ))
                .toList(),
          );

          _particles.addAll(
            nearMissBurst.take(6).map((p) => PopParticle(
                  x: p.x,
                  y: p.y,
                  vx: p.vx * 0.28,
                  vy: p.vy * 0.28,
                  age: p.age,
                  life: 0.14,
                  color: Colors.white,
                )),
          );

          break;
        }
      }

      if (!_reviveProtectionActive) {
        widget.engine.runLifecycle.report(const MissEvent());
      }

      _trimVisualEffects();

      if (_tapTraceLoggingEnabled) {
        widget.gameState.log(
          'TAP RESULT miss '
          'missDelta=${missesAfter - missesBefore} '
          'popsDelta=${widget.spawner.totalPops - popsBefore} '
          'activeBefore=$activeBefore '
          'activeAfter=${_balloons.where((b) => !b.isPopped).length} '
          'particles=${_particles.length} '
          'shock=${_shockwaves.length} '
          'score=${widget.engine.juice.scoreBursts.length}',
          type: DebugEventType.perf,
        );
      }

      return;
    }

    widget.engine.runLifecycle.report(PopEvent(points: 1));

    final shouldPlayPopSound =
        !_skipPopAudioDuringLagForgiveness || _lagForgivenessTicks == 0;

    if (shouldPlayPopSound) {
      AudioPlayerService.playPop();
    }

    widget.engine.juice.spawnScoreBurst(
      x: p.dx,
      y: p.dy,
      value: 1,
      isPerfect: _controller.lastTapPerfect,
    );

    final popBurst = PopParticle.burst(p.dx, p.dy);
    _particles.addAll(
      popBurst.take(_controller.timingLockActive ? 6 : 10),
    );

    if (_controller.timingLockActive) {
      final timingBurst = PopParticle.burst(p.dx, p.dy);

      _particles.addAll(
        timingBurst.take(3).map((p) => PopParticle(
              x: p.x,
              y: p.y,
              vx: p.vx * 0.42,
              vy: p.vy * 0.42,
              age: p.age,
              life: 0.22,
              color: const Color(0xFF7EEBFF),
            )),
      );
    }

    _shockwaves.add(
      PopShockwave(
        x: p.dx,
        y: p.dy,
        age: 0,
        life: _controller.timingLockActive ? 0.34 : 0.35,
      ),
    );

    _trimVisualEffects();

    if (_tapTraceLoggingEnabled) {
      widget.gameState.log(
        'TAP RESULT hit '
        'perfect=${_controller.lastTapPerfect} '
        'timing=${_controller.timingLockActive} '
        'popsDelta=${widget.spawner.totalPops - popsBefore} '
        'activeBefore=$activeBefore '
        'activeAfter=${_balloons.where((b) => !b.isPopped).length} '
        'particles=${_particles.length} '
        'shock=${_shockwaves.length} '
        'score=${widget.engine.juice.scoreBursts.length}',
        type: DebugEventType.perf,
      );
    }

    _popShake = _controller.lastTapPerfect
        ? (_controller.timingLockActive ? 14.0 : 10.0)
        : (_controller.timingLockActive ? 10.0 : 6.0);

    final nextStreak = widget.engine.runLifecycle.getSnapshot().streak;
    final prevMilestone = _milestoneForStreak(prevStreak);
    final nextMilestone = _milestoneForStreak(nextStreak);

    if (nextMilestone > prevMilestone) {
      AudioPlayerService.playStreakMilestone(nextMilestone);
    }
  }

  void _handleLongPress() {
    if (_showIntro) return;
    setState(() => _showHud = !_showHud);
    widget.onRequestDebug();
  }

  void _replay() {
    _balloons.clear();
    _particles.clear();
    _shockwaves.clear();
    _missPopups.clear();
    _canCountMisses = false;

    _leaderboardSubmitted = false;
    _leaderboardPlacement = null;

    _isLifecyclePaused = false;
    _showLifecyclePauseOverlay = false;
    _resumeGraceUntil = null;

    if (!_ticker.isActive) {
      _ticker.start();
    }

    _controller.reset();
    widget.spawner.resetForNewRun();
    _surge.reset();

    widget.gameState.clearLogs();
    _lastTime = Duration.zero;

    widget.engine.difficulty.reset();
    widget.engine.runLifecycle.startRun(
      runId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    setState(() {});
  }

  Future<void> _revive() async {
    final success = await widget.engine.wallet.spendCoins(_reviveCost);
    if (!success) return;

    _leaderboardSubmitted = false;
    _leaderboardPlacement = null;

    _dangerMode = false;
    _dangerPulseT = 0.0;
    _controller.clearDangerTelemetryForRevive();

    widget.engine.runLifecycle.revive();

    _reviveProtectionActive = true;
    _reviveProtectionTimer?.cancel();
    _reviveProtectionTimer = Timer(
      const Duration(milliseconds: 1250),
      () {
        if (!mounted) return;
        setState(() {
          _reviveProtectionActive = false;
        });
      },
    );

    _reviveFlashActive = true;
    AudioPlayerService.playStreakMilestone(1);

    Future.delayed(
      const Duration(milliseconds: 500),
      () {
        if (!mounted) return;
        setState(() {
          _reviveFlashActive = false;
        });
      },
    );

    setState(() {});
  }

  @override
  void dispose() {
    _nativeLifecycleChannel.setMethodCallHandler(null);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.removeObserver(this);
    _shieldFlashTimer?.cancel();
    _reviveProtectionTimer?.cancel();
    _walletPulse.dispose();
    _surge.dispose();
    _ticker.dispose();
    super.dispose();
  }

  Widget _buildLifecyclePauseOverlay() {
    final shouldShowPausedOverlay =
        _isLifecyclePaused && _showLifecyclePauseOverlay;

    if (_showIntro ||
        _isRunEnded ||
        (!shouldShowPausedOverlay && _resumeGraceUntil == null)) {
      return const SizedBox.shrink();
    }

    final paused = shouldShowPausedOverlay;
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
    final summary = widget.engine.runLifecycle.latestSummary;

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
              IgnorePointer(child: Container(color: bgColor)),
              if (_dangerMode)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withOpacity(0.32),
                    ),
                  ),
                ),
              if (_dangerMode)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Builder(
                      builder: (_) {
                        final primaryBeat =
                            pow((sin(_dangerPulseT).clamp(0.0, 1.0)), 2).toDouble();
                        final secondaryBeat =
                            pow((sin(_dangerPulseT * 2.0 + 0.55).clamp(0.0, 1.0)), 4)
                                .toDouble();
                        final beat = (primaryBeat * 0.72) + (secondaryBeat * 0.28);

                        return Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              radius: 1.02,
                              colors: [
                                Colors.transparent,
                                const Color(0x55B71C1C).withOpacity(
                                  0.18 + (beat * 0.18),
                                ),
                                const Color(0xFFFF3D3D).withOpacity(
                                  0.42 + (beat * 0.30),
                                ),
                              ],
                              stops: const [0.52, 0.82, 1.0],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (_showShieldFlash)
                IgnorePointer(
                  child: Container(
                    color: Colors.amber.withOpacity(0.25),
                  ),
                ),
              GameCanvas(
                currentWorld: currentWorld,
                nextWorld: nextWorld,
                backgroundColor: Colors.transparent,
                pulseColor: _backgroundForWorld(nextWorld),
                surge: _surge,
                balloons: _balloons,
                particles: _particles,
                scoreBursts: widget.engine.juice.scoreBursts,
                shockwaves: _shockwaves,
                missPopups: _missPopups,
                popShake: _popShake,
                gameState: widget.gameState,
                onTapDown: _handleTap,
                onLongPress: _handleLongPress,
                showHud: _showHud,
                fps: _fps,
                speedMultiplier:
                    widget.engine.difficulty.snapshot.speedMultiplier,
                recentAccuracy: _controller.accuracy01,
                runAccuracy: widget.engine.runLifecycle.getSnapshot().accuracy01,
                recentMisses: _controller.missCount,
                streak: widget.engine.runLifecycle.getSnapshot().streak,
              ),
              _buildLifecyclePauseOverlay(),
              if (_showIntro)
                CarnivalIntroOverlay(
                  onComplete: () {
                    setState(() {
                      _showIntro = false;
                    });
                  },
                ),
              if (_isRunEnded && summary != null)
                RunEndOverlay(
                  state: RunEndState.fromSummary(summary),
                  onReplay: _replay,
                  onRevive: _revive,
                  placement: _leaderboardPlacement,
                  onViewLeaderboard: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LeaderboardScreen(engine: widget.engine),
                      ),
                    );
                  },
                  engine: widget.engine,
                ),
              if (_reviveFlashActive)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                ),
              Positioned(
                top: 44,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _showHud ? Icons.bug_report : Icons.bug_report_outlined,
                      color: _showHud ? Colors.amberAccent : Colors.white,
                    ),
                    tooltip: _showHud ? 'Hide debug HUD' : 'Show debug HUD',
                    onPressed: _handleLongPress,
                  ),
                ),
              ),
              if (_showHud && kDebugMode)
                Positioned(
                  top: 104,
                  left: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDebugHudChip(
                        label: 'AUTO: ${widget.gameState.autoTapEnabled ? 'ON' : 'OFF'}',
                        onTap: _toggleAutoTap,
                        active: widget.gameState.autoTapEnabled,
                      ),
                      const SizedBox(width: 8),
                      _buildDebugHudChip(
                        label: 'MODE: ${widget.gameState.autoTapModeLabel}',
                        onTap: _cycleAutoTapMode,
                        active: widget.gameState.autoTapEnabled,
                      ),
                    ],
                  ),
                ),
              Positioned(
                top: 44,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          widget.engine.isMuted
                              ? Icons.volume_off
                              : Icons.volume_up,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          final muted = await widget.engine.toggleMute();
                          AudioPlayerService.setMuted(muted);
                          if (!mounted) return;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ScaleTransition(
                      scale: _walletScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.engine.wallet.balance}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
        return const Color(0xFF2B6CB0);
      case 3:
        return const Color(0xFF5A2BC0);
      case 4:
        return const Color(0xFF0B1220);
      default:
        return const Color(0xFF6EC6FF);
    }
  }
}
