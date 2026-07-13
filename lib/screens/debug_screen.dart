import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:balloon_burst/debug/debug_controller.dart'; // kept for compatibility with AppRoot
import 'package:balloon_burst/debug/debug_log.dart';
import 'package:balloon_burst/game/game_state.dart';
import 'package:balloon_burst/game/balloon_spawner.dart';

class DebugScreen extends StatefulWidget {
  final GameState gameState;
  final BalloonSpawner spawner;

  // NOTE: AppRoot still passes this. We keep it so we don't have to touch AppRoot yet.
  // ignore: unused_field
  final DebugController debug;

  final VoidCallback onClose;

  const DebugScreen({
    super.key,
    required this.gameState,
    required this.spawner,
    required this.debug,
    required this.onClose,
  });

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  static const int _displayedLogLimit = 100;

  String _buildDetailedReport(List<String> rawLogs) {
    final generatedAt = DateTime.now().toIso8601String();

    return '''
BALLOON BURST DEBUG REPORT
generatedAt: $generatedAt

SUMMARY
world: ${widget.spawner.currentWorld}
frame: ${widget.gameState.framesSinceStart}
totalPops: ${widget.spawner.totalPops}
worldSpeedBaseMultiplier: ${widget.spawner.worldSpeedBaseMultiplier.toStringAsFixed(2)}
worldRampMultiplier: ${widget.spawner.worldRampMultiplier.toStringAsFixed(2)}
accuracySpeedMultiplier: ${widget.spawner.accuracyModifier.toStringAsFixed(2)}
engineSpeedMultiplier: ${widget.spawner.engineSpeedMultiplier.toStringAsFixed(2)}
combinedSpeedMultiplier: ${widget.spawner.combinedSpeedMultiplier.toStringAsFixed(2)}
nominalRiseSpeedPxPerSecond: ${widget.spawner.nominalRiseSpeed.toStringAsFixed(1)}
minimumRiseSpeedPxPerSecond: ${widget.spawner.minimumRiseSpeed.toStringAsFixed(1)}
maximumRiseSpeedPxPerSecond: ${widget.spawner.maximumRiseSpeed.toStringAsFixed(1)}
worldSpawnTargetInterval: ${widget.spawner.worldSpawnTargetInterval.toStringAsFixed(2)}
adaptiveEngineSpawnInterval: ${widget.spawner.adaptiveEngineSpawnInterval.toStringAsFixed(2)}
adaptiveSpawnFactor: ${widget.spawner.adaptiveSpawnFactor.toStringAsFixed(2)}
targetSpawnInterval: ${widget.spawner.targetSpawnInterval.toStringAsFixed(2)}
easedSpawnInterval: ${widget.spawner.spawnInterval.toStringAsFixed(2)}
effectiveSpawnInterval: ${widget.spawner.effectiveSpawnInterval.toStringAsFixed(2)}
spawnFloor: ${widget.spawner.spawnFloor.toStringAsFixed(2)}
spawnVariance: ${widget.spawner.spawnVariance.toStringAsFixed(2)}
lastSpawnBatch: ${widget.spawner.lastSpawnBatch}
engineElapsedSeconds: ${widget.spawner.engineElapsedSeconds.toStringAsFixed(1)}
runId: ${widget.gameState.runId}
runState: ${widget.gameState.runStateLabel}
endReason: ${widget.gameState.runEndReasonLabel}
currentLifecycleMisses: ${widget.gameState.runMisses}
currentLifecycleEscapes: ${widget.gameState.runEscapes}
totalMissesAcrossRevives: ${widget.gameState.totalMissesObserved}
totalEscapesAcrossRevives: ${widget.gameState.totalEscapesCounted}
bestStreak: ${widget.gameState.runBestStreak}
accuracy: ${widget.gameState.runAccuracy01.toStringAsFixed(4)}
shieldActiveNow: ${widget.gameState.shieldActiveNow}
shieldActivations: ${widget.gameState.shieldActivations}
shieldAbsorptions: ${widget.gameState.shieldAbsorptions}
shieldEscapesPrevented: ${widget.gameState.shieldEscapesPrevented}
mercyEscapesPrevented: ${widget.gameState.mercyEscapesPrevented}
revivesUsed: ${widget.gameState.revivesUsed}
autoTap: ${widget.gameState.autoTapEnabled}
autoTapMode: ${widget.gameState.autoTapModeLabel}
autoTapEverEnabled: ${widget.gameState.autoTapEverEnabled}
autoTapActivationCount: ${widget.gameState.autoTapActivationCount}
autoTapModeChangeCount: ${widget.gameState.autoTapModeChangeCount}
performanceHitches: ${widget.gameState.perfHitchCount}
maximumCombinedSpeedMultiplier: ${widget.gameState.maxCombinedSpeedMultiplier.toStringAsFixed(2)}
minimumEffectiveSpawnInterval: ${widget.gameState.minimumEffectiveSpawnInterval.isInfinite ? 'n/a' : widget.gameState.minimumEffectiveSpawnInterval.toStringAsFixed(2)}
maximumSpawnBatch: ${widget.gameState.maximumSpawnBatch}
debugFrozen: ${widget.gameState.debugFrozen}
exportedLogCount: ${rawLogs.length}
displayedLogCount: ${rawLogs.length < _displayedLogLimit ? rawLogs.length : _displayedLogLimit}
displayedLogLimit: $_displayedLogLimit
logCapacity: ${widget.gameState.debugLogCapacity}
logBufferFull: ${rawLogs.length >= widget.gameState.debugLogCapacity}

NOTES
PERF SNAP = periodic performance snapshot.
PERF HITCH = a frame gap large enough to be noticed.
TAP DOWN / TAP RESULT = input and result tracing.

LOGS CHRONOLOGICAL
${rawLogs.join('\n')}
''';
  }

