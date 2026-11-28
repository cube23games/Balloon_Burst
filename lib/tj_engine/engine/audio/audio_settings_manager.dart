// lib/tj_engine/engine/audio/audio_settings_manager.dart
//
// TapJunkie Engine System: AudioSettingsManager
// - Stores global audio preferences (mute) using SharedPreferences.
// - No Flutter imports.
// - Safe, minimal API for current architecture.

import 'package:shared_preferences/shared_preferences.dart';

class AudioSettingsManager {
  static const String _muteKey = 'tj_audio_muted_v1';

  AudioSettingsManager({this.persistenceEnabled = true});

  final bool persistenceEnabled;

  bool _muted = false;

  bool get muted => _muted;

  /// Load saved audio settings (call once at app start).
  Future<void> load() async {
    if (!persistenceEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_muteKey) ?? false;
  }

  /// Persist mute state.
  Future<void> setMuted(bool value) async {
    _muted = value;
    if (!persistenceEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, _muted);
  }

  /// Convenience toggle.
  Future<bool> toggleMuted() async {
    final next = !_muted;
    await setMuted(next);
    return _muted;
  }
}
