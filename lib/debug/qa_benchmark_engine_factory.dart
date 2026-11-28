import '../tj_engine/engine/audio/audio_settings_manager.dart';
import '../tj_engine/engine/core/difficulty_manager.dart';
import '../tj_engine/engine/daily/daily_reward_manager.dart';
import '../tj_engine/engine/leaderboard/leaderboard_manager.dart';
import '../tj_engine/engine/run/run_lifecycle_manager.dart';
import '../tj_engine/engine/shield/shield_manager.dart';
import '../tj_engine/engine/tj_engine.dart';
import '../tj_engine/engine/wallet/wallet_manager.dart';
import '../tj_engine/juice/juice_manager.dart';

/// Constructs a fresh, disposable engine for controlled QA workloads.
///
/// Never accepts existing player managers. All five persistent subsystems
/// are explicitly configured to avoid persistent reads and writes.
/// Navigation, QA build gating and global audio lifecycle are handled
/// separately; constructing this engine does not activate benchmark mode.
class QaBenchmarkEngineFactory {
  QaBenchmarkEngineFactory._();

  static TJEngine create() {
    final shield = ShieldManager(persistenceEnabled: false);

    return TJEngine(
      shieldManager: shield,
      runLifecycleManager: RunLifecycleManager(shield: shield),
      difficulty: DifficultyManager(),
      dailyReward: DailyRewardManager(persistenceEnabled: false),
      leaderboard: LeaderboardManager(persistenceEnabled: false),
      audio: AudioSettingsManager(persistenceEnabled: false),
      wallet: WalletManager(persistenceEnabled: false),
      juice: JuiceManager(),
    );
  }
}