  Future<void> _copyDetailedReport(List<String> rawLogs) async {
    final report = _buildDetailedReport(rawLogs);

    await Clipboard.setData(ClipboardData(text: report));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Detailed debug report copied')),
    );
  }

  Future<void> _shareDetailedReport(List<String> rawLogs) async {
    final report = _buildDetailedReport(rawLogs);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    final file = File('${dir.path}/balloon_burst_debug_$stamp.txt');
    await file.writeAsString(report);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Balloon Burst Debug Report',
      text: 'Balloon Burst detailed debug report',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Authoritative logs now come from GameState -> DebugLog
    final rawLogs = widget.gameState.debugLogs;
    final logs = rawLogs.reversed
        .take(_displayedLogLimit)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug HUD'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onClose,
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.gameState.debugFrozen ? Icons.play_arrow : Icons.pause,
            ),
            tooltip:
                widget.gameState.debugFrozen ? 'Resume logging' : 'Freeze logging',
            onPressed: () {
              setState(() {
                widget.gameState.toggleFreeze();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () {
              setState(() {
                widget.gameState.clearLogs();
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SUMMARY ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'World: ${widget.spawner.currentWorld}\n'
              'Frame: ${widget.gameState.framesSinceStart}\n'
              'Total Pops: ${widget.spawner.totalPops}\n'
              'World Speed: ${widget.spawner.worldSpeedBaseMultiplier.toStringAsFixed(2)}x\n'
              'World Ramp: ${widget.spawner.worldRampMultiplier.toStringAsFixed(2)}x\n'
              'Accuracy Speed: ${widget.spawner.accuracyModifier.toStringAsFixed(2)}x\n'
              'Engine Speed: ${widget.spawner.engineSpeedMultiplier.toStringAsFixed(2)}x\n'
              'Combined Speed: ${widget.spawner.combinedSpeedMultiplier.toStringAsFixed(2)}x\n'
              'Rise: ${widget.spawner.nominalRiseSpeed.toStringAsFixed(0)} '
              '(${widget.spawner.minimumRiseSpeed.toStringAsFixed(0)}'
              '..${widget.spawner.maximumRiseSpeed.toStringAsFixed(0)}) px/s\n'
              'World Spawn: ${widget.spawner.worldSpawnTargetInterval.toStringAsFixed(2)}s\n'
              'Adaptive Engine Spawn: ${widget.spawner.adaptiveEngineSpawnInterval.toStringAsFixed(2)}s\n'
              'Spawn Target: ${widget.spawner.targetSpawnInterval.toStringAsFixed(2)}s\n'
              'Spawn Eased: ${widget.spawner.spawnInterval.toStringAsFixed(2)}s\n'
              'Effective Spawn: ${widget.spawner.effectiveSpawnInterval.toStringAsFixed(2)}s\n'
              'Spawn Floor: ${widget.spawner.spawnFloor.toStringAsFixed(2)}s\n'
              'Last Cluster: ${widget.spawner.lastSpawnBatch}\n'
              'Run Seconds: ${widget.spawner.engineElapsedSeconds.toStringAsFixed(0)}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),

          if (kDebugMode || kEnableQaAutoTap) ...[
            // --- QA AUTO TAP ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text(
                      'AUTO: ${widget.gameState.autoTapEnabled ? 'ON' : 'OFF'}',
                    ),
                    selected: widget.gameState.autoTapEnabled,
                    onSelected: (_) {
                      setState(() {
                        widget.gameState.toggleAutoTap();
                      });
                    },
                  ),
                  ActionChip(
                    label: Text('MODE: ${widget.gameState.autoTapModeLabel}'),
                    onPressed: () {
                      setState(() {
                        widget.gameState.cycleAutoTapMode();
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

          ],

          // --- FILTERS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DebugEventType.values.map((type) {
                final enabled = widget.gameState.enabledFilters.contains(type);

                return FilterChip(
                  label: Text(type.name.toUpperCase()),
                  selected: enabled,
                  onSelected: (_) {
                    setState(() {
                      if (enabled) {
                        widget.gameState.enabledFilters.remove(type);
                      } else {
                        widget.gameState.enabledFilters.add(type);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // --- EXPORT BUTTONS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Detailed Report'),
                  onPressed: () => _copyDetailedReport(rawLogs),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share Text File'),
                  onPressed: () => _shareDetailedReport(rawLogs),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // --- LOG VIEW ---
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              color: Colors.black.withOpacity(0.05),
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs yet',
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    )
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        return Text(
                          logs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
