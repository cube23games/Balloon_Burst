import 'dart:math';

import 'package:balloon_burst/game/balloon_type.dart';
import 'package:balloon_burst/game/game_state.dart';
import 'package:balloon_burst/gameplay/balloon.dart';

class BalloonSpawner {
  double _timer = 0.0;
  int _spawnCount = 0;
  final Random _rng = Random();

  double spawnInterval = 1.2;

  int totalPops = 0;
  int recentMisses = 0;
  int recentHits = 0;

  int _lastLoggedWorld = 1;
  double _lastClusterCenterX = 0.0;

  // Read-only difficulty telemetry. These values mirror the
  // existing movement and spawn calculations.
  double _lastBaseRiseSpeed = 0.0;
  double _lastEngineSpeedMultiplier = 1.0;
  double _lastAdaptiveEngineSpawnInterval = 1.2;
  double _lastAdaptiveSpawnFactor = 1.0;
  double _lastTargetSpawnInterval = 1.2;
  double _lastSampledSpawnThreshold = 1.2;
  double _lastEngineElapsedSeconds = 0.0;
  int _lastSpawnBatch = 0;

  final Duration mercyWindow = const Duration(milliseconds: 120);

  static const int world2Pops = 50;
  static const int world3Pops = 150;
  static const int world4Pops = 350;

  static const Map<int, double> worldSpeedMultiplier = {
    1: 1.00,
    2: 1.25,
    3: 1.55,
    4: 1.68,
  };

  static const Map<int, double> worldSpawnInterval = {
    1: 1.20,
    2: 1.00,
    3: 0.85,
    4: 0.92,
  };

  static const double maxWorldRamp = 0.10;
  static const double maxMissSlowdown = 0.05;

  // Vertical stacking on entry
  static const double burstSpacingY = 26.0;
  static const double spawnEntryPaddingY = 64.0;

  // Cluster feel — intentionally aggressive for stronger left/right scan pressure.
  static const double clusterSpread = 0.21;
  static const double clusterJitter = 0.07;

  // Horizontal spawn range by world
  static const double clusterOriginRangeWorld1 = 0.66;
  static const double clusterOriginRangeWorld2 = 0.82;
  static const double clusterOriginRangeWorld3 = 0.96;
  static const double clusterOriginRangeWorld4 = 0.86;

  static const double xClamp = 0.92;

  // Anti-rhythm overlap guard:
  // allow overlap, but don't let the screen become spammy.
  static const Map<int, int> overlapSpawnThreshold = {
    1: 1,
    2: 2,
    3: 2,
    4: 2,
  };

  void update({
    required double dt,
    required int tier,
    required List<Balloon> balloons,
    required double viewportHeight,
    required double engineSpawnInterval,
      required double engineSpeedMultiplier,
      required double adaptiveSpawnFactor,
      required double engineElapsedSeconds,
      required double baseRiseSpeed,
    required int engineMaxSimultaneousSpawns,
  }) {
      _lastBaseRiseSpeed = baseRiseSpeed;
      _lastEngineSpeedMultiplier = engineSpeedMultiplier;
      _lastAdaptiveEngineSpawnInterval = engineSpawnInterval;
      _lastAdaptiveSpawnFactor = adaptiveSpawnFactor;
      _lastEngineElapsedSeconds = engineElapsedSeconds;

    final int activeCount = balloons.where((b) => !b.isPopped).length;
    final int remainingCapacity =
        (engineMaxSimultaneousSpawns - activeCount).clamp(0, 9999);

    if (remainingCapacity <= 0) return;

    final int overlapGuard = overlapSpawnThreshold[currentWorld] ?? 2;
    if (activeCount > overlapGuard) return;

    final double worldInterval =
        worldSpawnInterval[currentWorld] ?? spawnInterval;

    final double engineMultiplier = engineSpawnInterval / 1.2;
    final double targetInterval = worldInterval * engineMultiplier;
      _lastTargetSpawnInterval = targetInterval;

    spawnInterval += (targetInterval - spawnInterval) * 0.05;

    _timer += dt;
      final sampledThreshold = _nextSpawnThreshold();
      _lastSampledSpawnThreshold = sampledThreshold;

      if (_timer < sampledThreshold) return;
    _timer = 0.0;

    final int desiredCount = _pickGroupSizeForWorld(currentWorld);
    final int count = min(desiredCount, remainingCapacity);

    if (count <= 0) return;
      _lastSpawnBatch = count;

    final List<BalloonType> types = _chooseTypesForGroup(count);

    final double clusterCenterX = _pickClusterOrigin(
      _clusterOriginRangeForWorld(currentWorld),
    );
    _lastClusterCenterX = clusterCenterX;

    final List<double> xOffsets = _xOffsetsForCount(count);

    for (int i = 0; i < count; i++) {
      final int index = _spawnCount++;

      final double spawnY =
          viewportHeight + spawnEntryPaddingY + burstSpacingY * (count - 1 - i);

      final double jitter = (_rng.nextDouble() * 2 - 1) * clusterJitter;

      final double x =
          (clusterCenterX + xOffsets[i] + jitter).clamp(-xClamp, xClamp);

      final Balloon b = Balloon(
        id: 'balloon_$index',
        y: spawnY,
        xOffset: x,
        baseXOffset: x,
        phase: _rng.nextDouble() * pi * 2,
        type: types[i],
      );

      balloons.add(b);
    }
  }

