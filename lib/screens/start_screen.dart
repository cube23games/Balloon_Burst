import 'dart:async';
import 'package:flutter/material.dart';

import 'package:balloon_burst/audio/audio_warmup.dart';
import 'package:balloon_burst/audio/audio_player.dart';
import 'package:balloon_burst/tj_engine/engine/tj_engine.dart';
import 'package:balloon_burst/screens/leaderboard_screen.dart';

class StartScreen extends StatefulWidget {
  final VoidCallback onStart;
  final VoidCallback onSkyward;
  final TJEngine engine;

  const StartScreen({
    super.key,
    required this.onStart,
    required this.onSkyward,
    required this.engine,
  });

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  Timer? _tick;
  bool _showPurchaseFlash = false;

  @override
  void initState() {
    super.initState();

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _handleStart() async {
    await AudioWarmup.warmUp();
    widget.onStart();
  }

  Future<void> _handleSkyward() async {
    await AudioWarmup.warmUp();
    if (!mounted) return;
    widget.onSkyward();
  }

  Future<void> _claimReward() async {
    final reward = await widget.engine.claimDailyRewardAndCredit(
      currentWorldLevel: 1,
    );

    if (reward != null) {
      setState(() {});
    }
  }

  Future<void> _purchaseShield() async {
    final success = await widget.engine.purchaseShield();
    if (!mounted) return;

    if (success) {
      setState(() {
        _showPurchaseFlash = true;
      });

      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          _showPurchaseFlash = false;
        });
      });
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  ButtonStyle _pillStyle({
    required bool enabled,
    bool primary = false,
    bool tertiary = false,
  }) {
    const primaryBg = Color(0xFF00D8FF);
    const primaryFg = Color(0xFF04121C);

    const baseBg = Color(0xFFF3F1FF);
    const baseFg = Color(0xFF5A4FCF);

    const tertiaryBg = Color(0xFF1A3146);
    const tertiaryFg = Color(0xFFE6F4FF);

    const disabledBg = Color(0xFFDCD7F5);
    const disabledFg = Color(0xFF7A74B8);

    return ElevatedButton.styleFrom(
      shape: const StadiumBorder(),
      padding: EdgeInsets.symmetric(
        horizontal: primary ? 28 : 20,
        vertical: primary ? 15 : 12,
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
      elevation: enabled ? (primary ? 8 : tertiary ? 6 : 0) : 0,
      shadowColor: primary
          ? const Color(0xAA00D8FF)
          : tertiary
              ? const Color(0x884E7FA8)
              : const Color(0xAA5A4FCF),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;

    final status = engine.dailyReward.getStatus(
      currentWorldLevel: 1,
    );

    final canAfford = engine.wallet.balance >= TJEngine.shieldCost;

    final shieldExists =
        engine.runLifecycle.isShieldActive ||
        engine.runLifecycle.isShieldArmedForNextRun;

    final shieldEnabled = canAfford && !shieldExists;

    String shieldLabel;
    String? helperText;

    if (shieldExists) {
      shieldLabel = '🛡 Shield Armed';
      helperText = 'Absorbs your first escape';
    } else if (canAfford) {
      shieldLabel = '🛡 Add Shield Protection (${TJEngine.shieldCost} Coins)';
      helperText = 'Absorbs your first escape';
    } else {
      shieldLabel = '🛡 Shield (${TJEngine.shieldCost} Coins)';
      helperText = 'Need more coins';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09111B),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.65),
                  radius: 1.15,
                  colors: [
                    Color(0xFF163654),
                    Color(0xFF0A1623),
                    Color(0xFF05080D),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.28),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.10),
                                ),
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  final muted = await engine.toggleMute();
                                  AudioPlayerService.setMuted(muted);
                                  if (!mounted) return;
                                  setState(() {});
                                },
                                icon: Icon(
                                  engine.isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.28),
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
                                    '${engine.wallet.balance}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 34),
                        const Text(
                          'TAPJUNKIE GAMES',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'BALLOON BURST',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                              Shadow(
                                color: Color(0xFF00D8FF),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tap fast. Stay sharp. Rise through the sky.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1A28).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.30),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (status.isAvailable)
                                ElevatedButton(
                                  style: _pillStyle(enabled: true),
                                  onPressed: _claimReward,
                                  child: Text(
                                    'Claim Daily Reward\n'
                                    '${status.computedReward.coins} Coins + '
                                    '${status.computedReward.bonusPoints} Bonus',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    const Text(
                                      'DAILY REWARD',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatDuration(status.timeRemaining),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'until your next reward',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 20),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: _showPurchaseFlash
                                      ? [
                                          BoxShadow(
                                            color: Colors.amber.withOpacity(0.55),
                                            blurRadius: 24,
                                            spreadRadius: 4,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: ElevatedButton(
                                  style: _pillStyle(
                                    enabled: shieldEnabled,
                                    tertiary: true,
                                  ),
                                  onPressed: shieldEnabled ? _purchaseShield : null,
                                  child: Text(shieldLabel),
                                ),
                              ),
                              if (helperText != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  helperText,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          style: _pillStyle(enabled: true, primary: true),
                          onPressed: _handleSkyward,
                          child: const Text(
                            'SKYWARD JOURNEY',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          style: _pillStyle(enabled: true),
                          onPressed: _handleStart,
                          child: const Text(
                            'ENDLESS ARCADE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeaderboardScreen(engine: engine),
                              ),
                            );
                          },
                          child: const Text(
                            'VIEW LEADERBOARD',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
