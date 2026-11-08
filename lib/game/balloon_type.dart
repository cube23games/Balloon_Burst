enum BalloonType {
  standard,
  smallFast,
  largeSlow,
  lead,
}

class BalloonTypeConfig {
  final double visualScale;
  final double speedMultiplier;
  final double hitRadiusMultiplier;
  final int zLayer;
  final double spawnWeight;

  const BalloonTypeConfig({
    required this.visualScale,
    required this.speedMultiplier,
    required this.hitRadiusMultiplier,
    required this.zLayer,
    required this.spawnWeight,
  });
}

const Map<BalloonType, BalloonTypeConfig> balloonTypeConfig = {
  BalloonType.standard: BalloonTypeConfig(
    visualScale: 1.0,
    speedMultiplier: 1.0,
    hitRadiusMultiplier: 1.0,
    zLayer: 1,
    spawnWeight: 1.0,
  ),

  BalloonType.smallFast: BalloonTypeConfig(
    visualScale: 0.75,
    speedMultiplier: 1.35,
    hitRadiusMultiplier: 0.9,
    zLayer: 0,
    spawnWeight: 0.35,
  ),

  BalloonType.lead: BalloonTypeConfig(
    visualScale: 1.35,
    speedMultiplier: 0.82,
    hitRadiusMultiplier: 1.3,
    zLayer: 3,
    spawnWeight: 0.0, // World 1 lead scheduler spawns these explicitly.
  ),

  BalloonType.largeSlow: BalloonTypeConfig(
    visualScale: 1.3,
    speedMultiplier: 0.75,
    hitRadiusMultiplier: 1.25,
    zLayer: 2,
    spawnWeight: 0.4,
  ),
};
