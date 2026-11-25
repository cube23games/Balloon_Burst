import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';

/// TJ-45H: QA-only observation of the existing Flutter Ticker callback.
/// No independent frame requests, timers, controllers, or VSync signals.
class QaFrameSchedulerFlags {
  static const bool enabled = kEnableQaAutoTap &&
      bool.fromEnvironment('TJ45H_FRAME_SCHEDULER', defaultValue: false);
}

class QaSchedulerGap {
  QaSchedulerGap({
    required this.sample,
    required this.tickerUs,
    required this.engineStampUs,
    required this.tickerGapUs,
    required this.engineGapUs,
    required this.wallGapUs,
    required this.wallSampleUs,
    required this.debugVisible,
    required this.transientPhase,
  });
  final int sample;
  final int tickerUs;
  final int engineStampUs;
  final int tickerGapUs;
  final int engineGapUs;
  final int wallGapUs;
  final int wallSampleUs;
  final bool debugVisible;
  final bool transientPhase;
  int? postFrameUs;
  int? postFrameEngineStampUs;
}

/// Intervals can be compared; epochs are NOT assumed to match
/// FrameTiming.timestampInMicroseconds or Perfetto clocks.
class QaFrameSchedulerStats {
  static const int hitchThresholdUs = 35714;
  static const int capacity = 8;

  final Stopwatch _clock = Stopwatch()..start();
  int tickSamples = 0;
  int intervalSamples = 0;
  int tickerHitches = 0;
  int engineGapsOverThreshold = 0;
  int wallGapsOverThreshold = 0;
  int outOfTransientPhase = 0;
  int timestampRegressions = 0;
  int postFrameCallbacksObserved = 0;
  int worstTickerGapUs = 0;
  int worstEngineGapUs = 0;
  int worstWallGapUs = 0;
  int _lastTickerUs = -1;
  int _lastEngineUs = -1;
  int _lastWallUs = -1;

  final List<QaSchedulerGap> _worst = <QaSchedulerGap>[];
  final List<String> _markers = <String>[];

  int get clockUs => _clock.elapsedMicroseconds;
  int get retainedCount => _worst.length;
  List<QaSchedulerGap> get worst =>
      List<QaSchedulerGap>.of(_worst)
        ..sort((a, b) => b.tickerGapUs.compareTo(a.tickerGapUs));

  QaSchedulerGap? recordTick({
    required int tickerElapsedUs,
    required int engineFrameStampUs,
    required int wallStampUs,
    required bool transientPhase,
    required bool debugVisible,
  }) {
    tickSamples++;
    if (!transientPhase) outOfTransientPhase++;
    if (_lastTickerUs < 0) {
      _lastTickerUs = tickerElapsedUs;
      _lastEngineUs = engineFrameStampUs;
      _lastWallUs = wallStampUs;
      return null;
    }

    final tickerGapUs = tickerElapsedUs - _lastTickerUs;
    final engineGapUs = engineFrameStampUs - _lastEngineUs;
    final wallGapUs = wallStampUs - _lastWallUs;
    _lastTickerUs = tickerElapsedUs;
    _lastEngineUs = engineFrameStampUs;
    _lastWallUs = wallStampUs;

    if (tickerGapUs <= 0 || engineGapUs <= 0 || wallGapUs < 0) {
      timestampRegressions++;
      return null;
    }
    intervalSamples++;
    if (tickerGapUs > worstTickerGapUs) worstTickerGapUs = tickerGapUs;
    if (engineGapUs > worstEngineGapUs) worstEngineGapUs = engineGapUs;
    if (wallGapUs > worstWallGapUs) worstWallGapUs = wallGapUs;
    if (engineGapUs >= hitchThresholdUs) engineGapsOverThreshold++;
    if (wallGapUs >= hitchThresholdUs) wallGapsOverThreshold++;

    if (tickerGapUs < hitchThresholdUs) return null;
    tickerHitches++;
    var replace = -1;
    if (_worst.length == capacity) {
      replace = 0;
      for (var i = 1; i < _worst.length; i++) {
        if (_worst[i].tickerGapUs < _worst[replace].tickerGapUs) replace = i;
      }
      if (tickerGapUs <= _worst[replace].tickerGapUs) return null;
    }
    final sample = QaSchedulerGap(
      sample: tickSamples,
      tickerUs: tickerElapsedUs,
      engineStampUs: engineFrameStampUs,
      tickerGapUs: tickerGapUs,
      engineGapUs: engineGapUs,
      wallGapUs: wallGapUs,
      wallSampleUs: wallStampUs,
      debugVisible: debugVisible,
      transientPhase: transientPhase,
    );
    if (replace < 0) { _worst.add(sample); } else { _worst[replace] = sample; }
    return sample;
  }

