import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:balloon_burst/debug/qa_benchmark_engine_factory.dart';
import 'package:balloon_burst/tj_engine/engine/tj_engine.dart';
import 'package:balloon_burst/tj_engine/engine/leaderboard/leaderboard_entry.dart';
import 'package:balloon_burst/tj_engine/engine/run/models/run_event.dart';
import 'package:balloon_burst/tj_engine/engine/run/models/run_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Object> saved;
  setUp(() {
    saved = {
      'tj_wallet_balance_v1': 4720,
      'tj_shield_pending_v1': true,
      'tj_shield_active_v1': false,
      'tj_audio_muted_v1': true,
      'tj_daily_last_claim_iso_v1': DateTime.now().toUtc().toIso8601String(),
      'tj_leaderboard_v1': jsonEncode([
        LeaderboardEntry(
          score: 9000,
          worldReached: 2,
          accuracy01: 0.95,
          bestStreak: 20,
          timestamp: DateTime.utc(2026, 11, 28),
        ).toJson(),
      ]),
      'skyward.world1.stars.v1': 'sentinel-stars',
      'bb_profile_json_v1': 'sentinel-profile',
      'bb_stats_json_v1': 'sentinel-stats',
      'unrelated_key': 42,
    };
    SharedPreferences.setMockInitialValues(saved);
  });

  Future<void> expectStorage(Map<String, Object> expected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, expected);
  }

  Future<TJEngine> fresh() async {
    final engine = QaBenchmarkEngineFactory.create();
    await engine.loadAll();
    return engine;
  }

  Future<void> exercise(TJEngine engine,
      Map<String, Object> expected) async {
    expect(await engine.purchaseShield(), isFalse);
    final reward = await engine.claimDailyRewardAndCredit(currentWorldLevel: 1);
    expect(reward, isNotNull);
    expect(engine.wallet.balance, 125);
    expect(await engine.claimDailyRewardAndCredit(currentWorldLevel: 1), isNull);
    await expectStorage(expected);

    expect(await engine.purchaseShield(), isTrue);
    expect(engine.wallet.balance, 50);
    expect(engine.shield.isPending, isTrue);
    expect(engine.runLifecycle.isShieldArmedForNextRun, isTrue);
    await expectStorage(expected);

    final run = engine.runLifecycle;
    run.startRun(runId: 'benchmark-test');
    expect(engine.shield.isActive, isTrue);
    expect(run.isShieldActive, isTrue);
    expect(engine.shield.isPending, isFalse);
    run.report(const EscapeEvent());
    expect(engine.shield.isActive, isFalse);
    expect(run.getSnapshot().escapes, 0);
    await expectStorage(expected);

    run.report(const PopEvent(points: 100));
    run.report(const WorldTransitionEvent(newWorldLevel: 2));
    run.endRun(EndReason.playerQuit);
    final summary = run.latestSummary!;
    expect(summary.score, 100);
    expect(summary.pops, 1);
    await engine.creditRunCoins(summary);
    expect(engine.wallet.balance, 72);
    await engine.creditRunCoins(summary);
    expect(engine.wallet.balance, 72);
    expect(engine.lastCreditedRunCoins, 0);
    await expectStorage(expected);

    expect(await engine.submitLatestRunToLeaderboard(), 1);
    expect(engine.leaderboard.entries.single.score, 100);
    await expectStorage(expected);

    expect(await engine.toggleMute(), isTrue);
    await engine.setMuted(false);
    expect(engine.isMuted, isFalse);
    await expectStorage(expected);
  }

  test('factory explicitly disables all five persistence flags', () async {
    final engine = await fresh();
    expect(engine.wallet.persistenceEnabled, isFalse);
    expect(engine.shield.persistenceEnabled, isFalse);
    expect(engine.dailyReward.persistenceEnabled, isFalse);
    expect(engine.audio.persistenceEnabled, isFalse);
    expect(engine.leaderboard.persistenceEnabled, isFalse);
    expect(engine.wallet.balance, 0);
    expect(engine.shield.isPending, isFalse);
    expect(engine.shield.isActive, isFalse);
    expect(engine.isMuted, isFalse);
    expect(engine.leaderboard.entries, isEmpty);
    expect(engine.dailyReward.getStatus(currentWorldLevel: 1).isAvailable, isTrue);
    await expectStorage(saved);
  });

  test('combined engine operations preserve every saved key', () async {
    final normal = TJEngine();
    await normal.loadAll();
    final engine = await fresh();
    await exercise(engine, saved);
    expect(normal.wallet.balance, 4720);
    expect(normal.shield.isPending, isTrue);
    expect(normal.shield.isActive, isFalse);
    expect(normal.isMuted, isTrue);
    expect(normal.leaderboard.entries.single.score, 9000);
    expect(normal.dailyReward.getStatus(currentWorldLevel: 1).isAvailable, isFalse);
    final reloaded = TJEngine();
    await reloaded.loadAll();
    expect(reloaded.wallet.balance, 4720);
    expect(reloaded.shield.isPending, isTrue);
    expect(reloaded.isMuted, isTrue);
    expect(reloaded.leaderboard.entries.single.score, 9000);
    await expectStorage(saved);
  });

  test('combined operations never create absent storage keys', () async {
    SharedPreferences.setMockInitialValues({});
    await exercise(await fresh(), {});
  });

  test('factory instances do not share mutable engine state', () async {
    final first = await fresh();
    final second = await fresh();
    expect(identical(first.input, second.input), isFalse);
    expect(identical(first.runLifecycle, second.runLifecycle), isFalse);
    expect(identical(first.wallet, second.wallet), isFalse);
    expect(identical(first.shield, second.shield), isFalse);
    expect(identical(first.audio, second.audio), isFalse);
    expect(identical(first.dailyReward, second.dailyReward), isFalse);
    expect(identical(first.leaderboard, second.leaderboard), isFalse);
    expect(identical(first.difficulty, second.difficulty), isFalse);
    expect(identical(first.juice, second.juice), isFalse);
    await exercise(first, saved);
    await first.setMuted(true);
    await first.shield.armForNextRun();
    first.update(21);
    first.juice.spawnScoreBurst(x: 10, y: 20);
    expect(second.wallet.balance, 0);
    expect(second.shield.isPending, isFalse);
    expect(second.isMuted, isFalse);
    expect(second.leaderboard.entries, isEmpty);
    expect(second.dailyReward.getStatus(currentWorldLevel: 1).isAvailable, isTrue);
    expect(second.runLifecycle.state, RunState.idle);
    expect(second.difficulty.elapsed, 0);
    expect(second.juice.scoreBursts, isEmpty);
    await expectStorage(saved);
  });

  test('isolated engine does not repair corrupt persistent leaderboard', () async {
    saved['tj_leaderboard_v1'] = 'invalid json';
    SharedPreferences.setMockInitialValues(saved);
    await exercise(await fresh(), saved);
  });

  test('normal engine still persists wallet and audio changes', () async {
    final normal = TJEngine();
    await normal.loadAll();
    await normal.wallet.addCoins(10);
    await normal.setMuted(false);
    final reloaded = TJEngine();
    await reloaded.loadAll();
    expect(reloaded.wallet.balance, 4730);
    expect(reloaded.isMuted, isFalse);
    await expectStorage({
      ...saved,
      'tj_wallet_balance_v1': 4730,
      'tj_audio_muted_v1': false,
    });
  });
}
