import 'dart:developer' show Timeline;
import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';

/// TJ-45G QA-only. Public and all previous QA builds have zero extra probes.
class QaUiBuildFlags {
  static const bool enabled = kEnableQaAutoTap &&
      bool.fromEnvironment('TJ45G_UI_BUILD', defaultValue: false);
}

enum QaUiBuildStage { appRoot, gameScaffold, gameLayout, debugHud }

class QaUiBuildSample {
  const QaUiBuildSample(this.index, this.durationUs, this.debugVisible,
      this.msAfterNavigation);
  final int index;
  final int durationUs;
  final bool debugVisible;
  final int msAfterNavigation;
}

class QaUiStageStats {
  static const int budgetUs = 16667;
  static const int worstCapacity = 4;
  int samples = 0, overBudget = 0, worstUs = 0, _sumUs = 0;
  final List<QaUiBuildSample> _worst = <QaUiBuildSample>[];

  double get averageMs => samples == 0 ? 0 : _sumUs / (1000 * samples);
  int get retainedCount => _worst.length;
  List<QaUiBuildSample> get worstSamples =>
      List<QaUiBuildSample>.of(_worst)
        ..sort((a, b) => b.durationUs.compareTo(a.durationUs));

  void record(int durationUs, {required bool debugVisible,
      required int msAfterNavigation}) {
    if (durationUs < 0) return;
    samples++;
    _sumUs += durationUs;
    if (durationUs > worstUs) worstUs = durationUs;
    if (durationUs > budgetUs) overBudget++;
    if (durationUs <= budgetUs) return;
    var replacement = -1;
    if (_worst.length == worstCapacity) {
      replacement = 0;
      for (var i = 1; i < _worst.length; i++) {
        if (_worst[i].durationUs < _worst[replacement].durationUs) {
          replacement = i;
        }
      }
      if (durationUs <= _worst[replacement].durationUs) return;
    }
    final sample = QaUiBuildSample(
        samples, durationUs, debugVisible, msAfterNavigation);
    if (replacement < 0) {
      _worst.add(sample);
    } else {
      _worst[replacement] = sample;
    }
  }

  void reset() {
    samples = 0;
    overBudget = 0;
    worstUs = 0;
    _sumUs = 0;
    _worst.clear();
  }
}

/// Measures ONLY selected synchronous Dart builder bodies, NOT total Flutter
/// build/layout/paint/raster or physical display presentation.
class QaUiBuildStats {
  final Stopwatch _clock = Stopwatch()..start();
  final Map<QaUiBuildStage, QaUiStageStats> _stages = {
    for (final s in QaUiBuildStage.values) s: QaUiStageStats()
  };
  bool debugVisible = false;
  int opens = 0, closes = 0, openPostFrames = 0, closePostFrames = 0;
  int lastOpenPostFrameMs = -1, lastClosePostFrameMs = -1;
  int _lastNavigationUs = -1;
  final List<String> _events = <String>[];

  QaUiStageStats stage(QaUiBuildStage s) => _stages[s]!;

  int begin(QaUiBuildStage s) {
    Timeline.startSync('TJ45G_${s.name}');
    return _clock.elapsedMicroseconds;
  }

  void end(QaUiBuildStage s, int startedUs) {
    final now = _clock.elapsedMicroseconds;
    try {
      _stages[s]!.record(now - startedUs,
          debugVisible: debugVisible,
          msAfterNavigation: _lastNavigationUs == -1
              ? -1 : (now - _lastNavigationUs) ~/ 1000);
    } finally {
      Timeline.finishSync();
    }
  }

  void navigationRequest({required bool opening}) {
    debugVisible = opening;
    _lastNavigationUs = _clock.elapsedMicroseconds;
    if (opening) { opens++; } else { closes++; }
    final name = opening ? 'debugOpenRequest' : 'debugCloseRequest';
    Timeline.instantSync('TJ45G_$name');
    _event('$name atElapsedMs=${_lastNavigationUs ~/ 1000}');
  }

  /// Post-frame means Flutter finished its frame callbacks, NOT panel present.
  void navigationPostFrame({required bool opening}) {
    final now = _clock.elapsedMicroseconds;
    final ms = _lastNavigationUs < 0 ? -1 : (now - _lastNavigationUs) ~/ 1000;
    if (opening) {
      openPostFrames++;
      lastOpenPostFrameMs = ms;
    } else {
      closePostFrames++;
      lastClosePostFrameMs = ms;
    }
    final name = opening ? 'debugOpenPostFrame' : 'debugClosePostFrame';
    Timeline.instantSync('TJ45G_$name');
    _event('$name afterRequestMs=$ms');
  }

  void _event(String s) {
    if (_events.length == 8) _events.removeAt(0);
    _events.add(s);
  }

  void reset() {
    for (final v in _stages.values) { v.reset(); }
    debugVisible = false;
    opens = closes = openPostFrames = closePostFrames = 0;
    lastOpenPostFrameMs = lastClosePostFrameMs = -1;
    _lastNavigationUs = -1;
    _events.clear();
    _clock..reset()..start();
  }

  String get reportFields {
    final lines = <String>[
      'qaUiBuildDiagnostic: enabled',
      'qaUiBuildScope: selectedWidgetBuildBodiesOnly-notWholeFlutterBuild',
      'qaUiBuildBudgetMs: 16.7',
      'qaUiDebugVisibleAtExport: $debugVisible',
      'qaUiDebugOpenRequests: $opens',
      'qaUiDebugCloseRequests: $closes',
      'qaUiDebugOpenPostFrameCount: $openPostFrames',
      'qaUiDebugClosePostFrameCount: $closePostFrames',
      'qaUiDebugLastOpenPostFrameMs: $lastOpenPostFrameMs',
      'qaUiDebugLastClosePostFrameMs: $lastClosePostFrameMs',
    ];
    for (final s in QaUiBuildStage.values) {
      final v = _stages[s]!;
      lines.add('qaUiBuild_${s.name}: samples=${v.samples} '
          'over16_7=${v.overBudget} avgMs=${v.averageMs.toStringAsFixed(3)} '
          'worstMs=${(v.worstUs / 1000).toStringAsFixed(2)}');
      final worst = v.worstSamples;
      for (var i = 0; i < worst.length; i++) {
        final w = worst[i];
        lines.add('qaUiBuildWorst_${s.name}[$i]: sample=${w.index} '
            'durationMs=${(w.durationUs / 1000).toStringAsFixed(2)} '
            'debugVisible=${w.debugVisible} '
            'msAfterNavigation=${w.msAfterNavigation}');
      }
    }
    for (var i = 0; i < _events.length; i++) {
      lines.add('qaUiNavigation[$i]: ${_events[i]}');
    }
    return lines.join('\n');
  }
}
