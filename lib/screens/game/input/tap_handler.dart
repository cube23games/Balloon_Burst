import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:balloon_burst/game/game_state.dart';
import 'package:balloon_burst/game/game_controller.dart';
import 'package:balloon_burst/game/balloon_spawner.dart';
import 'package:balloon_burst/gameplay/balloon.dart';
import 'package:balloon_burst/screens/game/effects/world_surge_pulse.dart';

class TapHandler {
  static const bool _verboseTapLogging = false;

  static void handleTap({
    required TapDownDetails details,
    required Size lastSize,
    required List<Balloon> balloons,
    required GameState gameState,
    required BalloonSpawner spawner,
    required GameController controller,
    required WorldSurgePulse surge,
    required double balloonRadius,
    required double hitForgiveness,
  }) {
    handleTapAt(
      tapPos: details.localPosition,
      lastSize: lastSize,
      balloons: balloons,
      gameState: gameState,
      spawner: spawner,
      controller: controller,
      surge: surge,
      balloonRadius: balloonRadius,
      hitForgiveness: hitForgiveness,
    );
  }

  static void handleTapAt({
    required Offset tapPos,
    required Size lastSize,
    required List<Balloon> balloons,
    required GameState gameState,
    required BalloonSpawner spawner,
    required GameController controller,
    required WorldSurgePulse surge,
    required double balloonRadius,
    required double hitForgiveness,
  }) {
    if (lastSize == Size.zero) return;

    final centerX = lastSize.width * 0.5;
    final widthHalf = lastSize.width * 0.5;

    bool hit = false;
    bool perfectHit = false;

    double? closestScore;
    double? closestDist;
    double? closestDx;
    double? closestDy;
    double? closestBx;
    double? closestBy;

    int? bestHitIndex;
    double? bestHitDist;
    double? bestHitScore;

    for (int i = 0; i < balloons.length; i++) {
      final b = balloons[i];
      if (b.isPopped) continue;

      final bx = centerX + (b.xOffset * widthHalf);
      final by = b.y;

      final dx = tapPos.dx - bx;
      final dy = tapPos.dy - by;

      final dist = sqrt(dx * dx + dy * dy);
      final centerBias = dx.abs();
      final tapScore = dist + centerBias * 0.35;

      final speedFactor = (b.riseSpeedMultiplier - 1.0).clamp(0.0, 1.5);
      final dynamicBonus = speedFactor * 12.0;
      final effectiveRadius = balloonRadius + hitForgiveness + dynamicBonus;

      // Track closest balloon for logging
      if (closestScore == null || tapScore < closestScore) {
        closestScore = tapScore;
        closestDist = dist;
        closestDx = dx;
        closestDy = dy;
        closestBx = bx;
        closestBy = by;
      }

      // Track best valid hit
      if (dist <= effectiveRadius) {
        if (bestHitScore == null || tapScore < bestHitScore) {
          bestHitScore = tapScore;
          bestHitIndex = i;
          bestHitDist = dist;
        }
      }
    }

    // ---------------------------------------------------------
    // APPLY HIT
    // ---------------------------------------------------------
    if (bestHitIndex != null) {
      final b = balloons[bestHitIndex];
      balloons[bestHitIndex] = b.pop();

      if (bestHitDist != null && bestHitDist <= balloonRadius * 0.45) {
        perfectHit = true;
        if (_verboseTapLogging) {
          gameState.log(
            'PERFECT HIT dist=${bestHitDist.toStringAsFixed(1)}',
          );
        }
      }

      spawner.registerPop(gameState);

      surge.maybeTrigger(
        totalPops: spawner.totalPops,
        currentWorld: spawner.currentWorld,
        world2Pops: BalloonSpawner.world2Pops,
        world3Pops: BalloonSpawner.world3Pops,
        world4Pops: BalloonSpawner.world4Pops,
      );

      hit = true;
    }

    // ---------------------------------------------------------
    // MISS HANDLING
    // ---------------------------------------------------------
    if (!hit) {
      if (closestDist != null &&
          closestBx != null &&
          closestBy != null &&
          closestDx != null &&
          closestDy != null) {
        gameState.log(
          'MISS world=${spawner.currentWorld} '
          'tap=(${tapPos.dx.toStringAsFixed(1)},${tapPos.dy.toStringAsFixed(1)}) '
          'balloon=(${closestBx.toStringAsFixed(1)},${closestBy.toStringAsFixed(1)}) '
          'dx=${closestDx.toStringAsFixed(1)} '
          'dy=${closestDy.toStringAsFixed(1)} '
          'dist=${closestDist.toStringAsFixed(1)} '
          'r=${(balloonRadius + hitForgiveness).toStringAsFixed(1)}',
        );
      }

      final nearMissRadius = balloonRadius + hitForgiveness + 10;

      if (closestDist != null &&
          closestDist > balloonRadius &&
          closestDist <= nearMissRadius) {
        gameState.log(
          'NEAR MISS dist=${closestDist.toStringAsFixed(1)}',
        );
      }

      spawner.registerMiss(gameState);
    }

    controller.registerTap(hit: hit, perfect: perfectHit);
  }

  static void clearTouch() {
    // intentionally empty for now
  }
}
