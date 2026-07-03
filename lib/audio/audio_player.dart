import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  static bool _muted = false;

  static DateTime? _lastPopSoundAt;
  static const Duration _minPopSoundGap = Duration(milliseconds: 40);
  static final AssetSource _popSource = AssetSource('audio/pop_mid.wav');

  static bool get muted => _muted;

  static String get diagnosticSummary =>
      'muted=$_muted popPool=$_popPoolSize popGapMs=${_minPopSoundGap.inMilliseconds}';

  static void setMuted(bool value) {
    _muted = value;
  }

  static final AudioContext _gameAudioContext = AudioContext(
    android: AudioContextAndroid(
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  // ============================================================
  // PLAYER POOLS
  // ============================================================

  static const int _popPoolSize = 4;
  static const int _coinPoolSize = 4;

  static final List<AudioPlayer> _popPlayers = List.generate(
    _popPoolSize,
    (_) => AudioPlayer()..setAudioContext(_gameAudioContext),
  );

  static final List<AudioPlayer> _coinPlayers = List.generate(
    _coinPoolSize,
    (_) => AudioPlayer()..setAudioContext(_gameAudioContext),
  );

  static int _popIndex = 0;
  static int _coinIndex = 0;

  static final AudioPlayer _surgePlayer =
      AudioPlayer()..setAudioContext(_gameAudioContext);

  static final AudioPlayer _milestonePlayer =
      AudioPlayer()..setAudioContext(_gameAudioContext);

  static final AudioPlayer _shieldPlayer =
      AudioPlayer()..setAudioContext(_gameAudioContext);

  // ============================================================
  // POP (CRITICAL — NON-BLOCKING)
  // ============================================================

  static void playPop() {
    if (_muted) return;

    final now = DateTime.now();
    final lastPopSoundAt = _lastPopSoundAt;

    if (lastPopSoundAt != null &&
        now.difference(lastPopSoundAt) < _minPopSoundGap) {
      return;
    }

    _lastPopSoundAt = now;

    try {
      final player = _popPlayers[_popIndex];
      _popIndex = (_popIndex + 1) % _popPoolSize;

      // Fire and forget, but intentionally throttled.
      // Background media playback can make rapid overlapping pop sounds hitch.
      player.play(
        _popSource,
        volume: 0.66,
      );
    } catch (_) {}
  }

  // ============================================================
  // COIN
  // ============================================================

  static void playCoin() {
    if (_muted) return;

    try {
      final player = _coinPlayers[_coinIndex];
      _coinIndex = (_coinIndex + 1) % _coinPoolSize;

      player.play(
       
 AssetSource('audio/coin.wav'),
        volume: 0.9,
      );
    } catch (_) {}
  }

  static void playCoinRamp(int amount) {
    final steps = (amount / 20).clamp(3, 6).round();

    for (int i = 0; i < steps; i++) {
      Future.delayed(Duration(milliseconds: 80 * i), () {
        playCoin();
      });
    }
  }

  // ============================================================
  // SURGE
  // ============================================================

  static void playSurge() {
    if (_muted) return;

    try {
      _surgePlayer.stop(); // non-awaited
      _surgePlayer.play(
        AssetSource('audio/surge.wav'),
        volume: 1.0,
      );
    } catch (_) {}
  }

  // ============================================================
  // MILESTONE
  // ============================================================

  static void playStreakMilestone(int milestoneIndex) {
    if (_muted) return;

    String? asset;

    switch (milestoneIndex) {
      case 1:
        asset = 'audio/milestone_10.mp3';
        break;
      case 2:
        asset = 'audio/milestone_20.mp3';
        break;
      case 3:
        asset = 'audio/milestone_30.mp3';
        break;
      default:
        return;
    }

    try {
      _milestonePlayer.stop();
      _milestonePlayer.play(
        AssetSource(asset),
        volume: 1.0,
      );
    } catch (_) {}
  }

  // ============================================================
  // SHIELD
  // ============================================================

  static void playShieldBreak() {
    if (_muted) return;

    try {
      _shieldPlayer.stop();
      _shieldPlayer.play(
        AssetSource('audio/milestone_30.mp3'),
        volume: 0.9,
      );
    } catch (_) {}
  }
}
