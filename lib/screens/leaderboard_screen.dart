import 'package:flutter/material.dart';
import 'package:balloon_burst/tj_engine/engine/tj_engine.dart';
import 'package:balloon_burst/tj_engine/engine/leaderboard/leaderboard_entry.dart';

class LeaderboardScreen extends StatefulWidget {
  final TJEngine engine;

  const LeaderboardScreen({
    super.key,
    required this.engine,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 2.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _accuracyRank(double accuracy) {
    if (accuracy >= 0.95) return 'S';
    if (accuracy >= 0.90) return 'A';
    if (accuracy >= 0.80) return 'B';
    return 'C';
  }

  String _rankLabel(String rank) {
    switch (rank) {
      case 'S':
        return '🏆 TapJunkie';
      case 'A':
        return '🥇 Tap Pro';
      case 'B':
        return '🥈 Tap Skilled';
      default:
        return '🥉 Tap Rookie';
    }
  }

  Color _rankColor(String rank) {
    switch (rank) {
      case 'S':
        return Colors.amber;
      case 'A':
        return Colors.cyanAccent;
      case 'B':
        return const Color(0xFFB0C4DE);
      default:
        return Colors.white70;
    }
  }

  Color _prestigeBorderColor(int world) {
    switch (world) {
      case 4:
        return const Color(0xFFFFD700);
      case 3:
        return const Color(0xFFFF3DFF);
      case 2:
        return const Color(0xFF00E5FF);
      default:
        return const Color(0xFF1E88E5);
    }
  }

  Color _prestigeBackground(int world) {
    switch (world) {
      case 4:
        return const Color(0xFF2B1F05);
      case 3:
        return const Color(0xFF1B0F2F);
      case 2:
        return const Color(0xFF0E1E2F);
      default:
        return const Color(0xFF13183F);
    }
  }

  Widget _buildBrandHeader() {
    return Column(
      children: const [
        Text(
          'TAPJUNKIE GAMES',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'BALLOON BURST',
          style: TextStyle(
            color: Color(0xFF00D8FF),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Rank tiers: 🏆 TapJunkie • 🥇 Tap Pro • 🥈 Tap Skilled • 🥉 Tap Rookie',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildEntryTile(LeaderboardEntry e, int rank) {
    final world = e.worldReached;
    final borderColor = _prestigeBorderColor(world);
    final background = _prestigeBackground(world);
    final rankCode = _accuracyRank(e.accuracy01);
    final rankText = _rankLabel(rankCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank == 1 && world >= 2 ? borderColor : Colors.white10,
          width: rank == 1 && world >= 2 ? _pulse.value : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: rank == 1 ? borderColor : Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e.score} Bursts • $rankText',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _rankColor(rankCode),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'World ${e.worldReached} • '
                  'Acc ${(e.accuracy01 * 100).toStringAsFixed(0)}% • '
                  'Streak ${e.bestStreak}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.engine.leaderboard.entries.take(10).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F2F),
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        backgroundColor: const Color(0xFF0B0F2F),
        elevation: 0,
        title: const Text(
          'LEADERBOARD',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                'No runs yet.\nBe the first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            )
          : AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  itemCount: entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 18,
                          left: 4,
                          right: 4,
                        ),
                        child: _buildBrandHeader(),
                      );
                    }

                    final e = entries[index - 1];
                    final rank = index;
                    return _buildEntryTile(e, rank);
                  },
                );
              },
            ),
    );
  }
}
