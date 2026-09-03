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

  test('fractional quantities round-trip exactly', () {
    expect(AssetQuantity.parse('0.015').toString(), '0.015');
    expect(AssetQuantity.parse('0.000125').toString(), '0.000125');
    expect(AssetQuantity.parse('5.25').toString(), '5.25');
    expect(AssetQuantity.parse('123.4567').toString(), '123.4567');
    expect(AssetQuantity.parse('1.23000000').scaled, 123000000);
    expect(() => AssetQuantity.parse('0.000000001'), throwsFormatException);
  });

  test(
    'asset and opening activity preserve type and unknown cost basis',
    () async {
      final asset = await assets.create(
        symbol: ' bbca ',
        name: 'BBCA',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.api,
        unitLabel: 'share',
      );
      final activity = await activities.create(
        assetId: asset.id,
        action: AssetTransactionAction.openingPosition,
        quantity: AssetQuantity.parse('1200'),
        transactionDate: DateTime(2026, 9, 3),
      );

      expect(asset.symbol, 'bbca');
      expect(asset.normalizedSymbol, 'BBCA');
      expect(asset.assetType, AssetType.stock);
      expect(asset.pricingMode, AssetPricingMode.api);
      expect(activity.priceAmount, isNull);
      expect(activity.totalAmount, isNull);
      expect(
        await activities.currentHolding(asset.id),
        AssetQuantity.parse('1200'),
      );
    },
  );

  test(
    'holdings apply buy, sell, adjustment and ignore soft-deleted activity',
    () async {
      final asset = await assets.create(
        name: 'Bitcoin',
        assetType: AssetType.crypto,
        pricingMode: AssetPricingMode.api,
      );
      await activities.create(
        assetId: asset.id,
        action: AssetTransactionAction.openingPosition,
        quantity: AssetQuantity.parse('0.015'),
        transactionDate: DateTime(2026, 9, 1),
      );
      await activities.create(
        assetId: asset.id,
        action: AssetTransactionAction.buy,
        quantity: AssetQuantity.parse('0.002'),
        transactionDate: DateTime(2026, 9, 2),
      );
      final sell = await activities.create(
        assetId: asset.id,
        action: AssetTransactionAction.sell,
        quantity: AssetQuantity.parse('0.005'),
        transactionDate: DateTime(2026, 9, 3),
      );
      await activities.create(
        assetId: asset.id,
        action: AssetTransactionAction.adjustment,
        quantity: AssetQuantity.parse('0.001'),
        transactionDate: DateTime(2026, 9, 4),
      );

      expect(
        await activities.currentHolding(asset.id),
        AssetQuantity.parse('0.013'),
      );
      expect(await activities.softDelete(sell.id), isTrue);
      expect(
        await activities.currentHolding(asset.id),
        AssetQuantity.parse('0.018'),
      );
    },
  );
}
