import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:balloon_burst/tj_engine/engine/wallet/wallet_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'tj_wallet_balance_v1';
  const saved = 4720;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      key: saved,
      'unrelated_player_data': true,
    });
  });

  Future<void> expectSavedUnchanged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect({for (final k in prefs.getKeys()) k: prefs.get(k)},
        {key: saved, 'unrelated_player_data': true});
  }

  test('isolated wallet cannot load legitimate savings', () async {
    final wallet = WalletManager(persistenceEnabled: false);
    await wallet.load();
    expect(wallet.balance, 0);
    expect(await wallet.spendCoins(1), isFalse);
    await expectSavedUnchanged();
  });

  test('temporary earnings and purchases never persist', () async {
    final wallet = WalletManager(persistenceEnabled: false);
    await wallet.addCoins(200);
    expect(wallet.balance, 200);
    await expectSavedUnchanged();
    expect(await wallet.spendCoins(75), isTrue);
    expect(wallet.balance, 125);
    await expectSavedUnchanged();
    await wallet.load();
    expect(wallet.balance, 125);
    await expectSavedUnchanged();
  });

  test('invalid transactions and insufficient funds are rejected', () async {
    final wallet = WalletManager(persistenceEnabled: false);
    await wallet.addCoins(20);
    await wallet.addCoins(0);
    await wallet.addCoins(-10);
    for (final amount in [0, -1, 21]) {
      expect(await wallet.spendCoins(amount), isFalse);
      expect(wallet.balance, 20);
      await expectSavedUnchanged();
    }
    expect(await wallet.spendCoins(20), isTrue);
    expect(wallet.balance, 0);
    await expectSavedUnchanged();
  });

  test('isolated reset cannot erase legitimate savings', () async {
    final wallet = WalletManager(persistenceEnabled: false);
    await wallet.addCoins(100);
    await wallet.reset();
    expect(wallet.balance, 0);
    await expectSavedUnchanged();
    final normal = WalletManager();
    await normal.load();
    expect(normal.balance, saved);
  });

  test('isolated instances maintain independent balances', () async {
    final first = WalletManager(persistenceEnabled: false);
    final second = WalletManager(persistenceEnabled: false);
    await first.addCoins(100);
    await second.load();
    expect(second.balance, 0);
    await second.addCoins(30);
    expect(await first.spendCoins(25), isTrue);
    expect(first.balance, 75);
    expect(second.balance, 30);
    await second.reset();
    expect(first.balance, 75);
    expect(second.balance, 0);
    await expectSavedUnchanged();
  });

  test('isolated operations never create absent persistent keys', () async {
    SharedPreferences.setMockInitialValues({});
    final wallet = WalletManager(persistenceEnabled: false);
    await wallet.load();
    await wallet.addCoins(100);
    expect(await wallet.spendCoins(50), isTrue);
    await wallet.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getKeys(), isEmpty);
  });

  test('default wallet retains normal persistent behavior', () async {
    final wallet = WalletManager();
    await wallet.load();
    expect(wallet.balance, saved);
    await wallet.addCoins(100);
    final reloaded = WalletManager();
    await reloaded.load();
    expect(reloaded.balance, saved + 100);
    expect(await reloaded.spendCoins(75), isTrue);
    expect(await reloaded.spendCoins(0), isFalse);
    expect(await reloaded.spendCoins(-1), isFalse);
    expect(await reloaded.spendCoins(saved + 26), isFalse);
    final afterPurchase = WalletManager();
    await afterPurchase.load();
    expect(afterPurchase.balance, saved + 25);
    await afterPurchase.reset();
    final afterReset = WalletManager();
    await afterReset.load();
    expect(afterReset.balance, 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getInt(key), 0);
    expect(prefs.getBool('unrelated_player_data'), isTrue);
  });
}
