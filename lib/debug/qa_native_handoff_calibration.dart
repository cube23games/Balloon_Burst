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


/// A lifecycle transition ordered by the Dart Stopwatch.
/// Not independent proof of a native suspend or its duration.
class QaClockEpochBoundary {
  const QaClockEpochBoundary(this.dartUs, this.reason);
  final int dartUs;
  final String reason;
}

/// Fail-closed mapping decision. Null anchor means no cross-clock estimate.
class QaClockEpochDecision {
  const QaClockEpochDecision(this.anchor, this.status);
  final QaHandoffAnchor? anchor;
  final String status;
}

/// Two bounded QA-only sampling bursts: early and on report export.
/// Native frame-delivery timing must still be read from Perfetto, not here.
class QaNativeHandoffCalibration {
  QaNativeHandoffCalibration(this.frameStats, {
    this.epochGuardEnabled = const bool.fromEnvironment(
        'TJ45M_CLOCK_EPOCH', defaultValue: false),
  });
  /// Legacy TJ-45L remains unchanged; TJ-45M is explicitly opt-in.
  final bool epochGuardEnabled;
  static const int probesPerPhase = 9;
  static const int maxLifecycleMarks = 16;
  /// 50ms is deliberately greater than native timestamp sampling noise.
  static const int discontinuityThresholdNs = 50000000;
  static const MethodChannel _channel =
      MethodChannel('com.cube23.balloonburst/lifecycle');
  final QaFrameRequestStats frameStats;
  final Map<String, QaHandoffAnchor> _best = {};
  final Map<String, int> _attempts = {}, _valid = {};
  final Set<String> _inFlight = {};
  final List<QaClockEpochBoundary> _lifecycleMarks = [];
  int lifecycleOverflow = 0;
  int _generation = 0;
  int failures = 0;

  void reset() {
    _generation++;
    _best.clear();
    _attempts.clear();
    _valid.clear();
    _inFlight.clear();
    _lifecycleMarks.clear();
    lifecycleOverflow = 0;
    failures = 0;
  }

  QaHandoffAnchor? anchorFor(String phase) => _best[phase];

  List<QaClockEpochBoundary> get lifecycleMarks =>
      List<QaClockEpochBoundary>.unmodifiable(_lifecycleMarks);

  void markLifecycle(String reason) =>
      markLifecycleAt(reason, frameStats.clockUs);

  /// Testable explicit timestamp: production passes the live Dart Stopwatch.
  void markLifecycleAt(String reason, int dartUs) {
    if (!epochGuardEnabled || dartUs < 0) return;
    if (_lifecycleMarks.length >= maxLifecycleMarks) {
      lifecycleOverflow++;
      return;
    }
    _lifecycleMarks.add(QaClockEpochBoundary(dartUs, reason));
  }

  int? get bootMinusMonoJumpNs {
    final a = _best['runStart'], b = _best['reportExport'];
    if (a == null || b == null) return null;
    return b.bootMinusMonoNs - a.bootMinusMonoNs;
  }

  bool? get clockEpochDiscontinuity {
    final delta = bootMinusMonoJumpNs;
    if (delta == null) return null;
    return delta.abs() >= discontinuityThresholdNs;
  }

  /// No interpolated clock conversions across a suspected suspend.
  /// If there is no lifecycle boundary and an offset jumped, the epoch
  /// transition cannot be localized, so decline ALL absolute estimates.
  QaClockEpochDecision resolveEvent(int dartUs) {
    if (!epochGuardEnabled) {
      return QaClockEpochDecision(bestAt(dartUs), 'legacy-nearest-anchor');
    }
    final early = _best['runStart'], late = _best['reportExport'];
    if (early == null) {
      return const QaClockEpochDecision(null, 'unmapped-no-runStart-anchor');
    }
    if (dartUs < early.dartMidUs) {
      return const QaClockEpochDecision(null, 'unmapped-before-runStart-anchor');
    }
    if (late != null && late.dartMidUs <= early.dartMidUs) {
      return const QaClockEpochDecision(null, 'unmapped-anchor-order-invalid');
    }
    if (late != null && dartUs >= late.dartMidUs) {
      return const QaClockEpochDecision(null, 'unmapped-at-or-after-export');
    }
    if (_lifecycleMarks.isNotEmpty) {
      if (early.dartMidUs >= _lifecycleMarks.first.dartUs) {
        return const QaClockEpochDecision(null, 'unmapped-runStart-after-lifecycle');
      }
      if (dartUs >= _lifecycleMarks.first.dartUs) {
        return const QaClockEpochDecision(null, 'unmapped-after-first-lifecycle');
      }
    } else if (clockEpochDiscontinuity == true) {
      return const QaClockEpochDecision(null, 'unmapped-clock-jump-without-boundary');
    }
    return QaClockEpochDecision(
        early, 'provisional-runStart-before-lifecycle');
  }

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
    if (epochGuardEnabled) {
      final jump = clockEpochDiscontinuity;
      lines.add('qaClockEpochIntegrityDiagnostic: enabled');
      lines.add('qaClockEpochMappingPolicy: earlyAnchorOnly-beforeFirstLifecycle');
      lines.add('qaClockEpochDiscontinuityThresholdNs: $discontinuityThresholdNs');
      lines.add('qaClockEpochDiscontinuity: ${jump == null ? 'unknown' : jump ? 'detected' : 'notDetected'}');
      lines.add('qaClockEpochBootMinusMonoJumpNs: ${bootMinusMonoJumpNs ?? 'n/a'}');
      lines.add('qaClockEpochLifecycleMarkCount: ${_lifecycleMarks.length}');
      lines.add('qaClockEpochLifecycleMarkOverflow: $lifecycleOverflow');
      lines.add('qaClockEpochFirstLifecycleUs: ${_lifecycleMarks.isEmpty ? -1 : _lifecycleMarks.first.dartUs}');
      for (var i = 0; i < _lifecycleMarks.length; i++) {
        final e = _lifecycleMarks[i];
        lines.add('qaClockEpochLifecycle[$i]: dartUs=${e.dartUs} reason=${e.reason}');
      }
    }
    return lines.join('\n');
  }

  String get eventFields {
    final lines = <String>[];
    void add(String label, List<QaFrameRequestObservation> events) {
      for (var i = 0; i < events.length; i++) {
        final s = events[i];
        final decision = resolveEvent(s.beginUs);
        final a = decision.anchor;
        lines.add('$label[$i]: sample=${s.tickerSample} frameId=${s.frameId} '
          'calibrationPhase=${a?.phase ?? 'unmapped'} '
          'qaEpochMappingStatus=${decision.status} '
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
