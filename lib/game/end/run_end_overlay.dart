import 'package:flutter/material.dart';
import 'package:balloon_burst/audio/audio_player.dart';
import 'package:balloon_burst/tj_engine/engine/tj_engine.dart';
import 'package:balloon_burst/tj_engine/engine/run/models/run_reward.dart';

import 'run_end_messages.dart';
import 'run_end_state.dart';

class RunEndOverlay extends StatefulWidget {
  final RunEndState state;
  final VoidCallback onReplay;
  final VoidCallback? onRevive;
  final int? placement;
  final VoidCallback? onViewLeaderboard;
  final TJEngine engine;

  const RunEndOverlay({
    super.key,
    required this.state,
    required this.onReplay,
    this.onRevive,
    this.placement,
    this.onViewLeaderboard,
    required this.engine,
  });

  @override
  State<RunEndOverlay> createState() => _RunEndOverlayState();
}

class _RunEndOverlayState extends State<RunEndOverlay>
    with TickerProviderStateMixin {
  static const int _reviveCost = 50;

  int _visibleRewardRows = 0;
  int _currentRewardTotal = -1;
  bool _rewardSparkle = false;
  bool _purchasingShield = false;
  bool _showResults = false;

  late final AnimationController _shieldPulse;
  late final Animation<double> _shieldScale;

  late final AnimationController _rankController;
  late final Animation<double> _rankScale;

  late final AnimationController _coinController;
  late Animation<int> _coinCounter;

  bool get _canAffordRevive => widget.engine.wallet.balance >= _reviveCost;

  bool get _canAffordShield =>
      widget.engine.wallet.balance >= TJEngine.shieldCost;

  bool get _shieldOwned =>
      widget.engine.runLifecycle.isShieldActive ||
      widget.engine.runLifecycle.isShieldArmedForNextRun;

  ButtonStyle _pillStyle({
    required bool enabled,
    bool primary = false,
    bool tertiary = false,
  }) {
    const primaryBg = Color(0xFF00D8FF);
    const primaryFg = Color(0xFF04121C);

    const baseBg = Color(0xFFF3F1FF);
    const baseFg = Color(0xFF5A4FCF);

    const tertiaryBg = Color(0xFF22405A);
    const tertiaryFg = Color(0xFFF2FAFF);

    const disabledBg = Color(0xFFDCD7F5);
    const disabledFg = Color(0xFF7A74B8);

    return ElevatedButton.styleFrom(
      shape: const StadiumBorder(),
      side: tertiary
          ? const BorderSide(color: Color(0x667FC8FF), width: 1.2)
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: tertiary ? 22 : 20,
        vertical: tertiary ? 13 : 12,
      ),
      backgroundColor: !enabled
          ? disabledBg
          : primary
              ? primaryBg
              : tertiary
                  ? tertiaryBg
                  : baseBg,
      foregroundColor: !enabled
          ? disabledFg
          : primary
              ? primaryFg
              : tertiary
                  ? tertiaryFg
                  : baseFg,
      disabledBackgroundColor: disabledBg,
      disabledForegroundColor: disabledFg,
      elevation: enabled ? (primary ? 8 : tertiary ? 8 : 4) : 0,
      shadowColor: primary
          ? const Color(0xAA00D8FF)
          : tertiary
              ? const Color(0xAA4E7FA8)
              : const Color(0xAA5A4FCF),
    );
  }

  String _accuracyRank(double accuracy) {
    if (accuracy >= 0.95) return 'S';
    if (accuracy >= 0.90) return 'A';
    if (accuracy >= 0.80) return 'B';
    return 'C';
  }

  String _rankLabel(String rank) {
    switch (rank) {
      case 'S':
        return '🏆 TAPJUNKIE';
      case 'A':
        return '🥇 TAP PRO';
      case 'B':
        return '🥈 TAP SKILLED';
      default:
        return '🥉 TAP ROOKIE';
    }
  }

  Color _rankColor(String rank) {
    switch (rank) {
      case 'S':
        return Colors.amber;
      case 'A':
        return Colors.cyanAccent;
      case 'B':
        return const Color(0xFFB0C4DE);
      default:
        return Colors.white70;
    }
  }

  List<Shadow> _rankShadows(String rank) {
    switch (rank) {
      case 'S':
        return const [
          Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
          Shadow(color: Colors.amber, blurRadius: 16),
          Shadow(color: Color(0xFFFFF176), blurRadius: 26),
        ];
      case 'A':
        return const [
          Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
          Shadow(color: Colors.cyanAccent, blurRadius: 14),
        ];
      case 'B':
        return const [
          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
          Shadow(color: Color(0xFFB0C4DE), blurRadius: 12),
        ];
      default:
        return const [
          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ];
    }
  }

  bool get _isVictory => widget.state.reason == RunEndReason.victory;

  List<Shadow> _titleShadows() {
    if (_isVictory) {
      return const [
        Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 2)),
        Shadow(color: Color(0xFFFFD54F), blurRadius: 18),
        Shadow(color: Color(0xFF00D8FF), blurRadius: 26),
      ];
    }

    return const [
      Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 2)),
      Shadow(color: Color(0xFF00D8FF), blurRadius: 22),
    ];
  }

  Widget _buildVictoryAccent() {
    if (!_isVictory) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0x22FFD54F),
        border: Border.all(color: const Color(0x66FFE082), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0x44FFD54F).withOpacity(0.55),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Text(
        '🏆 WORLD 4 CLEARED • TAPJUNKIE VICTORY',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFFFF4C2),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  int _totalForReward(RunReward reward) {
    return reward.baseCoins +
        reward.popCoins +
        reward.worldCoins +
        reward.accuracyCoins +
        reward.streakCoins;
  }

  void _maybeStartRewardAnimation(RunReward reward) {
    final total = _totalForReward(reward);
    if (_currentRewardTotal == total) return;
    AudioPlayerService.playCoinRamp(total);

    _currentRewardTotal = total;
    _rewardSparkle = false;

    _coinController.stop();
    _coinController.reset();

    _coinCounter = IntTween(
      begin: 0,
      end: total,
    ).animate(
      CurvedAnimation(
        parent: _coinController,
        curve: Curves.easeOutExpo,
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_currentRewardTotal != total) return;
      _coinController.forward(from: 0);
    });
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.10),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandLockup() {
    return Column(
      children: const [
        Text(
          'TAPJUNKIE GAMES',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'BALLOON BURST',
          style: TextStyle(
            color: Color(0xFF00D8FF),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    final snapshot = widget.engine.runLifecycle.getSnapshot();
    final accuracy = snapshot.accuracy01;
    final rank = _accuracyRank(accuracy);

    return Column(
      children: [
        if (_isVictory) ...[
          const Text(
            '🏆 TAPJUNKIE VICTORY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFE082),
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.0,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
                Shadow(color: Color(0xFFFFC107), blurRadius: 16),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        ScaleTransition(
          scale: _rankScale,
          child: Text(
            _rankLabel(rank),
            style: TextStyle(
              color: _rankColor(rank),
              fontWeight: FontWeight.w900,
              fontSize: _isVictory ? 30 : 28,
              letterSpacing: 0.9,
              shadows: _rankShadows(rank),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Accuracy ${(accuracy * 100).toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Best Streak ×${snapshot.bestStreak}',
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        if (widget.placement != null) ...[
          const SizedBox(height: 6),
          Text(
            'Leaderboard #${widget.placement}',
            style: const TextStyle(
              color: Color(0xFFD5DEE8),
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRewardBreakdown(RunReward reward) {
    Widget row(String label, int value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '+$value',
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 18),
        Text(
          _isVictory ? 'VICTORY REWARD' : 'RUN REWARD',
          style: TextStyle(
            color: _isVictory ? const Color(0xFFFFE082) : Colors.amber,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.4,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
              Shadow(color: Color(0xFFFFC107), blurRadius: 16),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _isVictory ? const Color(0xFF132230) : const Color(0xFF10212F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (_visibleRewardRows >= 1) row('Bursts', reward.popCoins),
                if (_visibleRewardRows >= 2)
                  row(
                    'Performance',
                    reward.baseCoins + reward.accuracyCoins + reward.streakCoins,
                  ),
                if (_visibleRewardRows >= 3) row('World', reward.worldCoins),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.amber.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.20),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _coinCounter,
                    builder: (context, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL EARNED',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              if (_rewardSparkle)
                                const Positioned(
                                  right: 44,
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                ),
                              Text(
                                '+${_coinCounter.value}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                    Shadow(
                                      color: Color(0xFFFFC107),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BANK',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${widget.engine.wallet.balance}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplash() {
    return Padding(
      key: const ValueKey('splash'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBrandLockup(),
          const SizedBox(height: 24),
          Text(
            RunEndMessages.title(widget.state),
            style: TextStyle(
              fontSize: _isVictory ? 36 : 34,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              shadows: _titleShadows(),
            ),
            textAlign: TextAlign.center,
          ),
          _buildVictoryAccent(),
          const SizedBox(height: 16),
          Text(
            RunEndMessages.body(widget.state),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.placement != null) ...[
            const SizedBox(height: 16),
            Text(
              'Leaderboard #${widget.placement}',
              style: const TextStyle(
                color: Color(0xFFE6EAF2),
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _purchaseShield() async {
    if (_purchasingShield) return;
    if (_shieldOwned) return;
    if (!_canAffordShield) return;

    setState(() {
      _purchasingShield = true;
    });

    final success = await widget.engine.purchaseShield();

    if (!mounted) return;

    setState(() {
      _purchasingShield = false;
    });

    if (!success) return;

    _shieldPulse.forward(from: 0);
  }

  Widget _buildResults() {
    final reward = widget.engine.lastRunReward;
    final shieldEnabled =
        !_shieldOwned && !_purchasingShield && _canAffordShield;

    final shieldLabel = _shieldOwned
        ? '🛡 Shield Armed'
        : '🛡 Start Next Run With Shield (${TJEngine.shieldCost})';

    return Padding(
      key: const ValueKey('results'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBrandLockup(),
          _buildVictoryAccent(),
          const SizedBox(height: 12),
          _buildStatsHeader(),
          if (reward != null) ...[
            _buildRewardBreakdown(reward),
          ],
          const SizedBox(height: 18),
          if (widget.onRevive != null)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: _pillStyle(enabled: true, primary: true),
                    onPressed: widget.onReplay,
                    child: const Text(
                      'REPLAY',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: _pillStyle(enabled: _canAffordRevive),
                    onPressed: _canAffordRevive ? widget.onRevive : null,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('REVIVE (50 Coins)'),
                    ),
                  ),
                ),
              ],
            )
          else
            ElevatedButton(
              style: _pillStyle(enabled: true, primary: true),
              onPressed: widget.onReplay,
              child: const Text(
                'REPLAY',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          const SizedBox(height: 10),
          ScaleTransition(
            scale: _shieldScale,
            child: ElevatedButton(
              style: _pillStyle(
                enabled: shieldEnabled,
                tertiary: true,
              ),
              onPressed: shieldEnabled ? _purchaseShield : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(shieldLabel),
              ),
            ),
          ),
          if (widget.onViewLeaderboard != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onViewLeaderboard,
              child: const Text(
                'VIEW LEADERBOARD',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _startResultsSequence() {
    Future.delayed(const Duration(milliseconds: 1350), () {
      if (!mounted) return;

      setState(() {
        _showResults = true;
      });

      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _rankController.forward();
      });

      for (int i = 1; i <= 3; i++) {
        Future.delayed(Duration(milliseconds: 140 * i), () {
          if (!mounted) return;
          setState(() => _visibleRewardRows = i);
        });
      }

      final reward = widget.engine.lastRunReward;
      if (reward != null) {
        _maybeStartRewardAnimation(reward);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _shieldPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _shieldScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.10)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.10, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_shieldPulse);

    _rankController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _rankScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.68, end: 1.32)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 46,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.32, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 54,
      ),
    ]).animate(_rankController);

    _coinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _coinCounter = IntTween(
      begin: 0,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _coinController,
        curve: Curves.easeOutExpo,
      ),
    );

    _coinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() => _rewardSparkle = true);

        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          setState(() => _rewardSparkle = false);
        });
      }
    });

    _startResultsSequence();
  }

  @override
  void didUpdateWidget(RunEndOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final reward = widget.engine.lastRunReward;
    if (_showResults && reward != null) {
      _maybeStartRewardAnimation(reward);
    }
  }

  @override
  void dispose() {
    _shieldPulse.dispose();
    _rankController.dispose();
    _coinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFF12243A),
            Color(0xFF05070D),
          ],
          radius: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1722).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.04),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 520),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: _showResults ? _buildResults() : _buildSplash(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
