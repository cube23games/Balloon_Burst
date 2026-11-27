import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';

/// Build-time gate: diagnostic counters never run in public release builds.
class FramePacingDiagnosticFlags {
  static const bool enabled = kEnableQaAutoTap &&
      bool.fromEnvironment('TJ45D_FRAME_DIAG', defaultValue: false);
}

/// Bounded QA-only wall-clock summary of the synchronous gameplay update.
///
/// This is measured inside the Flutter Ticker callback and EXCLUDES UI build,
/// raster and physical presentation. No per-frame logs or growing histories.
class GameUpdateTimingStats {
  static const int frameBudgetMicros = 16667;
  static const int severeBudgetMicros = 33333;

  int samples = 0;
  int overBudget = 0;
  int overSevereBudget = 0;
  int samplesAfterTickerHitch = 0;
  int overBudgetAfterTickerHitch = 0;
  int worstUpdateMicros = 0;
  int _sumUpdateMicros = 0;

  void record({
    required int durationMicros,
    required bool precedingTickerHitch,
  }) {
    if (durationMicros < 0) return;
    samples++;
    _sumUpdateMicros += durationMicros;
    if (durationMicros > worstUpdateMicros) worstUpdateMicros = durationMicros;
    if (durationMicros > frameBudgetMicros) overBudget++;
    if (durationMicros > severeBudgetMicros) overSevereBudget++;
    if (precedingTickerHitch) {
      samplesAfterTickerHitch++;
      if (durationMicros > frameBudgetMicros) overBudgetAfterTickerHitch++;
    }
  }

  double get averageUpdateMs =>
      samples == 0 ? 0.0 : _sumUpdateMicros / (1000.0 * samples);

  void reset() {
    samples = 0;
    overBudget = 0;
    overSevereBudget = 0;
    samplesAfterTickerHitch = 0;
    overBudgetAfterTickerHitch = 0;
    worstUpdateMicros = 0;
    _sumUpdateMicros = 0;
  }

  String get reportFields => [
        'qaFramePacingDiagnostic: enabled',
        'qaGameUpdateSampleCount: $samples',
        'qaGameUpdateFrameBudgetMs: 16.7',
        'qaGameUpdateOverBudgetCount: $overBudget',
        'qaGameUpdateOver33_3MsCount: $overSevereBudget',
        'qaGameUpdateSamplesAfterTickerHitch: $samplesAfterTickerHitch',
        'qaGameUpdateOverBudgetAfterTickerHitch: $overBudgetAfterTickerHitch',
        'qaGameUpdateAverageMs: ${averageUpdateMs.toStringAsFixed(2)}',
        'qaGameUpdateWorstMs: ${(worstUpdateMicros / 1000.0).toStringAsFixed(1)}',
      ].join('\n');
}