  /// Called by an existing frame's one-shot post-frame observer ONLY after
  /// a worst-gap sample. Does not schedule additional Flutter frames.
  void recordPostFrame(QaSchedulerGap gap, int postFrameWallUs,
      int postFrameEngineStampUs) {
    if (!_worst.contains(gap)) return;
    if (gap.postFrameUs != null) return;
    gap.postFrameUs = postFrameWallUs - gap.wallSampleUs;
    gap.postFrameEngineStampUs = postFrameEngineStampUs;
    postFrameCallbacksObserved++;
  }

  /// Lifecycle restart can change ticker epoch. Discard the interval
  /// spanning a pause without discarding the previously recorded evidence.
  void markLifecycle(String marker) {
    if (_markers.length == 8) _markers.removeAt(0);
    _markers.add('$marker afterTick=$tickSamples atClockMs=${clockUs ~/ 1000}');
    _lastTickerUs = -1;
    _lastEngineUs = -1;
    _lastWallUs = -1;
  }

  void reset() {
    tickSamples = intervalSamples = tickerHitches = 0;
    engineGapsOverThreshold = wallGapsOverThreshold = 0;
    outOfTransientPhase = timestampRegressions = 0;
    postFrameCallbacksObserved = 0;
    worstTickerGapUs = worstEngineGapUs = worstWallGapUs = 0;
    _lastTickerUs = _lastEngineUs = _lastWallUs = -1;
    _worst.clear();
    _markers.clear();
    _clock..reset()..start();
  }

  String get reportFields {
    final lines = <String>[
      'qaSchedulerDiagnostic: enabled',
      'qaSchedulerScope: existingTickerCallback-noNewFrameRequests',
      'qaSchedulerRawEngineStampScope: arbitraryEngineEpoch-notPresentationTime',
      'qaSchedulerHitchThresholdMs: 35.714',
      'qaSchedulerTickSampleCount: $tickSamples',
      'qaSchedulerIntervalSampleCount: $intervalSamples',
      'qaSchedulerTickerHitchCount: $tickerHitches',
      'qaSchedulerEngineGapOverThresholdCount: $engineGapsOverThreshold',
      'qaSchedulerWallGapOverThresholdCount: $wallGapsOverThreshold',
      'qaSchedulerNonTransientPhaseCount: $outOfTransientPhase',
      'qaSchedulerTimestampRegressionCount: $timestampRegressions',
      'qaSchedulerPostFrameObservedCount: $postFrameCallbacksObserved',
      'qaSchedulerWorstTickerGapMs: ${_ms(worstTickerGapUs)}',
      'qaSchedulerWorstEngineGapMs: ${_ms(worstEngineGapUs)}',
      'qaSchedulerWorstWallGapMs: ${_ms(worstWallGapUs)}',
      'qaSchedulerRetainedWorstCount: $retainedCount',
    ];
    final selected = worst;
    for (var i = 0; i < selected.length; i++) {
      final s = selected[i];
      lines.add('qaSchedulerWorst[$i]: '
          'sample=${s.sample} '
          'rawEngineFrameStampUs=${s.engineStampUs} '
          'tickerGapMs=${_ms(s.tickerGapUs)} '
          'rawEngineGapMs=${_ms(s.engineGapUs)} '
          'wallGapMs=${_ms(s.wallGapUs)} '
          'postFrameCallbackMs=${s.postFrameUs == null ? "n/a" : _ms(s.postFrameUs!)} '
          'debugVisible=${s.debugVisible} '
          'transientPhase=${s.transientPhase}');
    }
    for (var i = 0; i < _markers.length; i++) {
      lines.add('qaSchedulerLifecycle[$i]: ${_markers[i]}');
    }
    return lines.join('\n');
  }

  static String _ms(int value) => (value / 1000.0).toStringAsFixed(2);
}
