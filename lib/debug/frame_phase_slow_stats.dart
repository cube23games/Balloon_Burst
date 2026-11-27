import 'dart:ui' show FramePhase, FrameTiming;

/// TJ-45E: bounded slow-frame phase attribution, QA use only.
///
/// A FrameTiming contains mutually comparable phase timestamps. In contrast,
/// game ticker callback gaps and display presentation have different clocks.
class FramePhaseSlowStats {
  static const int frameBudgetMicros = 16667;
  static const int worstCapacity = 8;

  int samples = 0;
  int invalidPhaseOrder = 0;
  int slowFrames = 0;
  int dominantVsyncWait = 0;
  int dominantUiBuild = 0;
  int dominantRasterQueue = 0;
  int dominantRasterWork = 0;

  final List<SlowFramePhaseSample> _worst = <SlowFramePhaseSample>[];
  int get retainedCount => _worst.length;

  // Only copied/sorted when a detailed report is requested, not per frame.
  List<SlowFramePhaseSample> get worstFrames =>
      List<SlowFramePhaseSample>.of(_worst)
        ..sort((a, b) => b.totalMicros.compareTo(a.totalMicros));

  void record(FrameTiming frame) {
    final vsync = frame.timestampInMicroseconds(FramePhase.vsyncStart);
    final buildStart = frame.timestampInMicroseconds(FramePhase.buildStart);
    final buildFinish = frame.timestampInMicroseconds(FramePhase.buildFinish);
    final rasterStart = frame.timestampInMicroseconds(FramePhase.rasterStart);
    final rasterFinish = frame.timestampInMicroseconds(FramePhase.rasterFinish);

    final waitUs = buildStart - vsync;
    final buildUs = buildFinish - buildStart;
    final queueUs = rasterStart - buildFinish;
    final rasterUs = rasterFinish - rasterStart;
    final totalUs = rasterFinish - vsync;

    // Do not manufacture positive spans from non-monotonic input.
    if (waitUs < 0 || buildUs < 0 || queueUs < 0 || rasterUs < 0 ||
        totalUs < 0 || waitUs + buildUs + queueUs + rasterUs != totalUs) {
      invalidPhaseOrder++;
      return;
    }

    samples++;
    if (totalUs <= frameBudgetMicros) return;
    slowFrames++;

    // Each slow frame has one largest stage; ties go to the earlier stage.
    var maxUs = waitUs;
    if (buildUs > maxUs) maxUs = buildUs;
    if (queueUs > maxUs) maxUs = queueUs;
    if (rasterUs > maxUs) maxUs = rasterUs;
    if (waitUs == maxUs) {
      dominantVsyncWait++;
    } else if (buildUs == maxUs) {
      dominantUiBuild++;
    } else if (queueUs == maxUs) {
      dominantRasterQueue++;
    } else {
      dominantRasterWork++;
    }

    var replaceIndex = -1;
    if (_worst.length >= worstCapacity) {
      replaceIndex = 0;
      for (var i = 1; i < _worst.length; i++) {
        if (_worst[i].totalMicros < _worst[replaceIndex].totalMicros) {
          replaceIndex = i;
        }
      }
      if (totalUs <= _worst[replaceIndex].totalMicros) return;
    }
    // No per-frame history growth: allocate only when entering top eight.
    final entry = SlowFramePhaseSample(
      sampleIndex: samples,
      frameNumber: frame.frameNumber,
      vsyncTimestampUs: vsync,
      vsyncWaitMicros: waitUs,
      buildMicros: buildUs,
      rasterQueueMicros: queueUs,
      rasterMicros: rasterUs,
      totalMicros: totalUs,
    );
    if (replaceIndex < 0) {
      _worst.add(entry);
    } else {
      _worst[replaceIndex] = entry;
    }
  }

  void reset() {
    samples = 0;
    invalidPhaseOrder = 0;
    slowFrames = 0;
    dominantVsyncWait = 0;
    dominantUiBuild = 0;
    dominantRasterQueue = 0;
    dominantRasterWork = 0;
    _worst.clear();
  }

  String get reportFields {
    final lines = <String>[
      'qaFramePhaseDiagnostic: enabled',
      'qaFramePhaseBudgetMs: 16.7',
      'qaFramePhaseSampleCount: $samples',
      'qaFramePhaseInvalidOrderCount: $invalidPhaseOrder',
      'qaFramePhaseSlowCount: $slowFrames',
      'qaFramePhaseDominantVsyncWaitCount: $dominantVsyncWait',
      'qaFramePhaseDominantUiBuildCount: $dominantUiBuild',
      'qaFramePhaseDominantRasterQueueCount: $dominantRasterQueue',
      'qaFramePhaseDominantRasterWorkCount: $dominantRasterWork',
      'qaFramePhaseRetainedWorstCount: $retainedCount',
    ];
    final sorted = worstFrames;
    for (var i = 0; i < sorted.length; i++) {
      final f = sorted[i];
      lines.add('qaFramePhaseWorst[$i]: '
          'sample=${f.sampleIndex} frame=${f.frameNumber} '
          'vsyncTimestampUs=${f.vsyncTimestampUs} '
          'totalMs=${_ms(f.totalMicros)} '
          'vsyncWaitMs=${_ms(f.vsyncWaitMicros)} '
          'uiBuildMs=${_ms(f.buildMicros)} '
          'rasterQueueMs=${_ms(f.rasterQueueMicros)} '
          'rasterMs=${_ms(f.rasterMicros)}');
    }
    return lines.join('\n');
  }

  static String _ms(int us) => (us / 1000.0).toStringAsFixed(2);
}

class SlowFramePhaseSample {
  final int sampleIndex;
  final int frameNumber;
  final int vsyncTimestampUs;
  final int vsyncWaitMicros;
  final int buildMicros;
  final int rasterQueueMicros;
  final int rasterMicros;
  final int totalMicros;

  const SlowFramePhaseSample({
    required this.sampleIndex,
    required this.frameNumber,
    required this.vsyncTimestampUs,
    required this.vsyncWaitMicros,
    required this.buildMicros,
    required this.rasterQueueMicros,
    required this.rasterMicros,
    required this.totalMicros,
  });
}
