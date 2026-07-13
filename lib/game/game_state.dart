import 'package:balloon_burst/debug/debug_log.dart';

/// App-level screen modes
enum ScreenMode {
  game,
  debug,
  blank,
}

/// Global game state shared across screens and systems
class GameState {
  // -------------------------------
  // Core runtime state
  // -------------------------------
  int framesSinceStart = 0;
  bool tapPulse = false;

  /// Updated by renderer every frame
  double viewportHeight = 0.0;

  // -------------------------------
  // App / screen routing state
  // -------------------------------
  ScreenMode screenMode = ScreenMode.game;

  // -------------------------------
  // QA auto tap shared state
  // -------------------------------
  bool autoTapEnabled = false;
  int autoTapModeIndex = 0;

  bool autoTapEverEnabled = false;
  int autoTapActivationCount = 0;
  int autoTapModeChangeCount = 0;

  String get autoTapModeLabel {
    switch (autoTapModeIndex) {
      case 1:
        return 'HUMAN';
      case 2:
        return 'FAIL';
      default:
        return 'CLEAN';
    }
  }

  void toggleAutoTap() {
    autoTapEnabled = !autoTapEnabled;

    if (autoTapEnabled) {
      autoTapEverEnabled = true;
      autoTapActivationCount++;
    }

    log(
      'ASSIST: AUTO TAP '
      '${autoTapEnabled ? 'ENABLED' : 'DISABLED'} '
      'mode=$autoTapModeLabel',
      type: DebugEventType.system,
    );
  }

  void cycleAutoTapMode() {
    autoTapModeIndex =
        (autoTapModeIndex + 1) % 3;

    autoTapModeChangeCount++;

    log(
      'ASSIST: AUTO TAP MODE '
      '$autoTapModeLabel',
      type: DebugEventType.system,
    );
  }

  // -------------------------------
  // Full-run QA evidence
  // -------------------------------
  String runId = '';
  String runStateLabel = 'idle';
  String runEndReasonLabel = 'none';

  int runMisses = 0;
  int runEscapes = 0;
  int runBestStreak = 0;
  double runAccuracy01 = 0.0;

  int _missesBeforeRevives = 0;
  int _escapesBeforeRevives = 0;

  int shieldActivations = 0;
  int shieldAbsorptions = 0;
  int shieldEscapesPrevented = 0;
  bool shieldActiveNow = false;

  int mercyEscapesPrevented = 0;
  int revivesUsed = 0;

  int perfHitchCount = 0;

  double maxCombinedSpeedMultiplier = 0.0;

  double minimumEffectiveSpawnInterval =
      double.infinity;

  int maximumSpawnBatch = 0;

  int get totalMissesObserved =>
      _missesBeforeRevives + runMisses;

  int get totalEscapesCounted =>
      _escapesBeforeRevives + runEscapes;

  int get debugLogCapacity =>
      DebugLog.maxLogs;

  void resetRunEvidence() {
    runId = '';
    runStateLabel = 'idle';
    runEndReasonLabel = 'none';

    runMisses = 0;
    runEscapes = 0;
    runBestStreak = 0;
    runAccuracy01 = 0.0;

    _missesBeforeRevives = 0;
    _escapesBeforeRevives = 0;

    shieldActivations = 0;
    shieldAbsorptions = 0;
    shieldEscapesPrevented = 0;
    shieldActiveNow = false;

    mercyEscapesPrevented = 0;
    revivesUsed = 0;

    perfHitchCount = 0;

    maxCombinedSpeedMultiplier = 0.0;

    minimumEffectiveSpawnInterval =
        double.infinity;

    maximumSpawnBatch = 0;

    autoTapEverEnabled = autoTapEnabled;

    autoTapActivationCount =
        autoTapEnabled ? 1 : 0;

    autoTapModeChangeCount = 0;
  }

