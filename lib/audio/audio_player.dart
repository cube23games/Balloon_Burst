import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioPlayerService {
  static bool _muted = false;

  static DateTime? _lastPopSoundAt;
  static const Duration _minPopSoundGap = Duration(milliseconds: 70);
  static final List<AssetSource> _popSources = [
    AssetSource('audio/pop_low.wav'),
    AssetSource('audio/pop_mid.wav'),
    AssetSource('audio/pop_high.wav'),
  ];
  static const double _popVolume = 0.66;

  static const MethodChannel _nativeAudioChannel =
      MethodChannel('com.cube23.balloonburst/audio');
  // Native SoundPool was tested in TJ-42M/TJ-42N, but on target hardware the
  // MethodChannel/native play path caused a visible freeze on nearly every pop.
  // Keep the native code dormant for now and use the lightweight Dart fallback.
  static bool _nativePopAvailable = false;
  static int _popVariantIndex = 0;

  static bool get muted => _muted;

  static String get diagnosticSummary =>
      'muted=$_muted popPool=$_popPoolSize popVariants=${_popSources.length} popGapMs=${_minPopSoundGap.inMilliseconds} popVolume=$_popVolume nativePop=$_nativePopAvailable';

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

    if (_nativePopAvailable) {
      try {
        _nativeAudioChannel
            .invokeMethod<bool>('playPop', <String, Object>{
              'volume': _popVolume,
            })
            .then<void>((played) {
              if (played != true) {
                _playPopWithAudioPlayer();
              }
            })
            .catchError((_) {
              _nativePopAvailable = false;
              _playPopWithAudioPlayer();
            });
        return;
      } catch (_) {
        _nativePopAvailable = false;
      }
    }

    _playPopWithAudioPlayer();
  }

  static void _playPopWithAudioPlayer() {
    try {
      final player = _popPlayers[_popIndex];
      final source = _popSources[_popVariantIndex];

      _popIndex = (_popIndex + 1) % _popPoolSize;
      _popVariantIndex = (_popVariantIndex + 1) % _popSources.length;

      // Fallback path. Native Android SoundPool is preferred for rapid pops.
      player.play(
        source,
        volume: _popVolume,
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
