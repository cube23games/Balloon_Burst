/// Skyward Journey: World 1 level rules (TJ-44A).
///
/// Pure Dart on purpose. The existing endless arcade gameplay stays unchanged
/// until the new level mode is wired and separately QA-tested.
enum SkywardHazard { leadBalloon, microburst, ribbonChain }

class SkywardLevelDefinition {
  final int number;
  final String title;
  final int popsRequired;
  final int leadCatchesRequired;
  final int comboRequired;
  final int chainReactionsRequired;
  final int maxEscapes;
  final Set<SkywardHazard> hazards;
  final bool unlocksCarnival;

  const SkywardLevelDefinition({
    required this.number,
    required this.title,
    required this.popsRequired,
    this.leadCatchesRequired = 0,
    this.comboRequired = 0,
    this.chainReactionsRequired = 0,
    this.maxEscapes = 2,
    this.hazards = const <SkywardHazard>{},
    this.unlocksCarnival = false,
  })  : assert(number >= 1 && number <= 8),
        assert(popsRequired > 0),
        assert(leadCatchesRequired >= 0),
        assert(comboRequired >= 0),
        assert(chainReactionsRequired >= 0),
        assert(maxEscapes >= 0);
}

class SkywardWorldOne {
  SkywardWorldOne._();

  /// Each level introduces one new idea before combining mechanics.
  /// These are design calibration values, not the old World 1-4 speed curve.
  static const List<SkywardLevelDefinition> levels = [
    SkywardLevelDefinition(
      number: 1,
      title: 'First Flight',
      popsRequired: 12,
    ),
    SkywardLevelDefinition(
      number: 2,
      title: 'Cloud Combos',
      popsRequired: 20,
      comboRequired: 6,
    ),
    SkywardLevelDefinition(
      number: 3,
      title: 'Whistle Drop',
      popsRequired: 20,
      leadCatchesRequired: 2,
      hazards: <SkywardHazard>{SkywardHazard.leadBalloon},
    ),
    SkywardLevelDefinition(
      number: 4,
      title: 'Crosswind Alley',
      popsRequired: 24,
      leadCatchesRequired: 2,
      hazards: <SkywardHazard>{
        SkywardHazard.leadBalloon,
        SkywardHazard.microburst,
      },
    ),
    SkywardLevelDefinition(
      number: 5,
      title: 'Ribbon Reaction',
      popsRequired: 25,
      chainReactionsRequired: 2,
      hazards: <SkywardHazard>{SkywardHazard.ribbonChain},
    ),
    SkywardLevelDefinition(
      number: 6,
      title: 'Spiraling Skies',
      popsRequired: 28,
      chainReactionsRequired: 2,
      hazards: <SkywardHazard>{
        SkywardHazard.microburst,
        SkywardHazard.ribbonChain,
      },
    ),
    SkywardLevelDefinition(
      number: 7,
      title: 'Leadstorm',
      popsRequired: 30,
      leadCatchesRequired: 3,
      chainReactionsRequired: 2,
      hazards: <SkywardHazard>{
        SkywardHazard.leadBalloon,
        SkywardHazard.microburst,
        SkywardHazard.ribbonChain,
      },
    ),
    SkywardLevelDefinition(
      number: 8,
      title: 'Carnival Gate',
      popsRequired: 36,
      leadCatchesRequired: 3,
      chainReactionsRequired: 3,
      maxEscapes: 1,
      hazards: <SkywardHazard>{
        SkywardHazard.leadBalloon,
        SkywardHazard.microburst,
        SkywardHazard.ribbonChain,
      },
      unlocksCarnival: true,
    ),
  ];

  static SkywardLevelDefinition level(int number) {
    if (number < 1 || number > levels.length) {
      throw RangeError.range(number, 1, levels.length, 'number');
    }
    return levels[number - 1];
  }
}

