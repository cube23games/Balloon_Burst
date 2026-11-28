import 'package:shared_preferences/shared_preferences.dart';

import 'models/daily_reward_model.dart';
import 'models/daily_reward_status.dart';
import 'now_provider.dart';

/// ===============================================================
/// SYSTEM: DailyRewardManager
/// ===============================================================
///
/// ENGINE-OWNED.
/// No UI logic.
/// "Pure Dart-ish" (uses SharedPreferences like LeaderboardManager).
///
/// RULE:
/// Reward available every 24 hours from last claim.
/// Not midnight reset.
/// ===============================================================
class DailyRewardManager {
  static const Duration claimInterval = Duration(hours: 24);

  // Storage key (versioned)
  static const String _storageKeyLastClaim = 'tj_daily_last_claim_iso_v1';

  final NowProvider _clock;
  final bool persistenceEnabled;

  DateTime? _lastClaimTime;

  DailyRewardManager({NowProvider? clock, this.persistenceEnabled = true})
      : _clock = clock ?? SystemNowProvider();

  /// ============================================================
  /// Load persisted state (call once at app start).
  /// ============================================================
  Future<void> load() async {
    if (!persistenceEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(_storageKeyLastClaim);
      if (iso == null || iso.trim().isEmpty) {
        _lastClaimTime = null;
        return;
      }

      final parsed = DateTime.tryParse(iso);
      _lastClaimTime = parsed?.toUtc();
    } catch (_) {
      // Never block gameplay/UI due to storage.
      _lastClaimTime = null;
    }
  }

  /// ============================================================
  /// Persist current state.
  /// ============================================================
  Future<void> save() async => _persist();

  /// ============================================================
  /// Persist current state (internal).
  /// ============================================================
  Future<void> _persist() async {
    if (!persistenceEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = _lastClaimTime?.toUtc().toIso8601String();
      if (value == null) {
        await prefs.remove(_storageKeyLastClaim);
      } else {
        await prefs.setString(_storageKeyLastClaim, value);
      }
    } catch (_) {
      // Fail silently.
    }
  }

  /// ============================================================
  /// Get current reward status snapshot.
  /// ============================================================
  DailyRewardStatus getStatus({
    required int currentWorldLevel,
  }) {
    final now = _clock.now().toUtc();

    final lastClaim = _lastClaimTime;
    bool isAvailable;
    Duration remaining;

    if (lastClaim == null) {
      isAvailable = true;
      remaining = Duration.zero;
    } else {
      final nextEligible = lastClaim.add(claimInterval);
      if (now.isAfter(nextEligible) || now.isAtSameMomentAs(nextEligible)) {
        isAvailable = true;
        remaining = Duration.zero;
      } else {
        isAvailable = false;
        remaining = nextEligible.difference(now);
      }
    }

    final reward = _computeReward(currentWorldLevel);

    return DailyRewardStatus(
      isAvailable: isAvailable,
      timeRemaining: remaining,
      currentWorldLevel: currentWorldLevel,
      computedReward: reward,
    );
  }

  /// ============================================================
  /// Claim reward (if eligible).
  /// Returns reward or null if not available.
  ///
  /// NOTE:
  /// This persists asynchronously (fire-and-forget).
  /// For bulletproof persistence, use claimAndSave().
  /// ============================================================
  DailyRewardModel? claim({
    required int currentWorldLevel,
  }) {
    final status = getStatus(currentWorldLevel: currentWorldLevel);
    if (!status.isAvailable) return null;

    _lastClaimTime = _clock.now().toUtc();

    // Persist asynchronously; do not block UI.
    _persist();

    return status.computedReward;
  }

  /// ============================================================
  /// Claim reward AND persist synchronously (bulletproof).
  /// Returns reward or null if not available.
  /// ============================================================
  Future<DailyRewardModel?> claimAndSave({
    required int currentWorldLevel,
  }) async {
    final status = getStatus(currentWorldLevel: currentWorldLevel);
    if (!status.isAvailable) return null;

    _lastClaimTime = _clock.now().toUtc();
    await _persist();

    return status.computedReward;
  }

  /// ============================================================
  /// Reward scaling logic.
  /// Engine-owned economic tuning lives here.
  /// ============================================================
  DailyRewardModel _computeReward(int worldLevel) {
    const int baseCoins = 100;
    const int coinsPerWorld = 25;
    const int bonusPointsPerWorld = 5;

    final scaledCoins = baseCoins + (worldLevel * coinsPerWorld);
    final scaledBonus = worldLevel * bonusPointsPerWorld;

    return DailyRewardModel(
      coins: scaledCoins,
      bonusPoints: scaledBonus,
    );
  }
}
