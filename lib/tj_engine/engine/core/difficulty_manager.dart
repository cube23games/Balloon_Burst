/// Snapshot of the current difficulty settings. You can read these
/// in your game logic to scale speed, spawn rate, etc.
class DifficultySnapshot {
  final int level;
  final double spawnInterval;
  final double speedMultiplier;
  final int maxSimultaneousSpawns;

  const DifficultySnapshot({
    required this.level,
    required this.spawnInterval,
    required this.speedMultiplier,
    required this.maxSimultaneousSpawns,
  });
}

/// Time-based difficulty controller for TapJunkie games.
///
/// - Difficulty level increases over time
/// - Spawn interval goes down over time
/// - Speed multiplier & max spawns go up over time
class DifficultyManager {
  double _elapsed = 0;
  int _level = 1;

  double get elapsed => _elapsed;
  int get level => _level;

  DifficultySnapshot get snapshot => DifficultySnapshot(
        level: _level,
        spawnInterval: _currentSpawnInterval(),
        speedMultiplier: _currentSpeedMultiplier(),
        maxSimultaneousSpawns: _currentMaxSpawns(),
      );

  double get spawnInterval => snapshot.spawnInterval;
  double get speedMultiplier => snapshot.speedMultiplier;
  int get maxSimultaneousSpawns => snapshot.maxSimultaneousSpawns;

  /// Call this every frame from a game system (for example from a Spawner).
  void update(double dt) {
    _elapsed += dt;

    // Every ~20 seconds, bump difficulty up by 1, capped at 10.
    final newLevel = 1 + (_elapsed ~/ 20).toInt();
    if (newLevel != _level) {
      _level = newLevel.clamp(1, 10);
    }
  }

  void reset() {
    _elapsed = 0;
    _level = 1;
  }

  double _currentSpawnInterval() {
    // Start at 1.2s, go down as level increases, but never below 0.25s.
    final base = 1.2;
    final minInterval = 0.25;
    final reduced = base - (_level - 1) * 0.1;
    return reduced < minInterval ? minInterval : reduced;
  }

  double _currentSpeedMultiplier() {
    // Speed increases ~4% per level.
    return 1.0 + (_level - 1) * 0.04;
  }

  int _currentMaxSpawns() {
    // Start at 3 concurrent spawns, scale up slowly.
    return 3 + (_level ~/ 2);
  }
}
