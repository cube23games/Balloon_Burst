import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:balloon_burst/tj_engine/engine/leaderboard/leaderboard_entry.dart';
import 'package:balloon_burst/tj_engine/engine/leaderboard/leaderboard_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'tj_leaderboard_v1';

  LeaderboardEntry entry(int score) => LeaderboardEntry(
        score: score,
        worldReached: 2,
        accuracy01: 0.95,
        bestStreak: 20,
        timestamp: DateTime.utc(2026, 11, 28),
      );

  LeaderboardManager isolated() =>
      LeaderboardManager(persistenceEnabled: false);

  List<int> scores(LeaderboardManager manager) =>
      manager.entries.map((e) => e.score).toList();

  late Map<String, Object> saved;
  setUp(() {
    saved = {
      key: jsonEncode([entry(9000).toJson(), entry(8000).toJson()]),
      'tj_wallet_balance_v1': 4720,
    };
    SharedPreferences.setMockInitialValues(saved);
  });

  Future<void> expectStorage(Map<String, Object> expected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, expected);
  }

  test('isolated load ignores legitimate records', () async {
    final manager = isolated();
    await manager.load();
    expect(manager.entries, isEmpty);
    final normal = LeaderboardManager();
    await normal.load();
    expect(scores(normal), [9000, 8000]);
    await expectStorage(saved);
  });

  test('temporary scores rank correctly without persistent writes', () async {
    final manager = isolated();
    expect(await manager.submit(entry(100)), 1);
    await expectStorage(saved);
    expect(await manager.submit(entry(300)), 1);
    await expectStorage(saved);
    expect(await manager.submit(entry(200)), 2);
    expect(scores(manager), [300, 200, 100]);
    await manager.load();
    expect(scores(manager), [300, 200, 100]);
    await expectStorage(saved);
  });

  test('top ten limit and rejected scores preserve storage', () async {
    final manager = isolated();
    for (var i = 1; i <= 10; i++) {
      expect(await manager.submit(entry(i * 100)), 1);
      await expectStorage(saved);
    }
    expect(await manager.submit(entry(50)), isNull);
    expect(scores(manager), List.generate(10, (i) => (10 - i) * 100));
    expect(await manager.submit(entry(1100)), 1);
    expect(scores(manager), List.generate(10, (i) => (11 - i) * 100));
    await expectStorage(saved);
  });

  test('isolated instances have independent records', () async {
    final first = isolated();
    final second = isolated();
    await first.submit(entry(100));
    await second.load();
    expect(second.entries, isEmpty);
    await second.submit(entry(200));
    expect(scores(first), [100]);
    expect(scores(second), [200]);
    await expectStorage(saved);
  });

  for (final raw in ['invalid json', '{}', '[{}]']) {
    test('isolated manager preserves corrupted record: $raw', () async {
      final corrupt = <String, Object>{
        key: raw,
        'tj_wallet_balance_v1': 4720,
      };
      SharedPreferences.setMockInitialValues(corrupt);
      final manager = isolated();
      await manager.load();
      expect(manager.entries, isEmpty);
      await expectStorage(corrupt);
      await manager.submit(entry(100));
      await expectStorage(corrupt);
      final normal = LeaderboardManager();
      await normal.load();
      expect(normal.entries, isEmpty);
      await expectStorage({'tj_wallet_balance_v1': 4720});
    });
  }

  test('isolated operations never create absent keys', () async {
    SharedPreferences.setMockInitialValues({});
    final manager = isolated();
    await manager.load();
    await manager.submit(entry(100));
    await expectStorage({});
  });

  test('default manager persists and reloads normal scores', () async {
    final normal = LeaderboardManager();
    await normal.load();
    expect(await normal.submit(entry(8500)), 2);
    final reloaded = LeaderboardManager();
    await reloaded.load();
    expect(scores(reloaded), [9000, 8500, 8000]);
    expect(reloaded.entries[1].toJson(), entry(8500).toJson());
    await expectStorage({
      key: jsonEncode([
        entry(9000).toJson(),
        entry(8500).toJson(),
        entry(8000).toJson(),
      ]),
      'tj_wallet_balance_v1': 4720,
    });
  });
}