/// One level attempt. Calls should come from confirmed gameplay events, not
/// frames. A chain reaction counts all popped balloons but only one tap.
class SkywardLevelRun {
  final SkywardLevelDefinition level;

  int popped = 0;
  int leadCatches = 0;
  int chainReactions = 0;
  int successfulTaps = 0;
  int currentCombo = 0;
  int bestCombo = 0;
  int missedTaps = 0;
  int escaped = 0;

  SkywardLevelRun(this.level);

  bool get isFailed => escaped > level.maxEscapes;

  bool get isComplete =>
      !isFailed &&
      popped >= level.popsRequired &&
      bestCombo >= level.comboRequired &&
      leadCatches >= level.leadCatchesRequired &&
      chainReactions >= level.chainReactionsRequired;

  double get tapAccuracy {
    final totalTaps = successfulTaps + missedTaps;
    return totalTaps == 0 ? 0.0 : successfulTaps / totalTaps;
  }

  int get stars {
    if (!isComplete) return 0;
    var count = 1;
    if (tapAccuracy >= 0.88) count++;
    if (escaped == 0 && tapAccuracy >= 0.95) count++;
    return count;
  }

  void recordPop({
    int balloonsPopped = 1,
    bool leadCaught = false,
    bool triggeredChain = false,
  }) {
    if (balloonsPopped < 1) {
      throw ArgumentError.value(balloonsPopped, 'balloonsPopped');
    }
    if (isFailed || isComplete) return;
    successfulTaps++;
    currentCombo++;
    if (currentCombo > bestCombo) bestCombo = currentCombo;
    popped += balloonsPopped;
    if (leadCaught) leadCatches++;
    if (triggeredChain) chainReactions++;
  }

  void recordMiss() {
    if (isFailed || isComplete) return;
    missedTaps++;
    currentCombo = 0;
  }

  void recordEscape() {
    if (isFailed || isComplete) return;
    escaped++;
    currentCombo = 0;
  }
}

/// Local, eight-level unlock rules. No wallet, account, or persistent
/// storage is touched here; integrating save data is a separate milestone.
class SkywardWorldOneProgress {
  final List<int> _bestStars;

  SkywardWorldOneProgress()
      : _bestStars = List<int>.filled(SkywardWorldOne.levels.length, 0);

  /// Defensive restore: clamp star values and discard unlocks after gaps.
  factory SkywardWorldOneProgress.fromSaved(List<int> saved) {
    final progress = SkywardWorldOneProgress();
    for (var i = 0; i < progress._bestStars.length; i++) {
      if (i > 0 && progress._bestStars[i - 1] == 0) break;
      progress._bestStars[i] =
          i < saved.length ? saved[i].clamp(0, 3).toInt() : 0;
    }
    return progress;
  }

  List<int> get bestStars => List<int>.unmodifiable(_bestStars);

  int get totalStars => _bestStars.fold<int>(0, (sum, n) => sum + n);

  bool get worldComplete => _bestStars.every((stars) => stars > 0);

  bool get carnivalUnlocked => worldComplete;

  bool isLevelUnlocked(int number) {
    SkywardWorldOne.level(number); // Validate level number.
    return number == 1 || _bestStars[number - 2] > 0;
  }

  int get nextLevel {
    final firstUncleared = _bestStars.indexOf(0);
    return firstUncleared == -1 ? SkywardWorldOne.levels.length : firstUncleared + 1;
  }

  void submit(SkywardLevelRun run) {
    final number = run.level.number;
    if (!identical(run.level, SkywardWorldOne.level(number))) {
      throw ArgumentError('Only official World 1 levels are accepted');
    }
    if (!isLevelUnlocked(number)) {
      throw StateError('Level $number is locked');
    }
    if (!run.isComplete) {
      throw StateError('Cannot submit an unfinished level');
    }
    final index = number - 1;
    if (run.stars > _bestStars[index]) _bestStars[index] = run.stars;
  }
}