  double _nextSpawnThreshold() {
    final variance = switch (currentWorld) {
      1 => 0.06,
      2 => 0.10,
      3 => 0.14,
      4 => 0.18,
      _ => 0.10,
    };

    final factor = 1.0 + ((_rng.nextDouble() * 2 - 1) * variance);
    final minThreshold = currentWorld >= 4
        ? 0.60
        : currentWorld >= 3
            ? 0.48
            : 0.45;

    return (spawnInterval * factor).clamp(minThreshold, 1.6);
  }

  int _pickGroupSizeForWorld(int world) {
    final roll = _rng.nextDouble();

    switch (world) {
      case 1:
        // Slow world: bigger clusters are readable and satisfying.
        if (roll < 0.14) return 1;
        if (roll < 0.54) return 2;
        if (roll < 0.92) return 3;
        return 4;

      case 2:
        if (roll < 0.14) return 1;
        if (roll < 0.56) return 2;
        if (roll < 0.90) return 3;
        return 4;

      case 3:
        // Pressure world: no 5-clusters, rare 4-clusters.
        if (roll < 0.12) return 1;
        if (roll < 0.52) return 2;
        if (roll < 0.90) return 3;
        return 4;

      case 4:
        // Fast world: readability beats cluster size.
        if (roll < 0.30) return 1;
        if (roll < 0.82) return 2;
        return 3;

      default:
        return 2;
    }
  }

  double _clusterOriginRangeForWorld(int world) {
    switch (world) {
      case 2:
        return clusterOriginRangeWorld2;
      case 3:
        return clusterOriginRangeWorld3;
      case 4:
        return clusterOriginRangeWorld4;
      default:
        return clusterOriginRangeWorld1;
    }
  }

  double _pickClusterOrigin(double range) {
    // World 1 stays more natural/readable.
    if (currentWorld <= 1) {
      final t = _rng.nextDouble();
      final biased = pow(t, 0.68).toDouble();
      final sign = _rng.nextBool() ? 1.0 : -1.0;
      return biased * range * sign;
    }

    // World 2 begins waking the player up, but is still not too aggressive.
    if (currentWorld == 2) {
      final t = _rng.nextDouble();
      final biased = pow(t, 0.58).toDouble();
      final sign = _rng.nextBool() ? 1.0 : -1.0;
      return biased * range * sign;
    }

    // Worlds 3+ bias toward the opposite side of the last cluster.
    final double preferredSign = _lastClusterCenterX >= 0 ? -1.0 : 1.0;
    final bool forceOpposite = _rng.nextDouble() < (currentWorld >= 4 ? 0.58 : 0.72);
    final double sign = forceOpposite
        ? preferredSign
        : (_rng.nextBool() ? 1.0 : -1.0);

    // Bias farther outward so the switch is felt, not just technically different.
    final t = _rng.nextDouble();
    final exponent = currentWorld >= 4 ? 0.58 : 0.44;
    final biased = pow(t, exponent).toDouble();

    // Keep a minimum outward push in later worlds.
    final outwardFloor = currentWorld >= 4 ? 0.24 : 0.32;
    final strength = outwardFloor + ((1.0 - outwardFloor) * biased);

    return strength * range * sign;
  }

  List<double> _xOffsetsForCount(int count) {
    if (count <= 1) return const [0.0];

    final double mid = (count - 1) / 2.0;
    final List<double> out = [];

    for (int i = 0; i < count; i++) {
      final base = (i - mid) * clusterSpread;
      final asymmetry = (_rng.nextDouble() * 2 - 1) *
          (currentWorld >= 4
              ? 0.045
              : currentWorld >= 3
                  ? 0.075
                  : currentWorld >= 2
                      ? 0.050
                      : 0.028);
      out.add(base + asymmetry);
    }

    out.shuffle(_rng);
    return out;
  }

  List<BalloonType> _chooseTypesForGroup(int count) {
    if (count <= 1) {
      return [_chooseBalloonType()];
    }

    final List<BalloonType> out = List.filled(count, BalloonType.standard);
    out[0] = BalloonType.standard;

    bool hasLargeSlow = false;

    for (int i = 1; i < count; i++) {
      final BalloonType t = _chooseBalloonType();

      if (t == BalloonType.largeSlow) {
        if (hasLargeSlow) {
          out[i] = BalloonType.standard;
        } else {
          out[i] = BalloonType.largeSlow;
          hasLargeSlow = true;
        }
      } else {
        out[i] = t;
      }
    }

    out.shuffle(_rng);
    return out;
  }

