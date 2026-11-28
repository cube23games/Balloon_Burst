import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:balloon_burst/tj_engine/engine/daily/daily_reward_manager.dart';
import 'package:balloon_burst/tj_engine/engine/daily/now_provider.dart';

class _Clock implements NowProvider {
  _Clock(this.time);
  DateTime time;
  @override
  DateTime now() => time;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'tj_daily_last_claim_iso_v1';
  final start = DateTime.utc(2026, 11, 28, 12);
  late _Clock clock;
  late Map<String, Object> saved;

  setUp(() {
    clock = _Clock(start);
    saved = {
      key: start.subtract(const Duration(hours: 1)).toIso8601String(),
      'tj_wallet_balance_v1': 4720,
    };
    SharedPreferences.setMockInitialValues(saved);
  });

  DailyRewardManager isolated() =>
      DailyRewardManager(clock: clock, persistenceEnabled: false);

  Future<void> unchanged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, saved);
  }

  test('isolated load ignores legitimate claim history', () async {
    final manager = isolated();
    await manager.load();
    expect(manager.getStatus(currentWorldLevel: 1).isAvailable, isTrue);
    final normal = DailyRewardManager(clock: clock);
    await normal.load();
    expect(normal.getStatus(currentWorldLevel: 1).isAvailable, isFalse);
    await unchanged();
  });

  test('both claim methods remain temporary and reject duplicate claims',
      () async {
    final manager = isolated();
    final reward = manager.claim(currentWorldLevel: 1);
    expect(reward?.coins, 125);
    expect(manager.claim(currentWorldLevel: 1), isNull);
    expect(await manager.claimAndSave(currentWorldLevel: 1), isNull);
    await unchanged();
    clock.time = start.add(const Duration(hours: 24));
    expect((await manager.claimAndSave(currentWorldLevel: 2))?.coins, 150);
    await manager.save();
    await manager.load();
    expect(manager.getStatus(currentWorldLevel: 2).isAvailable, isFalse);
    await unchanged();
  });

  test('cooldown enforces exact 24-hour boundary', () async {
    final manager = isolated();
    await manager.claimAndSave(currentWorldLevel: 1);
    clock.time = start.add(const Duration(hours: 24))
        .subtract(const Duration(milliseconds: 1));
    final status = manager.getStatus(currentWorldLevel: 1);
    expect(status.isAvailable, isFalse);
    expect(status.timeRemaining, const Duration(milliseconds: 1));
    expect(manager.claim(currentWorldLevel: 1), isNull);
    clock.time = start.add(const Duration(hours: 24));
    expect(manager.getStatus(currentWorldLevel: 1).isAvailable, isTrue);
    expect(manager.getStatus(currentWorldLevel: 1).timeRemaining, Duration.zero);
    expect(await manager.claimAndSave(currentWorldLevel: 1), isNotNull);
    await unchanged();
  });

  test('explicit save of fresh isolated manager cannot remove history',
      () async {
    await isolated().save();
    await unchanged();
  });

  test('isolated instances maintain independent eligibility', () async {
    final first = isolated();
    final second = isolated();
    await first.claimAndSave(currentWorldLevel: 1);
    expect(first.getStatus(currentWorldLevel: 1).isAvailable, isFalse);
    expect(second.getStatus(currentWorldLevel: 1).isAvailable, isTrue);
    await second.claimAndSave(currentWorldLevel: 1);
    await unchanged();
  });

  test('isolated claims never create absent persistent keys', () async {
    SharedPreferences.setMockInitialValues({});
    final manager = isolated();
    await manager.load();
    await manager.claimAndSave(currentWorldLevel: 1);
    await manager.save();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getKeys(), isEmpty);
  });

  test('default manager retains normal persistent cooldown and rewards',
      () async {
    final normal = DailyRewardManager(clock: clock);
    await normal.load();
    expect(await normal.claimAndSave(currentWorldLevel: 1), isNull);
    clock.time = start.add(const Duration(hours: 23));
    expect((await normal.claimAndSave(currentWorldLevel: 1))?.coins, 125);
    final reloaded = DailyRewardManager(clock: clock);
    await reloaded.load();
    expect(reloaded.getStatus(currentWorldLevel: 1).isAvailable, isFalse);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString(key), clock.time.toIso8601String());
    expect(prefs.getInt('tj_wallet_balance_v1'), 4720);
    clock.time = clock.time.add(const Duration(hours: 24));
    expect(reloaded.getStatus(currentWorldLevel: 1).isAvailable, isTrue);
  });
}
