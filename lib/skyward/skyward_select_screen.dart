import 'package:flutter/material.dart';
import 'package:balloon_burst/skyward/world_one.dart';

/// World 1 map. Only levels with implemented gameplay are selectable.
class SkywardSelectScreen extends StatelessWidget {
  final SkywardWorldOneProgress progress;
  final ValueChanged<int> onSelectLevel;
  final VoidCallback onBack;

  const SkywardSelectScreen({
    super.key,
    required this.progress,
    required this.onSelectLevel,
    required this.onBack,
  });

  static const int playableThrough = 7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1730),
      appBar: AppBar(
        title: const Text('SKYWARD JOURNEY'),
        backgroundColor: const Color(0xFF101F3B),
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Back to main menu',
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'WORLD 1 · OPEN SKIES',
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.totalStars} / 24 stars earned',
              style: const TextStyle(color: Color(0xFFFFDB6F), fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Leadstorm combines whistling lead balloons, crosswinds and floating '
              'ribbon chains. Clear each challenge to unlock the next.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            for (final level in SkywardWorldOne.levels) ...[
              _LevelTile(
                level: level,
                stars: progress.bestStars[level.number - 1],
                isUnlocked: progress.isLevelUnlocked(level.number),
                isImplemented: level.number <= playableThrough,
                onTap: () => onSelectLevel(level.number),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF182846),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_activity, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      progress.carnivalUnlocked
                          ? 'Carnival Gate unlocked — minigame coming later'
                          : 'Carnival Gate — complete all eight levels to unlock',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final SkywardLevelDefinition level;
  final int stars;
  final bool isUnlocked;
  final bool isImplemented;
  final VoidCallback onTap;

  const _LevelTile({
    required this.level,
    required this.stars,
    required this.isUnlocked,
    required this.isImplemented,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = isUnlocked && isImplemented;
    final subtitle = !isImplemented
        ? 'In development'
        : isUnlocked
            ? '${level.popsRequired} pops  ·  '
                '${level.comboRequired > 0 ? 'Combo ${level.comboRequired}  ·  ' : ''}'
                '${level.leadCatchesRequired > 0 ? 'Lead ${level.leadCatchesRequired}  ·  ' : ''}'
                '${level.chainReactionsRequired > 0 ? 'Chains ${level.chainReactionsRequired}  ·  ' : ''}'
                'Max ${level.maxEscapes} escapes'
            : 'Complete the previous level';
    return Card(
      color: available ? const Color(0xFF204B70) : const Color(0xFF1B2840),
      margin: EdgeInsets.zero,
      child: ListTile(
        enabled: available,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: available
              ? const Color(0xFF00D7FF)
              : const Color(0xFF46536B),
          child: Text(
            '${level.number}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          level.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: available
            ? Text(
                stars == 0 ? 'PLAY' : '${List<String>.filled(stars, '★').join()}${List<String>.filled(3 - stars, '☆').join()}',
                style: const TextStyle(color: Color(0xFFFFDB6F)),
              )
            : const Icon(Icons.lock_outline, color: Colors.white54),
        onTap: available ? onTap : null,
      ),
    );
  }
}
