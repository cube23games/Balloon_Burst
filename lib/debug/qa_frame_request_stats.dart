/// TJ-45K: bounded QA-only observations of Flutter's *existing* frame path.
/// These are framework request/begin/Ticker times, NOT Android VSync delivery
/// timestamps or physical display presentation times.
class QaFrameRequestObservation {
  QaFrameRequestObservation({
    required this.frameId,
    required this.tickerSample,
    required this.requestUs,
    required this.beginUs,
    required this.tickerUs,
    required this.rawEngineStampUs,
    required this.engineGapUs,
    required this.wallGapUs,
  });
  final int frameId, tickerSample, beginUs, tickerUs, rawEngineStampUs;
  final int engineGapUs, wallGapUs;
  final int? requestUs;
  int? get requestToBeginUs =>
      requestUs == null ? null : beginUs - requestUs!;
  int get beginToTickerUs => tickerUs - beginUs;
}

class QaFrameRequestStats {
  static const int slowThresholdUs = 35714;
  static const int maxRetained = 8;
  final Stopwatch _clock = Stopwatch()..start();
  int get clockUs => _clock.elapsedMicroseconds;

  bool _running = false;
  int requests = 0, beginFrames = 0, tickerCallbacks = 0;
  int unmatchedBegins = 0, unmatchedTickers = 0, pendingOverwritten = 0;
  int invalidIntervals = 0, wallOnlySlow = 0;
  int requestWaitsOverThreshold = 0, beginToTickerOver8ms = 0;
  int? _pendingRequestUs;
  int? _beginUs;
  int? _beginRequestUs;
  int? _lastTickerUs;
  int? _lastEngineStampUs;
  int _frameId = 0, _lastTickerFrameId = -1;
  int _rawStampUs = 0;
  int _anchorRoundTripUs = -1, _monoAtClockZeroNs = 0;
  int _bootMinusMonoNs = 0;
  final List<QaFrameRequestObservation> _worstWallOnly = [];
  final List<QaFrameRequestObservation> _worstRequestWait = [];
  List<QaFrameRequestObservation> get worstWallOnly =>
      List.of(_worstWallOnly)
        ..sort((a, b) => b.wallGapUs.compareTo(a.wallGapUs));
  List<QaFrameRequestObservation> get worstRequestWait =>
      List.of(_worstRequestWait)
        ..sort((a, b) => (b.requestToBeginUs ?? 0)
            .compareTo(a.requestToBeginUs ?? 0));

  void reset() {
    _clock..reset()..start();
    _running = true;
    requests = beginFrames = tickerCallbacks = 0;
    unmatchedBegins = unmatchedTickers = pendingOverwritten = 0;
    invalidIntervals = wallOnlySlow = 0;
    requestWaitsOverThreshold = beginToTickerOver8ms = 0;
    _pendingRequestUs = _beginUs = _beginRequestUs = null;
    _lastTickerUs = _lastEngineStampUs = null;
    _frameId = 0;
    _lastTickerFrameId = -1;
    _rawStampUs = 0;
    _anchorRoundTripUs = -1;
    _monoAtClockZeroNs = _bootMinusMonoNs = 0;
    _worstWallOnly.clear();
    _worstRequestWait.clear();
  }

  void markLifecycle() {
    // Never pair a frame request, callback or Ticker across pause/resume.
    _pendingRequestUs = _beginUs = _beginRequestUs = null;
    _lastTickerUs = _lastEngineStampUs = null;
    _lastTickerFrameId = _frameId;
  }

  void recordRequest(int wallUs) {
    if (!_running) return;
    requests++;
    if (_pendingRequestUs != null) pendingOverwritten++;
    _pendingRequestUs = wallUs;
  }

  void recordBegin(int wallUs, int rawStampUs) {
    if (!_running) return;
    beginFrames++;
    _frameId++;
    _beginUs = wallUs;
    _rawStampUs = rawStampUs;
    _beginRequestUs = _pendingRequestUs;
    if (_pendingRequestUs == null) unmatchedBegins++;
    _pendingRequestUs = null;
  }

