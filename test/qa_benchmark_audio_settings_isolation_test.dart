import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:balloon_burst/tj_engine/engine/audio/audio_settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'tj_audio_muted_v1';

  AudioSettingsManager isolated() =>
      AudioSettingsManager(persistenceEnabled: false);

  Future<void> expectStorage(Map<String, Object> expected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, expected);
  }

  for (final savedMute in [true, false]) {
    test('isolated settings preserve saved mute=$savedMute', () async {
      final saved = <String, Object>{
        key: savedMute,
        'tj_wallet_balance_v1': 4720,
      };
      SharedPreferences.setMockInitialValues(saved);
      final audio = isolated();
      await audio.load();
      expect(audio.muted, isFalse);
      await expectStorage(saved);
      await audio.setMuted(true);
      expect(audio.muted, isTrue);
      await expectStorage(saved);
      await audio.load();
      expect(audio.muted, isTrue);
      await audio.setMuted(false);
      expect(audio.muted, isFalse);
      await expectStorage(saved);
      final normal = AudioSettingsManager();
      await normal.load();
      expect(normal.muted, savedMute);
    });
  }

  test('repeated isolated toggles return correct state without writes', () async {
    final saved = <String, Object>{key: true};
    SharedPreferences.setMockInitialValues(saved);
    final audio = isolated();
    await audio.load();
    for (final expected in [true, false, true, false, true]) {
      expect(await audio.toggleMuted(), expected);
      expect(audio.muted, expected);
      await expectStorage(saved);
    }
  });

  test('isolated instances maintain independent settings', () async {
    final saved = <String, Object>{key: true};
    SharedPreferences.setMockInitialValues(saved);
    final first = isolated();
    final second = isolated();
    await first.load();
    await second.load();
    await first.setMuted(true);
    expect(first.muted, isTrue);
    expect(second.muted, isFalse);
    await second.toggleMuted();
    await first.toggleMuted();
    expect(first.muted, isFalse);
    expect(second.muted, isTrue);
    await expectStorage(saved);
  });

  test('isolated operations never create absent persistent keys', () async {
    SharedPreferences.setMockInitialValues({});
    final audio = isolated();
    await audio.load();
    await audio.setMuted(true);
    await expectStorage({});
    await audio.toggleMuted();
    await expectStorage({});
  });

  test('default manager persists settings across instances', () async {
    SharedPreferences.setMockInitialValues({'tj_wallet_balance_v1': 4720});
    final audio = AudioSettingsManager();
    await audio.load();
    expect(audio.muted, isFalse);
    await audio.setMuted(true);
    await expectStorage({key: true, 'tj_wallet_balance_v1': 4720});
    final reloaded = AudioSettingsManager();
    await reloaded.load();
    expect(reloaded.muted, isTrue);
    expect(await reloaded.toggleMuted(), isFalse);
    await expectStorage({key: false, 'tj_wallet_balance_v1': 4720});
    final finalAudio = AudioSettingsManager();
    await finalAudio.load();
    expect(finalAudio.muted, isFalse);
  });
}
