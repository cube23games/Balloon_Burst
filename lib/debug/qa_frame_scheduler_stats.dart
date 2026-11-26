import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';

/// TJ-45H: QA-only observation of the existing Flutter Ticker callback.
/// No independent frame requests, timers, controllers, or VSync signals.
class QaFrameSchedulerFlags {
  static const bool enabled = kEnableQaAutoTap &&
      bool.fromEnvironment('TJ45H_FRAME_SCHEDULER', defaultValue: false);
}

/// TJ-45I correlation is enabled only in its dedicated QA APK.
class QaWallClockCorrelationFlags {
  static const bool enabled = QaFrameSchedulerFlags.enabled &&
      bool.fromEnvironment('TJ45I_WALL_CLOCK_CORRELATION', defaultValue: false);
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
    this.startup = false,
    this.msAfterLifecycle = -1,
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
  final bool startup;
  final int msAfterLifecycle;
  int? postFrameUs;
  int? postFrameEngineStampUs;
}

/// Intervals can be compared; epochs are NOT assumed to match
/// FrameTiming.timestampInMicroseconds or Perfetto clocks.
class QaFrameSchedulerStats {
  QaFrameSchedulerStats({bool? wallCorrelationEnabled})
      : _wallCorrelationEnabled =
            wallCorrelationEnabled ?? QaWallClockCorrelationFlags.enabled;

  final bool _wallCorrelationEnabled;
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
  // Independent, mutually exclusive cross-tab for every VALID interval.
  int wallOnlySlow = 0, engineOnlySlow = 0, bothSlow = 0, neitherSlow = 0;
  int differingClockIntervals = 0;
  int startupSlowWallIntervals = 0;
  int nearLifecycleSlowWallIntervals = 0;
  int debugVisibleSlowWallIntervals = 0;
  int _lastLifecycleUs = -1;
  int _lastTickerUs = -1;
  int _lastEngineUs = -1;
  int _lastWallUs = -1;

  final List<QaSchedulerGap> _worst = <QaSchedulerGap>[];
  // Separate bounded wall-clock rankings: top eight overall and wall-only.
  final List<QaSchedulerGap> _worstWall = <QaSchedulerGap>[];
  final List<QaSchedulerGap> _worstWallOnly = <QaSchedulerGap>[];
  final List<String> _markers = <String>[];

  int get clockUs => _clock.elapsedMicroseconds;
  int get retainedCount => _worst.length;
  List<QaSchedulerGap> get worst =>
      List<QaSchedulerGap>.of(_worst)
        ..sort((a, b) => b.tickerGapUs.compareTo(a.tickerGapUs));
  List<QaSchedulerGap> get worstWall =>
      List<QaSchedulerGap>.of(_worstWall)
        ..sort((a, b) => b.wallGapUs.compareTo(a.wallGapUs));
  List<QaSchedulerGap> get worstWallOnly =>
      List<QaSchedulerGap>.of(_worstWallOnly)
        ..sort((a, b) => b.wallGapUs.compareTo(a.wallGapUs));
  bool get wallCorrelationEnabled => _wallCorrelationEnabled;

  bool _qualifies(List<QaSchedulerGap> list, int value, bool byWall) {
    if (list.length < capacity) return true;
    var smallest = _gapValue(list[0], byWall);
    for (var i = 1; i < list.length; i++) {
      final candidate = _gapValue(list[i], byWall);
      if (candidate < smallest) smallest = candidate;
    }
    return value > smallest;
  }

  int _gapValue(QaSchedulerGap gap, bool byWall) =>
      byWall ? gap.wallGapUs : gap.tickerGapUs;

  void _retain(List<QaSchedulerGap> list, QaSchedulerGap candidate,
      {required bool byWall}) {
    if (list.length < capacity) {
      list.add(candidate);
      return;
    }
    var minIndex = 0;
    for (var i = 1; i < list.length; i++) {
      if (_gapValue(list[i], byWall) <
          _gapValue(list[minIndex], byWall)) minIndex = i;
    }
    if (_gapValue(candidate, byWall) >
        _gapValue(list[minIndex], byWall)) {
      list[minIndex] = candidate;
    }
  }

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

    final tickerSlow = tickerGapUs >= hitchThresholdUs;
    final engineSlow = engineGapUs >= hitchThresholdUs;
    final wallSlow = wallGapUs >= hitchThresholdUs;
    if (tickerSlow) tickerHitches++;

    if (_wallCorrelationEnabled) {
      // Mutually exclusive cross-tab: never infer overlap by subtraction.
      if (wallSlow && engineSlow) {
        bothSlow++;
      } else if (wallSlow) {
        wallOnlySlow++;
      } else if (engineSlow) {
        engineOnlySlow++;
      } else {
        neitherSlow++;
      }
      if ((wallGapUs - engineGapUs).abs() >= 16667) {
        differingClockIntervals++;
      }
      if (wallSlow) {
        if (wallStampUs < 1000000) startupSlowWallIntervals++;
        if (_lastLifecycleUs >= 0 &&
            wallStampUs - _lastLifecycleUs <= 2500000) {
          nearLifecycleSlowWallIntervals++;
        }
        if (debugVisible) debugVisibleSlowWallIntervals++;
      }
    }