  QaFrameRequestObservation? recordTicker({
    required int tickerSample,
    required int wallUs,
    required int rawStampUs,
  }) {
    if (!_running) return null;
    if (_beginUs == null || _lastTickerFrameId == _frameId ||
        rawStampUs != _rawStampUs) {
      unmatchedTickers++;
      return null;
    }
    _lastTickerFrameId = _frameId;
    tickerCallbacks++;
    final beginUs = _beginUs!;
    final requestUs = _beginRequestUs;
    final wallGapUs = _lastTickerUs == null ? 0 : wallUs - _lastTickerUs!;
    final engineGapUs = _lastEngineStampUs == null
        ? 0 : rawStampUs - _lastEngineStampUs!;
    _lastTickerUs = wallUs;
    _lastEngineStampUs = rawStampUs;
    final reqGapUs = requestUs == null ? null : beginUs - requestUs;
    if (wallGapUs < 0 || engineGapUs < 0 || wallUs < beginUs ||
        (reqGapUs != null && reqGapUs < 0)) {
      invalidIntervals++;
      return null;
    }
    if (wallGapUs >= slowThresholdUs &&
        engineGapUs < slowThresholdUs) wallOnlySlow++;
    if (reqGapUs != null && reqGapUs >= slowThresholdUs) {
      requestWaitsOverThreshold++;
    }
    if (wallUs - beginUs >= 8000) beginToTickerOver8ms++;
    if ((wallGapUs < slowThresholdUs || engineGapUs >= slowThresholdUs) &&
        (reqGapUs == null || reqGapUs < slowThresholdUs)) return null;
    final observation = QaFrameRequestObservation(
      frameId: _frameId, tickerSample: tickerSample,
      requestUs: requestUs, beginUs: beginUs, tickerUs: wallUs,
      rawEngineStampUs: rawStampUs, engineGapUs: engineGapUs,
      wallGapUs: wallGapUs,
    );
    if (wallGapUs >= slowThresholdUs && engineGapUs < slowThresholdUs) {
      _retain(_worstWallOnly, observation, (v) => v.wallGapUs);
    }
    if (reqGapUs != null && reqGapUs >= slowThresholdUs) {
      _retain(_worstRequestWait, observation, (v) => v.requestToBeginUs ?? 0);
    }
    return observation;
  }

  void recordClockAnchor({
    required int dartBeforeUs,
    required int dartAfterUs,
    required int nativeMonotonicNs,
    required int nativeBoottimeNs,
  }) {
    if (!_running || nativeMonotonicNs <= 0 || nativeBoottimeNs <= 0 ||
        dartBeforeUs < 0 || dartAfterUs < dartBeforeUs) return;
    final roundTrip = dartAfterUs - dartBeforeUs;
    if (_anchorRoundTripUs >= 0 && roundTrip >= _anchorRoundTripUs) return;
    _anchorRoundTripUs = roundTrip;
    _monoAtClockZeroNs =
        nativeMonotonicNs - (dartBeforeUs + dartAfterUs) * 500;
    _bootMinusMonoNs = nativeBoottimeNs - nativeMonotonicNs;
  }

  void _retain(List<QaFrameRequestObservation> list,
      QaFrameRequestObservation item, int Function(QaFrameRequestObservation) score) {
    if (list.length < maxRetained) { list.add(item); return; }
    var smallest = 0;
    for (var i = 1; i < list.length; i++) {
      if (score(list[i]) < score(list[smallest])) smallest = i;
    }
    if (score(item) > score(list[smallest])) list[smallest] = item;
  }

  String get reportFields {
    if (!_running) return '';
    final out = <String>[
      'qaFrameRequestCorrelationDiagnostic: enabled',
      'qaFrameRequestScope: framework-scheduleFrame-to-handleBeginFrame-to-gameTicker',
      'qaFrameRequestNativeVsyncScope: perfetto-only-no-native-frame-loop',
      'qaFrameRequestCount: $requests',
      'qaFrameBeginCount: $beginFrames',
      'qaFrameTickerCount: $tickerCallbacks',
      'qaFrameRequestUnmatchedBegins: $unmatchedBegins',
      'qaFrameRequestUnmatchedTickers: $unmatchedTickers',
      'qaFrameRequestPendingOverwrites: $pendingOverwritten',
      'qaFrameRequestInvalidIntervals: $invalidIntervals',
      'qaFrameRequestWallOnlySlowCount: $wallOnlySlow',
      'qaFrameRequestWaitOver35_7Count: $requestWaitsOverThreshold',
      'qaFrameRequestBeginToTickerOver8msCount: $beginToTickerOver8ms',
      'qaFrameRequestClockAnchorRoundTripUs: $_anchorRoundTripUs',
      'qaFrameRequestClockMonoAtZeroNs: $_monoAtClockZeroNs',
      'qaFrameRequestClockBootMinusMonoNs: $_bootMinusMonoNs',
      'qaFrameRequestWorstWallOnlyRetained: ${_worstWallOnly.length}',
      'qaFrameRequestWorstWaitRetained: ${_worstRequestWait.length}',
    ];
    void add(String label, List<QaFrameRequestObservation> records) {
      for (var i = 0; i < records.length; i++) {
        final s = records[i];
        out.add('$label[$i]: '
            'sample=${s.tickerSample} frameId=${s.frameId} '
            'dartRequestUs=${s.requestUs ?? -1} '
            'dartBeginUs=${s.beginUs} dartTickerUs=${s.tickerUs} '
            'rawEngineFrameStampUs=${s.rawEngineStampUs} '
            'requestToBeginMs=${_ms(s.requestToBeginUs)} '
            'beginToTickerMs=${_ms(s.beginToTickerUs)} '
            'engineGapMs=${_ms(s.engineGapUs)} '
            'wallGapMs=${_ms(s.wallGapUs)}');
      }
    }
    add('qaFrameRequestWorstWallOnly', worstWallOnly);
    add('qaFrameRequestWorstWait', worstRequestWait);
    return out.join('\n');
  }

  static String _ms(int? micros) =>
      micros == null ? 'n/a' : (micros / 1000.0).toStringAsFixed(2);
}
