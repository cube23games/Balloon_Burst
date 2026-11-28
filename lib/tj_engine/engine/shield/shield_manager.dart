// lib/tj_engine/engine/shield/shield_manager.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../run/run_lifecycle_manager.dart';

class ShieldManager implements ShieldAccess {
  static const String _pendingKey = 'tj_shield_pending_v1';
  static const String _activeKey = 'tj_shield_active_v1';

  ShieldManager({this.persistenceEnabled = true});

  final bool persistenceEnabled;

  bool _pending = false;
  bool _active = false;

  @override
  bool get isPending => _pending;

  @override
  bool get isActive => _active;

  Future<void> load() async {
    if (!persistenceEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _pending = prefs.getBool(_pendingKey) ?? false;
      _active = prefs.getBool(_activeKey) ?? false;
    } catch (_) {
      _pending = false;
      _active = false;
    }
  }

  Future<void> _persist() async {
    if (!persistenceEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKey, _pending);
      await prefs.setBool(_activeKey, _active);
    } catch (_) {}
  }

  @override
  Future<void> armForNextRun() async {
    _pending = true;
    await _persist();
  }

  @override
  Future<void> activateIfPending() async {
    if (!_pending) return;
    _active = true;
    _pending = false;
    await _persist();
  }

  @override
  Future<void> consume() async {
    if (!_active) return;
    _active = false;
    await _persist();
  }
}
