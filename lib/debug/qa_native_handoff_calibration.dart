import 'package:flutter/services.dart';
import 'qa_frame_request_stats.dart';

/// Best of bounded round-trip clock probes; no frame scheduling changes.
class QaHandoffAnchor {
  const QaHandoffAnchor(this.phase, this.beforeUs, this.afterUs,
      this.monoBeforeNs, this.bootNs, this.monoAfterNs);
  final String phase;
  final int beforeUs, afterUs, monoBeforeNs, bootNs, monoAfterNs;
  int get rttUs => afterUs - beforeUs;
  int get nativeSpanNs => monoAfterNs - monoBeforeNs;
  int get dartMidUs => beforeUs + rttUs ~/ 2;
  int get monoMidNs => monoBeforeNs + nativeSpanNs ~/ 2;
  int get bootMinusMonoNs => bootNs - monoMidNs;
  int get bootAtZeroNs => bootNs - dartMidUs * 1000;
  // A midpoint/transport approximation, NOT a guaranteed hard bound.
  int get nominalHalfWindowUs =>
      (rttUs + 1) ~/ 2 + (nativeSpanNs + 1999) ~/ 2000;
  int atBootNs(int dartUs) => bootAtZeroNs + dartUs * 1000;
}

/// Two bounded QA-only sampling bursts: early and on report export.
/// Native frame-delivery timing must still be read from Perfetto, not here.
class QaNativeHandoffCalibration {
  QaNativeHandoffCalibration(this.frameStats);
  static const int probesPerPhase = 9;
  static const MethodChannel _channel =
      MethodChannel('com.cube23.balloonburst/lifecycle');
  final QaFrameRequestStats frameStats;
  final Map<String, QaHandoffAnchor> _best = {};
  final Map<String, int> _attempts = {}, _valid = {};
  final Set<String> _inFlight = {};
  int _generation = 0;
  int failures = 0;

  void reset() {
    _generation++;
    _best.clear();
    _attempts.clear();
    _valid.clear();
    _inFlight.clear();
    failures = 0;
  }

  QaHandoffAnchor? anchorFor(String phase) => _best[phase];

  bool recordSample({
    required String phase, required int beforeUs, required int afterUs,
    required int monoBeforeNs, required int bootNs,
    required int monoAfterNs,
  }) {
    _attempts[phase] = (_attempts[phase] ?? 0) + 1;
    if (beforeUs < 0 || afterUs < beforeUs || monoBeforeNs <= 0 ||
        bootNs <= 0 || monoAfterNs < monoBeforeNs) {
      failures++;
      return false;
    }
    _valid[phase] = (_valid[phase] ?? 0) + 1;
    final a = QaHandoffAnchor(phase, beforeUs, afterUs,
        monoBeforeNs, bootNs, monoAfterNs);
    final old = _best[phase];
    if (old == null || a.rttUs < old.rttUs ||
        (a.rttUs == old.rttUs && a.nativeSpanNs < old.nativeSpanNs)) {
      _best[phase] = a;
    }
    return true;
  }

  void recordFailure(String phase) {
    _attempts[phase] = (_attempts[phase] ?? 0) + 1;
    failures++;
  }

  QaHandoffAnchor? bestAt(int dartUs) {
    final a = _best['runStart'], b = _best['reportExport'];
    if (a == null) return b;
    if (b == null) return a;
    return (dartUs - b.dartMidUs).abs() < (dartUs - a.dartMidUs).abs()
        ? b : a;
  }

