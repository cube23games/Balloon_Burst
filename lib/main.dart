import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/app_state.dart';
import 'screens/start_screen.dart';
import 'app_root.dart';

import 'package:balloon_burst/tj_engine/engine/tj_engine.dart';
import 'package:balloon_burst/audio/audio_player.dart';
import 'package:balloon_burst/skyward/world_one.dart';
import 'package:balloon_burst/skyward/skyward_select_screen.dart';

void main() {
  runApp(const BalloonBurstApp());
}

class BalloonBurstApp extends StatefulWidget {
  const BalloonBurstApp({super.key});

  @override
  State<BalloonBurstApp> createState() => _BalloonBurstAppState();
}

class _BalloonBurstAppState extends State<BalloonBurstApp> {
  static const _skywardStarsKey = 'skyward.world1.stars.v1';

  AppView _view = AppView.start;
  int _selectedSkywardLevel = 1;
  SkywardWorldOneProgress _skywardProgress = SkywardWorldOneProgress();

  late final TJEngine _engine;
  bool _engineReady = false;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    _engine = TJEngine();
    await _engine.loadAll();
    AudioPlayerService.setMuted(_engine.isMuted);

    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList(_skywardStarsKey) ?? <String>[];
    _skywardProgress = SkywardWorldOneProgress.fromSaved(
      saved.map((value) => int.tryParse(value) ?? 0).toList(),
    );

    if (!mounted) return;
    setState(() {
      _engineReady = true;
    });
  }

  Future<void> _saveSkywardProgress() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = _skywardProgress.bestStars.map((n) => n.toString()).toList();
    await preferences.setStringList(_skywardStarsKey, saved);
  }

  void _returnToMainMenu() {
    setState(() => _view = AppView.start);
  }

  void _startGame() {
    setState(() => _view = AppView.game);
  }

  void _showLevelMap() {
    setState(() => _view = AppView.skywardSelect);
  }

  void _selectSkywardLevel(int level) {
    // Later levels must not be playable before their hazards are implemented.
    if (level > SkywardSelectScreen.playableThrough ||
        !_skywardProgress.isLevelUnlocked(level)) {
      return;
    }
    setState(() {
      _selectedSkywardLevel = level;
      _view = AppView.skywardGame;
    });
  }

  void _completeSkywardLevel(SkywardLevelRun run) {
    if (!run.isComplete) return;
    _skywardProgress.submit(run); // Synchronous unlock for Next Level.
    unawaited(_saveSkywardProgress());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_engineReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: switch (_view) {
        AppView.start => StartScreen(
            onStart: _startGame,
            onSkyward: _showLevelMap,
            engine: _engine,
          ),
        AppView.game => AppRoot(
            key: const ValueKey('classic-arcade'),
            engine: _engine,
            onMainMenu: _returnToMainMenu,
          ),
        AppView.skywardSelect => SkywardSelectScreen(
            progress: _skywardProgress,
            onSelectLevel: _selectSkywardLevel,
            onBack: () => setState(() => _view = AppView.start),
          ),
        AppView.skywardGame => AppRoot(
            key: ValueKey('skyward-$_selectedSkywardLevel'),
            engine: _engine,
            onMainMenu: _returnToMainMenu,
            skywardRun: SkywardLevelRun(
              SkywardWorldOne.level(_selectedSkywardLevel),
            ),
            onSkywardCompleted: _completeSkywardLevel,
            onSkywardExit: _showLevelMap,
            onSkywardNext: _selectedSkywardLevel <
                    SkywardSelectScreen.playableThrough
                ? () => _selectSkywardLevel(_selectedSkywardLevel + 1)
                : null,
          ),
      },
    );
  }
}