    final qualifyTicker = tickerSlow &&
        _qualifies(_worst, tickerGapUs, false);
    final qualifyWall = _wallCorrelationEnabled && wallSlow &&
        _qualifies(_worstWall, wallGapUs, true);
    final qualifyWallOnly = _wallCorrelationEnabled && wallSlow &&
        !engineSlow && _qualifies(_worstWallOnly, wallGapUs, true);
    if (!qualifyTicker && !qualifyWall && !qualifyWallOnly) return null;

    // Allocate one entry only for a gap entering at least one bounded list.
    // The identical entry may belong to more than one list; the post-frame
    // callback is registered once, on the already-scheduled Flutter frame.
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
      startup: wallStampUs < 1000000,
      msAfterLifecycle: _lastLifecycleUs < 0
          ? -1 : (wallStampUs - _lastLifecycleUs) ~/ 1000,
    );
    if (qualifyTicker) _retain(_worst, sample, byWall: false);
    if (qualifyWall) _retain(_worstWall, sample, byWall: true);
    if (qualifyWallOnly) _retain(_worstWallOnly, sample, byWall: true);
    return sample;
  }

  /// Called by an existing frame's one-shot post-frame observer ONLY after
  /// a worst-gap sample. Does not schedule additional Flutter frames.
  void recordPostFrame(QaSchedulerGap gap, int postFrameWallUs,
      int postFrameEngineStampUs) {
    if (!_worst.contains(gap) && !_worstWall.contains(gap) &&
        !_worstWallOnly.contains(gap)) return;
    if (gap.postFrameUs != null) return;
    gap.postFrameUs = postFrameWallUs - gap.wallSampleUs;
    gap.postFrameEngineStampUs = postFrameEngineStampUs;
    postFrameCallbacksObserved++;
  }

  /// Lifecycle restart can change ticker epoch. Discard the interval
  /// spanning a pause without discarding the previously recorded evidence.
  void markLifecycle(String marker) {
    _lastLifecycleUs = clockUs;
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
    wallOnlySlow = engineOnlySlow = bothSlow = neitherSlow = 0;
    differingClockIntervals = startupSlowWallIntervals = 0;
    nearLifecycleSlowWallIntervals = debugVisibleSlowWallIntervals = 0;
    _lastLifecycleUs = -1;
    _lastTickerUs = _lastEngineUs = _lastWallUs = -1;
    _worst.clear();
    _worstWall.clear();
    _worstWallOnly.clear();
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
    if (_wallCorrelationEnabled) {
      lines.addAll(<String>[
        'qaWallClockCorrelationDiagnostic: enabled',
        'qaWallClockCrossTabScope: validCallbackIntervals-only',
        'qaWallClockBothSlowCount: $bothSlow',
        'qaWallClockWallOnlySlowCount: $wallOnlySlow',
        'qaWallClockEngineOnlySlowCount: $engineOnlySlow',
        'qaWallClockNeitherSlowCount: $neitherSlow',
        'qaWallClockDeltaDifferenceOver16_7Count: $differingClockIntervals',
        'qaWallClockStartupSlowWallCount: $startupSlowWallIntervals',
        'qaWallClockAfterLifecycle2500msSlowWallCount: $nearLifecycleSlowWallIntervals',
        'qaWallClockDebugVisibleSlowWallCount: $debugVisibleSlowWallIntervals',
        'qaWallClockWorstWallRetainedCount: ${_worstWall.length}',
        'qaWallClockWorstWallOnlyRetainedCount: ${_worstWallOnly.length}',
      ]);
      final wall = worstWall;
      for (var i = 0; i < wall.length; i++) {
        lines.add(_wallRecord('qaWallClockWorstWall[$i]', wall[i]));
      }
      final only = worstWallOnly;
      for (var i = 0; i < only.length; i++) {
        lines.add(_wallRecord('qaWallClockWorstWallOnly[$i]', only[i]));
      }
    }
    return lines.join('\n');
  }

  String _wallRecord(String field, QaSchedulerGap s) =>
      '$field: sample=${s.sample} wallAtMs=${_ms(s.wallSampleUs)} '
      'rawEngineFrameStampUs=${s.engineStampUs} '
      'tickerGapMs=${_ms(s.tickerGapUs)} '
      'rawEngineGapMs=${_ms(s.engineGapUs)} '
      'wallGapMs=${_ms(s.wallGapUs)} '
      'postFrameCallbackMs=${s.postFrameUs == null ? "n/a" : _ms(s.postFrameUs!)} '
      'startup=${s.startup} '
      'msAfterLifecycle=${s.msAfterLifecycle} '
      'debugVisible=${s.debugVisible} '
      'transientPhase=${s.transientPhase}';

  static String _ms(int value) => (value / 1000.0).toStringAsFixed(2);
}
