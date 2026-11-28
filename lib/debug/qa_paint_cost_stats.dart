/// TJ-45O-A: bounded, sampled Dart painter-recording cost attribution.
/// CPU timing only: does NOT measure Flutter raster-thread/GPU work, and
/// cannot establish Android display-presentation timing.
class QaPaintCostStats {
  static const bool enabled =
      bool.fromEnvironment('TJ45O_PAINT_COST', defaultValue: false);
  static const int sampleEvery = 16;
  static const int maxCategories = 5;
  static const int maxRetainedSlow = 8;
  static const String balloon = 'balloon';
  static const String aura = 'aura';
  static const String particles = 'particles';
  static const String shockwaves = 'shockwaves';
  static const String scoreBursts = 'scoreBursts';
  static const List<String> categories = <String>[
    balloon, aura, particles, shockwaves, scoreBursts,
  ];

  final List<int> _calls = List<int>.filled(maxCategories, 0);
  final List<int> _samples = List<int>.filled(maxCategories, 0);
  final List<int> _totalUs = List<int>.filled(maxCategories, 0);
  final List<int> _worstUs = List<int>.filled(maxCategories, 0);
  final List<List<int>> _slowUs = List<List<int>>.generate(
    maxCategories, (_) => <int>[],
  );
  // Independent samples per category. A slow frame cannot be inferred by
  // combining individual samples from different frames.
  static const int overBudgetUs = 16667;

  int calls(String category) => _calls[categories.indexOf(category)];
  int samples(String category) => _samples[categories.indexOf(category)];
  int worstUs(String category) => _worstUs[categories.indexOf(category)];

  /// Optional painter probe. The callback always paints exactly once.
  /// Sampling is deterministic and never requests new Flutter frames.
  void measure(String category, void Function() paint) {
    if (!enabled) {
      paint();
      return;
    }
    final index = categories.indexOf(category);
    if (index < 0) {
      paint();
      return;
    }
    final invocation = ++_calls[index];
    if (invocation % sampleEvery != 0) {
      paint();
      return;
    }
    final watch = Stopwatch()..start();
    try {
      paint();
    } finally {
      watch.stop();
      final us = watch.elapsedMicroseconds;
      _samples[index]++;
      _totalUs[index] += us;
      if (us > _worstUs[index]) _worstUs[index] = us;
      if (us > overBudgetUs) {
        final slow = _slowUs[index];
        if (slow.length < maxRetainedSlow) {
          slow.add(us);
        } else {
          var minimum = 0;
          for (var i = 1; i < slow.length; i++) {
            if (slow[i] < slow[minimum]) minimum = i;
          }
          if (us > slow[minimum]) slow[minimum] = us;
        }
      }
    }
  }

  void reset() {
    for (var i = 0; i < maxCategories; i++) {
      _calls[i] = _samples[i] = _totalUs[i] = _worstUs[i] = 0;
      _slowUs[i].clear();
    }
  }

  String get reportFields {
    final lines = <String>[
      'qaPaintCostDiagnostic: ${enabled ? 'enabled' : 'disabled'}',
      'qaPaintCostScope: sampled-Dart-CustomPainter-CPU-recording-only-NOT-GPU',
      'qaPaintCostSampleEvery: $sampleEvery',
      'qaPaintCostCategoryCount: $maxCategories',
    ];
    for (var i = 0; i < maxCategories; i++) {
      final avg = _samples[i] == 0
          ? 0.0 : _totalUs[i] / (1000.0 * _samples[i]);
      final slow = List<int>.of(_slowUs[i])..sort((a, b) => b.compareTo(a));
      lines.add('qaPaintCost_${categories[i]}: calls=${_calls[i]} '
          'samples=${_samples[i]} avgMs=${avg.toStringAsFixed(3)} '
          'worstMs=${(_worstUs[i] / 1000).toStringAsFixed(3)} '
          'retainedOver16_7=${slow.length}');
    }
    return lines.join('\n');
  }
}