  Future<void> samplePhase(String phase) async {
    if (phase != 'runStart' && phase != 'reportExport') return;
    if (_best.containsKey(phase) || _inFlight.contains(phase)) return;
    final generation = _generation;
    _inFlight.add(phase);
    try {
      for (var i = 0; i < probesPerPhase; i++) {
        if (generation != _generation) break;
        final before = frameStats.clockUs;
        try {
          final data = await _channel.invokeMapMethod<String, dynamic>(
            'getQaNativeHandoffClockAnchor',
          );
          final after = frameStats.clockUs;
          if (generation != _generation) break;
          final m1 = data?['monoBeforeNs'];
          final boot = data?['boottimeNs'];
          final m2 = data?['monoAfterNs'];
          if (m1 is! int || boot is! int || m2 is! int) {
            recordFailure(phase);
            continue;
          }
          if (recordSample(phase: phase, beforeUs: before, afterUs: after,
              monoBeforeNs: m1, bootNs: boot, monoAfterNs: m2)) {
            // Keep original TJ-45K anchor fields populated for comparison.
            frameStats.recordClockAnchor(
              dartBeforeUs: before, dartAfterUs: after,
              nativeMonotonicNs: m1 + (m2 - m1) ~/ 2,
              nativeBoottimeNs: boot,
            );
          }
        } catch (_) {
          if (generation == _generation) recordFailure(phase);
        }
      }
    } finally {
      _inFlight.remove(phase);
    }
  }

  String get reportFields {
    final a = _best['runStart'], b = _best['reportExport'];
    final lines = <String>[
      'qaNativeHandoffDiagnostic: enabled',
      'qaNativeHandoffScope: offline-nativeFrameEvent-to-flutterBegin',
      'qaNativeHandoffSampling: 9PerPhase-noNewFrameListeners',
      'qaNativeHandoffMarker: TJ45L_clock_anchor-perSampleOnly',
      'qaNativeHandoffFailedSamples: $failures',
    ];
    for (final phase in <String>['runStart', 'reportExport']) {
      final x = _best[phase];
      lines.add('qaNativeHandoff${phase}Attempts: ${_attempts[phase] ?? 0}');
      lines.add('qaNativeHandoff${phase}Valid: ${_valid[phase] ?? 0}');
      lines.add('qaNativeHandoff${phase}BestRttUs: ${x?.rttUs ?? -1}');
      lines.add('qaNativeHandoff${phase}NativeSpanNs: ${x?.nativeSpanNs ?? -1}');
      lines.add('qaNativeHandoff${phase}DartMidUs: ${x?.dartMidUs ?? -1}');
      lines.add('qaNativeHandoff${phase}BootAtDartZeroNs: ${x?.bootAtZeroNs ?? -1}');
      lines.add('qaNativeHandoff${phase}BootMinusMonoNs: ${x?.bootMinusMonoNs ?? -1}');
      lines.add('qaNativeHandoff${phase}NominalHalfWindowUs: ${x?.nominalHalfWindowUs ?? -1}');
    }
    lines.add('qaNativeHandoffOffsetDriftNs: ${a == null || b == null ? 'n/a' : b.bootAtZeroNs - a.bootAtZeroNs}');
    lines.add('qaNativeHandoffBootMinusMonoDriftNs: ${a == null || b == null ? 'n/a' : b.bootMinusMonoNs - a.bootMinusMonoNs}');
    return lines.join('\n');
  }

  String get eventFields {
    final lines = <String>[];
    void add(String label, List<QaFrameRequestObservation> events) {
      for (var i = 0; i < events.length; i++) {
        final s = events[i], a = bestAt(s.beginUs);
        lines.add('$label[$i]: sample=${s.tickerSample} frameId=${s.frameId} '
          'calibrationPhase=${a?.phase ?? 'missing'} '
          'requestBootNs=${s.requestUs == null || a == null ? -1 : a.atBootNs(s.requestUs!)} '
          'beginBootNs=${a?.atBootNs(s.beginUs) ?? -1} '
          'tickerBootNs=${a?.atBootNs(s.tickerUs) ?? -1} '
          'nominalHalfWindowUs=${a?.nominalHalfWindowUs ?? -1} '
          'requestToBeginUs=${s.requestToBeginUs ?? -1} '
          'beginToTickerUs=${s.beginToTickerUs} '
          'wallGapUs=${s.wallGapUs} engineGapUs=${s.engineGapUs}');
      }
    }
    add('qaNativeHandoffWorstWallOnly', frameStats.worstWallOnly);
    add('qaNativeHandoffWorstWait', frameStats.worstRequestWait);
    return lines.join('\n');
  }
}
