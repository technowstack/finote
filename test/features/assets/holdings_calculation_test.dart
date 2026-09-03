import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_transaction_action.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AssetRepository assets;
  late AssetTransactionRepository activities;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    assets = AssetRepository(database);
    activities = AssetTransactionRepository(database);
  });

  tearDown(() => database.close());

  Future<AssetRecord> createAsset(
    String name,
    AssetType type, {
    String? symbol,
  }) {
    return assets.create(
      symbol: symbol,
      name: name,
      assetType: type,
      pricingMode: type.defaultPricingMode,
    );
  }

  Future<void> add(
    AssetRecord asset,
    AssetTransactionAction action,
    String quantity,
  ) {
    return activities.create(
      assetId: asset.id,
      action: action,
      quantity: AssetQuantity.parse(quantity),
      transactionDate: DateTime(2026, 9, 1),
    );
  }

  test('aggregate preserves no activity versus valid zero holding', () async {
    final empty = await createAsset('Empty', AssetType.stock, symbol: 'EMP');
    final closed = await createAsset('Closed', AssetType.stock, symbol: 'CLS');
    await add(closed, AssetTransactionAction.openingPosition, '10');
    await add(closed, AssetTransactionAction.sell, '10');

    final holdings = await activities.watchAllHoldings().first;
    final emptyHolding = holdings.singleWhere(
      (item) => item.asset.id == empty.id,
    );
    final closedHolding = holdings.singleWhere(
      (item) => item.asset.id == closed.id,
    );
    expect(emptyHolding.hasActivity, isFalse);
    expect(emptyHolding.quantity, AssetQuantity.fromScaled(0));
    expect(closedHolding.hasActivity, isTrue);
    expect(closedHolding.quantity, AssetQuantity.fromScaled(0));
  });

  test('stock flow uses shares as canonical quantity', () async {
    final asset = await createAsset('BBCA', AssetType.stock, symbol: 'BBCA');
    await add(asset, AssetTransactionAction.openingPosition, '12');
    await add(asset, AssetTransactionAction.buy, '3');
    await add(asset, AssetTransactionAction.sell, '2');
    await add(asset, AssetTransactionAction.adjustment, '1');

    expect(
      await activities.currentHolding(asset.id),
      AssetQuantity.parse('14'),
    );
  });

  test('fractional quantities remain exact across asset types', () async {
    final crypto = await createAsset(
      'Bitcoin',
      AssetType.crypto,
      symbol: 'BTC',
    );
    final gold = await createAsset('Gold', AssetType.gold);
    final fund = await createAsset('Fund', AssetType.mutualFund);
    await add(crypto, AssetTransactionAction.openingPosition, '0.015');
    await add(crypto, AssetTransactionAction.buy, '0.002');
    await add(crypto, AssetTransactionAction.sell, '0.005');
    await add(crypto, AssetTransactionAction.adjustment, '0.000125');
    await add(gold, AssetTransactionAction.openingPosition, '5.25');
    await add(gold, AssetTransactionAction.sell, '1.25');
    await add(fund, AssetTransactionAction.openingPosition, '123.4567');
    await add(fund, AssetTransactionAction.buy, '10.1001');

    expect(
      await activities.currentHolding(crypto.id),
      AssetQuantity.parse('0.012125'),
    );
    expect(await activities.currentHolding(gold.id), AssetQuantity.parse('4'));
    expect(
      await activities.currentHolding(fund.id),
      AssetQuantity.parse('133.5568'),
    );
  });

  test(
    'deleted activity has no effect and archived assets leave active holdings',
    () async {
      final asset = await createAsset('BBCA', AssetType.stock, symbol: 'BBCA');
      final activity = await activities.create(
        assetId: asset.id,
        action: AssetTransactionAction.buy,
        quantity: AssetQuantity.parse('2'),
        transactionDate: DateTime(2026, 9, 1),
      );
      expect((await activities.watchHoldings().first), hasLength(1));
      await activities.softDelete(activity.id);
      expect(
        (await activities.watchHoldings().first).single.hasActivity,
        isFalse,
      );
      await assets.archive(asset.id);
      expect(await activities.watchHoldings().first, isEmpty);
      final archived = await activities.watchAllHoldings().first;
      expect(archived.single.quantity, AssetQuantity.fromScaled(0));
      expect(archived.single.hasActivity, isFalse);
    },
  );

  test('negative aggregate is exposed as inconsistent, not clamped', () async {
    final asset = await createAsset('Corrupt', AssetType.other);
    await add(asset, AssetTransactionAction.sell, '2');

    final holding = (await activities.watchAllHoldings().first).single;
    expect(holding.quantity, AssetQuantity.parse('-2'));
    expect(holding.isConsistent, isFalse);
    expect((await activities.findNegativeHoldings()).single.asset.id, asset.id);
  });

  test('same symbol across types remains independent', () async {
    final crypto = await createAsset(
      'Bitcoin',
      AssetType.crypto,
      symbol: 'BTC',
    );
    final other = await createAsset(
      'Other BTC',
      AssetType.other,
      symbol: 'BTC',
    );
    await add(crypto, AssetTransactionAction.buy, '0.5');
    await add(other, AssetTransactionAction.buy, '3');

    final holdings = await activities.watchAllHoldings().first;
    expect(
      holdings.singleWhere((item) => item.asset.id == crypto.id).quantity,
      AssetQuantity.parse('0.5'),
    );
    expect(
      holdings.singleWhere((item) => item.asset.id == other.id).quantity,
      AssetQuantity.parse('3'),
    );
  });
}