  BalloonType _chooseBalloonType() {
    final entries = balloonTypeConfig.entries.toList();
    final totalWeight =
        entries.fold<double>(0, (s, e) => s + e.value.spawnWeight);

    double roll = _rng.nextDouble() * totalWeight;

    for (final e in entries) {
      roll -= e.value.spawnWeight;
      if (roll <= 0) return e.key;
    }

    return BalloonType.standard;
  }

  void registerPop(GameState gameState) {
    totalPops++;
    recentHits++;
    recentMisses = max(0, recentMisses - 1);

    final w = currentWorld;
    if (w != _lastLoggedWorld) {
      gameState.log('WORLD CHANGE $_lastLoggedWorld → $w at pops=$totalPops');
      gameState.log('BG COLOR → ${_worldName(w)}');
      _lastLoggedWorld = w;
    }
  }

  void registerMiss(GameState gameState) {
    recentMisses++;
    recentHits = max(0, recentHits - 1);
  }

  int get currentWorld {
    if (totalPops >= world4Pops) return 4;
    if (totalPops >= world3Pops) return 3;
    if (totalPops >= world2Pops) return 2;
    return 1;
  }

  double get worldProgress {
    int start;
    int end;

    switch (currentWorld) {
      case 2:
        start = world2Pops;
        end = world3Pops;
        break;
      case 3:
        start = world3Pops;
        end = world4Pops;
        break;
      case 4:
        start = world4Pops;
        end = world4Pops + 200;
        break;
      default:
        start = 0;
        end = world2Pops;
    }

    return ((totalPops - start) / (end - start)).clamp(0.0, 1.0);
  }

  double get accuracyModifier {
    if (recentMisses == 0) return 1.0;

    final missFactor =
        (recentMisses / (recentMisses + recentHits + 1)).clamp(0.0, 1.0);

    final slowdown = missFactor * maxMissSlowdown;
    return (1.0 - slowdown).clamp(1.0 - maxMissSlowdown, 1.0);
  }

  double get speedMultiplier {
    final worldMult = worldSpeedMultiplier[currentWorld] ?? 1.0;
    final ramp = 1.0 + (worldProgress * maxWorldRamp);
    return worldMult * ramp * accuracyModifier;
  }

  double get worldSpeedBaseMultiplier =>
      worldSpeedMultiplier[currentWorld] ?? 1.0;

  double get worldRampMultiplier =>
      1.0 + (worldProgress * maxWorldRamp);

  double get engineSpeedMultiplier =>
      _lastEngineSpeedMultiplier;

  double get combinedSpeedMultiplier =>
      speedMultiplier * engineSpeedMultiplier;

  double get nominalRiseSpeed =>
      _lastBaseRiseSpeed * combinedSpeedMultiplier;

  double get minimumRiseSpeed =>
      nominalRiseSpeed * 0.92;

  double get maximumRiseSpeed =>
      nominalRiseSpeed * 1.08;

  double get worldSpawnTargetInterval =>
      worldSpawnInterval[currentWorld] ?? spawnInterval;

  double get adaptiveEngineSpawnInterval =>
      _lastAdaptiveEngineSpawnInterval;

  double get adaptiveSpawnFactor =>
      _lastAdaptiveSpawnFactor;

  double get targetSpawnInterval =>
      _lastTargetSpawnInterval;

  double get effectiveSpawnInterval =>
      _lastSampledSpawnThreshold;

  double get spawnFloor => currentWorld >= 4
      ? 0.60
      : currentWorld >= 3
          ? 0.48
          : 0.45;

  double get spawnVariance => switch (currentWorld) {
        1 => 0.06,
        2 => 0.10,
        3 => 0.14,
        4 => 0.18,
        _ => 0.10,
      };

  int get lastSpawnBatch => _lastSpawnBatch;

  double get engineElapsedSeconds =>
      _lastEngineElapsedSeconds;

  String _worldName(int w) {
    switch (w) {
      case 2:
        return 'Sky Blue';
      case 3:
        return 'Neon Purple';
      case 4:
        return 'Deep Space';
      default:
        return 'Dark Carnival';
    }
  }

  void resetForNewRun() {
    _timer = 0.0;
    _spawnCount = 0;
    spawnInterval = worldSpawnInterval[1]!;

    _lastBaseRiseSpeed = 0.0;
    _lastEngineSpeedMultiplier = 1.0;
    _lastAdaptiveEngineSpawnInterval = 1.2;
    _lastAdaptiveSpawnFactor = 1.0;
    _lastTargetSpawnInterval = 1.2;
    _lastSampledSpawnThreshold = 1.2;
    _lastEngineElapsedSeconds = 0.0;
    _lastSpawnBatch = 0;

    totalPops = 0;
    _lastLoggedWorld = 1;
    _lastClusterCenterX = 0.0;
    recentHits = 0;
    recentMisses = 0;
  }
}
