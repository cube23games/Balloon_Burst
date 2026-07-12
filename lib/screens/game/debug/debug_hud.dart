import 'package:flutter/material.dart';

class DebugHud extends StatelessWidget {
  final double fps;
  final double speedMultiplier;
  final int world;
  final int balloonCount;
  final double recentAccuracy; // 0..1
  final double runAccuracy; // 0..1
  final int recentMisses;

  const DebugHud({
    super.key,
    required this.fps,
    required this.speedMultiplier,
    required this.world,
    required this.balloonCount,
    required this.recentAccuracy,
    required this.runAccuracy,
    required this.recentMisses,
  });

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'FPS: ${fps.toStringAsFixed(0)}',
      'Combined Speed: ${speedMultiplier.toStringAsFixed(2)}x',
      'World: $world',
      'Balloons: $balloonCount',
      'Tap Accuracy: ${(recentAccuracy * 100).toStringAsFixed(0)}%',
      'Run Accuracy: ${(runAccuracy * 100).toStringAsFixed(0)}%',
      'Miss streak: $recentMisses',
    ];

    return Positioned(
      top: 12,
      left: 12,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.25,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map((t) => Text(t)).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
