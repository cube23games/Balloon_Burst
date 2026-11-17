/// QA-only fixed-memory summary of Flutter UI and raster frame durations.
///
/// Uses Flutter FrameTiming.buildDuration and rasterDuration. These are not the
/// same as game ticker callback gaps, and callbacks may contain batched frames.
class FlutterFrameTimingStats {
  /// Fixed 60 Hz comparison budget for the Moto G 2026 QA baseline.
  static const int frameBudgetMicros = 16667;

  int samples = 0;
  int buildOverBudget = 0;
  int rasterOverBudget = 0;
  int bothOverBudget = 0;

  int _sumBuildMicros = 0;
  int _sumRasterMicros = 0;
  int worstBuildMicros = 0;
  int worstRasterMicros = 0;

  void record({
    required Duration buildDuration,
    required Duration rasterDuration,
  }) {
    final buildUs = buildDuration.inMicroseconds;
    final rasterUs = rasterDuration.inMicroseconds;
    if (buildUs < 0 || rasterUs < 0) return;

    samples++;
    _sumBuildMicros += buildUs;
    _sumRasterMicros += rasterUs;
    if (buildUs > worstBuildMicros) worstBuildMicros = buildUs;
    if (rasterUs > worstRasterMicros) worstRasterMicros = rasterUs;

    final slowBuild = buildUs > frameBudgetMicros;
    final slowRaster = rasterUs > frameBudgetMicros;
    if (slowBuild) buildOverBudget++;
    if (slowRaster) rasterOverBudget++;
    if (slowBuild && slowRaster) bothOverBudget++;
  }

  double get averageBuildMs =>
      samples == 0 ? 0.0 : _sumBuildMicros / (1000.0 * samples);
  double get averageRasterMs =>
      samples == 0 ? 0.0 : _sumRasterMicros / (1000.0 * samples);

  void reset() {
    samples = 0;
    buildOverBudget = 0;
    rasterOverBudget = 0;
    bothOverBudget = 0;
    _sumBuildMicros = 0;
    _sumRasterMicros = 0;
    worstBuildMicros = 0;
    worstRasterMicros = 0;
  }

  /// String generation happens only when a QA report is exported.
  String get reportFields => [
        'qaFlutterTimingSampleCount: $samples',
        'qaFlutterTimingFrameBudgetMs: 16.7',
        'qaFlutterTimingBuildOverBudgetCount: $buildOverBudget',
        'qaFlutterTimingRasterOverBudgetCount: $rasterOverBudget',
        'qaFlutterTimingBothOverBudgetCount: $bothOverBudget',
        'qaFlutterTimingAverageBuildMs: ${averageBuildMs.toStringAsFixed(2)}',
        'qaFlutterTimingAverageRasterMs: ${averageRasterMs.toStringAsFixed(2)}',
        'qaFlutterTimingWorstBuildMs: ${(worstBuildMicros / 1000.0).toStringAsFixed(1)}',
        'qaFlutterTimingWorstRasterMs: ${(worstRasterMicros / 1000.0).toStringAsFixed(1)}',
      ].join('\n');
}