  void syncRunEvidence({
    required String runId,
    required String state,
    required String endReason,
    required int misses,
    required int escapes,
    required int bestStreak,
    required double accuracy01,
    required bool shieldActive,
  }) {
    this.runId = runId;
    runStateLabel = state;
    runEndReasonLabel = endReason;
    runMisses = misses;
    runEscapes = escapes;
    runBestStreak = bestStreak;
    runAccuracy01 = accuracy01;
    shieldActiveNow = shieldActive;
  }

  void recordDifficultyEvidence({
    required double combinedSpeedMultiplier,
    required double effectiveSpawnInterval,
    required int spawnBatch,
    required int hitches,
  }) {
    if (combinedSpeedMultiplier >
        maxCombinedSpeedMultiplier) {
      maxCombinedSpeedMultiplier =
          combinedSpeedMultiplier;
    }

    if (effectiveSpawnInterval > 0 &&
        effectiveSpawnInterval <
            minimumEffectiveSpawnInterval) {
      minimumEffectiveSpawnInterval =
          effectiveSpawnInterval;
    }

    if (spawnBatch > maximumSpawnBatch) {
      maximumSpawnBatch = spawnBatch;
    }

    perfHitchCount = hitches;
  }

  void recordShieldActivation({
    required int world,
    required int pops,
    required double runSeconds,
  }) {
    shieldActivations++;
    shieldActiveNow = true;

    log(
      'ASSIST: SHIELD ACTIVE '
      'world=$world '
      'pops=$pops '
      'runSec=${runSeconds.toStringAsFixed(1)}',
      type: DebugEventType.system,
    );
  }

  void recordShieldAbsorption({
    required int escapesPrevented,
    required int world,
    required int pops,
    required double runSeconds,
  }) {
    shieldAbsorptions++;
    shieldEscapesPrevented +=
        escapesPrevented;

    shieldActiveNow = false;

    log(
      'ASSIST: SHIELD ABSORBED ESCAPE '
      'count=$escapesPrevented '
      'world=$world '
      'pops=$pops '
      'runSec=${runSeconds.toStringAsFixed(1)}',
      type: DebugEventType.system,
    );
  }

  void recordMercyEscapePrevention({
    required int escapesPrevented,
    required int world,
    required int pops,
    required double runSeconds,
  }) {
    mercyEscapesPrevented +=
        escapesPrevented;

    log(
      'ASSIST: MERCY POP PREVENTED ESCAPE '
      'count=$escapesPrevented '
      'world=$world '
      'pops=$pops '
      'runSec=${runSeconds.toStringAsFixed(1)}',
      type: DebugEventType.system,
    );
  }

  void recordRevive({
    required int missesBeforeReset,
    required int escapesBeforeReset,
    required int world,
    required int pops,
    required double runSeconds,
  }) {
    _missesBeforeRevives +=
        missesBeforeReset;

    _escapesBeforeRevives +=
        escapesBeforeReset;

    revivesUsed++;

    log(
      'ASSIST: REVIVE USED '
      'world=$world '
      'pops=$pops '
      'missesBeforeReset=$missesBeforeReset '
      'escapesBeforeReset=$escapesBeforeReset '
      'runSec=${runSeconds.toStringAsFixed(1)}',
      type: DebugEventType.system,
    );
  }

  // -------------------------------
  // DEBUG LOG FORWARDING
  // -------------------------------
  List<String> get debugLogs =>
      DebugLog.instance.logs.toList();

  bool get debugFrozen =>
      DebugLog.instance.debugFrozen;

  Set<DebugEventType> get enabledFilters =>
      DebugLog.instance.enabledFilters;

  void log(
    String message, {
    DebugEventType type =
        DebugEventType.system,
  }) {
    DebugLog.instance.log(
      message,
      type: type,
    );
  }

  void clearLogs() {
    DebugLog.instance.clear();
  }

  void toggleFreeze() {
    DebugLog.instance.toggleFreeze();
  }
}
