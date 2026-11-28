import 'package:shared_preferences/shared_preferences.dart';

/// ===============================================================
/// SYSTEM: WalletManager
/// ===============================================================
///
/// Engine-owned persistent coin balance.
/// No UI logic.
/// Safe async persistence.
/// Versioned storage key.
/// ===============================================================
class WalletManager {
  static const String _storageKey = 'tj_wallet_balance_v1';

  WalletManager({this.persistenceEnabled = true});

  final bool persistenceEnabled;

  int _balance = 0;

  int get balance => _balance;

  /// Load persisted balance.
  Future<void> load() async {
    if (!persistenceEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _balance = prefs.getInt(_storageKey) ?? 0;
    } catch (_) {
      _balance = 0;
    }
  }

  /// Persist current balance.
  Future<void> _persist() async {
    if (!persistenceEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storageKey, _balance);
    } catch (_) {
      // Never crash economy.
    }
  }

  /// Add coins to wallet.
  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    _balance += amount;
    await _persist();
  }

  /// Spend coins. Returns true if successful.
  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return false;
    if (_balance < amount) return false;

    _balance -= amount;
    await _persist();
    return true;
  }

  /// Reset wallet (debug only, not used in production flows).
  Future<void> reset() async {
    _balance = 0;
    await _persist();
  }
}
