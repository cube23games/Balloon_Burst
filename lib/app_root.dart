import 'package:flutter/material.dart';

import 'package:balloon_burst/debug/debug_controller.dart';
import 'package:balloon_burst/game/balloon_spawner.dart';
import 'package:balloon_burst/game/game_state.dart';
import 'package:balloon_burst/screens/debug_screen.dart';
import 'package:balloon_burst/screens/game_screen.dart';
import 'package:balloon_burst/tj_engine/engine/tj_engine.dart';
import 'package:balloon_burst/skyward/world_one.dart';

class AppRoot extends StatefulWidget {
  final TJEngine engine;
  final SkywardLevelRun? skywardRun;
  final ValueChanged<SkywardLevelRun>? onSkywardCompleted;
  final VoidCallback? onSkywardExit;
  final VoidCallback? onSkywardNext;

  const AppRoot({
    super.key,
    required this.engine,
    this.skywardRun,
    this.onSkywardCompleted,
    this.onSkywardExit,
    this.onSkywardNext,
  });

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final GameState _gameState = GameState();
  final BalloonSpawner _spawner = BalloonSpawner();
  final DebugController _debug = DebugController();

  void _openDebug() {
    setState(() {
      _gameState.screenMode = ScreenMode.debug;
    });
  }

  void _closeDebug() {
    setState(() {
      _gameState.screenMode = ScreenMode.game;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showDebug = _gameState.screenMode == ScreenMode.debug;

    return Stack(
      children: [
        GameScreen(
          gameState: _gameState,
          spawner: _spawner,
          engine: widget.engine,
          onRequestDebug: _openDebug,
          skywardRun: widget.skywardRun,
          onSkywardCompleted: widget.onSkywardCompleted,
          onSkywardExit: widget.onSkywardExit,
          onSkywardNext: widget.onSkywardNext,
        ),
        if (showDebug)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: DebugScreen(
                gameState: _gameState,
                spawner: _spawner,
                debug: _debug,
                onClose: _closeDebug,
              ),
            ),
          ),
      ],
    );
  }
}
