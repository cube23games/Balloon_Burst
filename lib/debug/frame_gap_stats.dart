/// Small, allocation-free frame-gap sampler for QA debug reports.
///
/// This observes ticker callback intervals, not GPU/raster frame times.
/// It deliberately does not change gameplay timing or hitch policy.
class FrameGapStats {
  static const double hitchThresholdSeconds = 1.0 / 28.0;
  static const double firstSecondBoundary = 1.0;

  int samples = 0;
  int firstSecondHitches = 0;
  int laterHitches = 0;
  int atMost16_7Ms = 0;
  int over16_7To33_3Ms = 0;
  int over33_3To50Ms = 0;
  int over50Ms = 0;
  double worstGapMs = 0.0;

  int get totalHitches => firstSecondHitches + laterHitches;

  void record({
    required double rawDeltaSeconds,
    required double runSeconds,
  }) {
    // Ignore invalid input instead of polluting baseline measurements.
    if (!rawDeltaSeconds.isFinite ||
        rawDeltaSeconds <= 0 ||
        !runSeconds.isFinite ||
        runSeconds < 0) {
      return;
    }

    samples++;
    final gapMs = rawDeltaSeconds * 1000.0;
    if (gapMs > worstGapMs) worstGapMs = gapMs;

    if (gapMs <= 16.7) {
      atMost16_7Ms++;
    } else if (gapMs <= 1000.0 / 30.0) {
      over16_7To33_3Ms++;
    } else if (gapMs <= 50.0) {
      over33_3To50Ms++;
    } else {
      over50Ms++;
    }

    if (rawDeltaSeconds >= hitchThresholdSeconds) {
      if (runSeconds < firstSecondBoundary) {
        firstSecondHitches++;
      } else {
        laterHitches++;
      }
    }
  }

  void reset() {
    samples = 0;
    firstSecondHitches = 0;
    laterHitches = 0;
    atMost16_7Ms = 0;
    over16_7To33_3Ms = 0;
    over33_3To50Ms = 0;
    over50Ms = 0;
    worstGapMs = 0.0;
  }

  /// Created only when exporting a QA report, never inside the frame loop.
  String get reportFields => [
        'qaFrameGapSampleCount: $samples',
        'qaFrameGapHitchThresholdMs: 35.7',
        'qaFrameGapFirstSecondHitches: $firstSecondHitches',
        'qaFrameGapLaterHitches: $laterHitches',
        'qaFrameGapHitchesTotal: $totalHitches',
        'qaFrameGapWorstMs: ' + worstGapMs.toStringAsFixed(1),
        'qaFrameGapAtMost16_7Ms: $atMost16_7Ms',
        'qaFrameGapOver16_7To33_3Ms: $over16_7To33_3Ms',
        'qaFrameGapOver33_3To50Ms: $over33_3To50Ms',
        'qaFrameGapOver50Ms: $over50Ms',
      ].join('\n');
}
