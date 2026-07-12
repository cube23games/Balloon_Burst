// lib/tj_engine/engine/tj_engine.dart

import 'input/input_latch.dart';
import 'audio/audio_settings_manager.dart';
import 'core/difficulty_manager.dart';
import 'daily/daily_reward_manager.dart';
import 'daily/models/daily_reward_model.dart';
import 'leaderboard/leaderboard_entry.dart';
import 'leaderboard/leaderboard_manager.dart';
import 'run/run_lifecycle_manager.dart';
import 'run/models/run_summary.dart';
import 'run/models/run_reward.dart';
import 'shield/shield_manager.dart';
import 'wallet/wallet_manager.dart';

// 🧃 Arcade Juice
import '../juice/juice_manager.dart';

class TJEngine {
  late final ShieldManager shield;
  late final RunLifecycleManager runLifecycle;

  final DifficultyManager difficulty;
  final DailyRewardManager dailyReward;
  final LeaderboardManager leaderboard;
  final AudioSettingsManager audio;
  final WalletManager wallet;
  final input = InputLatch();

  // 🧃 Engine-owned juice module (optional, UI renders)
  final JuiceManager juice;

  RunReward? _lastRunReward;

  // Tracks the cumulative reward already credited for the active logical run.
  // After a revive, only newly earned reward coins are added to the wallet.
  String? _creditedRunId;
  int _creditedRunTotal = 0;
  int _lastCreditedRunCoins = 0;

  TJEngine({
    ShieldManager? shieldManager,
    RunLifecycleManager? runLifecycleManager,
    DifficultyManager? difficulty,
    DailyRewardManager? dailyReward,
    LeaderboardManager? leaderboard,
    AudioSettingsManager? audio,
    WalletManager? wallet,
    JuiceManager? juice,
  })  : difficulty = difficulty ?? DifficultyManager(),
        dailyReward = dailyReward ?? DailyRewardManager(),
        leaderboard = leaderboard ?? LeaderboardManager(),
        audio = audio ?? AudioSettingsManager(),
        wallet = wallet ?? WalletManager(),
        juice = juice ?? JuiceManager() {
    shield = shieldManager ?? ShieldManager();
    runLifecycle = runLifecycleManager ?? RunLifecycleManager(shield: shield);
  }

  void update(double dt) {
    difficulty.update(dt);
    juice.update(dt);
  }

  Future<void> loadAll() async {
    await leaderboard.load();
    await dailyReward.load();
    await audio.load();
    await wallet.load();
    await shield.load();
  }

  Future<DailyRewardModel?> claimDailyRewardAndCredit({
    required int currentWorldLevel,
  }) async {
    final reward = dailyReward.claim(
      currentWorldLevel: currentWorldLevel,
    );

    if (reward == null) return null;

    await wallet.addCoins(reward.coins);
    return reward;
  }

  Future<void> loadDailyReward() async {
    await dailyReward.load();
  }

  bool get isMuted => audio.muted;

  Future<void> setMuted(bool value) async {
    await audio.setMuted(value);
  }

  Future<bool> toggleMute() async {
    return audio.toggleMuted();
  }

  static const int shieldCost = 75;

  Future<bool> purchaseShield() async {
    final success = await wallet.spendCoins(shieldCost);
    if (!success) return false;

    await shield.armForNextRun();
    return true;
  }

  Future<int?> submitLatestRunToLeaderboard() async {
    final summary = runLifecycle.latestSummary;
    if (summary == null) return null;

    final entry = LeaderboardEntry(
      score: summary.score,
      worldReached: summary.worldReached,
      accuracy01: summary.accuracy01,
      bestStreak: summary.bestStreak,
      timestamp: summary.endTime,
    );

    return leaderboard.submit(entry);
  }

  // ============================================================
  // RUN REWARD SYSTEM
  // ============================================================

  RunReward? get lastRunReward => _lastRunReward;
  int get lastCreditedRunCoins => _lastCreditedRunCoins;

  RunReward calculateRunReward(RunSummary summary) {
    const base = 5;

    final popCoins = summary.pops;
    final worldCoins = summary.worldReached * 3;
    final accuracyCoins = (summary.accuracy01 * 10).round();
    final streakCoins = (summary.bestStreak / 3).floor();

    final total =
        base + popCoins + worldCoins + accuracyCoins + streakCoins;

    return RunReward(
      baseCoins: base,
      popCoins: popCoins,
      worldCoins: worldCoins,
      accuracyCoins: accuracyCoins,
      streakCoins: streakCoins,
    );
  }

  Future<void> creditRunCoins(RunSummary summary) async {
    final reward = calculateRunReward(summary);
    _lastRunReward = reward;

    if (_creditedRunId != summary.runId) {
      _creditedRunId = summary.runId;
      _creditedRunTotal = 0;
    }

    final deltaCoins = reward.totalCoins - _creditedRunTotal;
    _lastCreditedRunCoins = deltaCoins > 0 ? deltaCoins : 0;
    if (deltaCoins <= 0) return;

    // Update before awaiting persistence so rapid repeated calls cannot
    // credit the same reward delta more than once.
    _creditedRunTotal = reward.totalCoins;
    await wallet.addCoins(deltaCoins);
  }
}
