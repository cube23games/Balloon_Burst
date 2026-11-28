import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:balloon_burst/tj_engine/engine/shield/shield_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pendingKey = 'tj_shield_pending_v1';
  const activeKey = 'tj_shield_active_v1';

  for (final pending in [false, true]) {
    for (final active in [false, true]) {
      test('isolated shield preserves saved pending=$pending active=$active',
          () async {
        SharedPreferences.setMockInitialValues({
          pendingKey: pending,
          activeKey: active,
          'unrelated_player_data': 4720,
        });
        final prefs = await SharedPreferences.getInstance();
        final before = {
          for (final key in prefs.getKeys()) key: prefs.get(key),
        };
        Future<void> expectUnchanged() async {
          await prefs.reload();
          expect({
            for (final key in prefs.getKeys()) key: prefs.get(key),
          }, before);
        }

        final isolated = ShieldManager(persistenceEnabled: false);
        await isolated.load();
        expect(isolated.isPending, isFalse);
        expect(isolated.isActive, isFalse);
        await expectUnchanged();

        await isolated.activateIfPending();
        await isolated.consume();
        await expectUnchanged();

        await isolated.armForNextRun();
        expect(isolated.isPending, isTrue);
        await expectUnchanged();

        await isolated.activateIfPending();
        expect(isolated.isPending, isFalse);
        expect(isolated.isActive, isTrue);
        await expectUnchanged();

        await isolated.consume();
        expect(isolated.isActive, isFalse);
        await expectUnchanged();

        final normal = ShieldManager();
        await normal.load();
        expect(normal.isPending, pending);
        expect(normal.isActive, active);
      });
    }
  }

  test('isolated shield never creates absent persistent keys', () async {
    SharedPreferences.setMockInitialValues({});
    final isolated = ShieldManager(persistenceEnabled: false);
    await isolated.load();
    await isolated.armForNextRun();
    await isolated.activateIfPending();
    await isolated.consume();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getKeys(), isEmpty);
  });

  test('default shield persists purchase, activation and consumption', () async {
    SharedPreferences.setMockInitialValues({});
    final normal = ShieldManager();
    await normal.load();
    await normal.armForNextRun();

    final purchased = ShieldManager();
    await purchased.load();
    expect(purchased.isPending, isTrue);
    expect(purchased.isActive, isFalse);

    await purchased.activateIfPending();
    final activated = ShieldManager();
    await activated.load();
    expect(activated.isPending, isFalse);
    expect(activated.isActive, isTrue);

    await activated.consume();
    final consumed = ShieldManager();
    await consumed.load();
    expect(consumed.isPending, isFalse);
    expect(consumed.isActive, isFalse);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getBool(pendingKey), isFalse);
    expect(prefs.getBool(activeKey), isFalse);
  });
}
