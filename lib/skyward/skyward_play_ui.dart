import 'package:flutter/material.dart';
import 'package:balloon_burst/skyward/world_one.dart';

class SkywardObjectiveHud extends StatelessWidget {
  final SkywardLevelRun run;
  final bool leadWarning;
  final bool windWarning;
  final bool windGusting;
  final int windDirection;
  final VoidCallback onExit;

  const SkywardObjectiveHud({
    super.key,
    required this.run,
    this.leadWarning = false,
    this.windWarning = false,
    this.windGusting = false,
    this.windDirection = 1,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final level = run.level;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 45, 12, 0),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xDC0C2340),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Exit to level map',
                onPressed: onExit,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LEVEL ${level.number} · ${level.title}',
                      style: const TextStyle(
                        color: Color(0xFFFFDB6F),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'POPS ${run.popped}/${level.popsRequired}   '
                      'ESCAPES ${run.escaped}/${level.maxEscapes}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    if (level.comboRequired > 0)
                      Text(
                        'BEST COMBO ${run.bestCombo}/${level.comboRequired}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (leadWarning)
                      const Text(
                        '↓ WHISTLE! LEAD INCOMING',
                        style: TextStyle(
                          color: Color(0xFFFFCC4D),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (windWarning || windGusting)
                      Text(
                        windWarning
                            ? '${windDirection > 0 ? '→' : '←'} CROSSWIND INCOMING'
                            : '${windDirection > 0 ? '→' : '←'} GUST! KEEP YOUR AIM',
                        key: const ValueKey('skyward-wind-warning'),
                        style: TextStyle(
                          color: windGusting
                              ? const Color(0xFF89F7FF)
                              : const Color(0xFFFFE082),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (level.leadCatchesRequired > 0)
                      Text(
                        'LEAD ${run.leadCatches}/${level.leadCatchesRequired}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (level.chainReactionsRequired > 0)
                      Text(
                        'CHAINS ${run.chainReactions}/${level.chainReactionsRequired}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkywardResultOverlay extends StatelessWidget {
  final SkywardLevelRun run;
  final VoidCallback onReplay;
  final VoidCallback onMap;
  final VoidCallback? onNext;

  const SkywardResultOverlay({
    super.key,
    required this.run,
    required this.onReplay,
    required this.onMap,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final won = run.isComplete;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xE90B1425),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      won ? Icons.emoji_events : Icons.refresh,
                      color: won ? Colors.amberAccent : Colors.cyanAccent,
                      size: 68,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      won ? 'LEVEL CLEARED!' : 'TRY AGAIN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${run.level.number}. ${run.level.title}',
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    if (won)
                      Text(
                        '${List<String>.filled(run.stars, '★').join()}${List<String>.filled(3 - run.stars, '☆').join()}',
                        style: const TextStyle(
                          color: Color(0xFFFFDB6F),
                          fontSize: 42,
                          letterSpacing: 5,
                        ),
                      ),
                    Text(
                      '${run.popped} pops · ${(run.tapAccuracy * 100).toStringAsFixed(0)}% tap accuracy',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '${run.escaped} escaped',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    if (won && onNext != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onNext,
                          child: const Text('NEXT LEVEL'),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onReplay,
                        child: const Text('REPLAY LEVEL'),
                      ),
                    ),
                    TextButton(
                      onPressed: onMap,
                      child: const Text(
                        'LEVEL MAP',
                        style: TextStyle(color: Colors.cyanAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
