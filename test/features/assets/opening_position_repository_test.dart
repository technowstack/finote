import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_transaction_action.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AssetTransactionRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = AssetTransactionRepository(database);
  });

  tearDown(() => database.close());

  Future<AssetRecord> createAsset(AssetType type) {
    return database
        .into(database.assets)
        .insertReturning(
          AssetsCompanion.insert(
            name: type.label,
            assetType: type,
            pricingMode: type.defaultPricingMode,
            unitLabel: Value(type.defaultUnitLabel),
          ),
        );
  }

  test(
    'stores exact quantities, optional cost, and stable date without cashflow',
    () async {
      final asset = await createAsset(AssetType.crypto);
      final date = DateTime(2026, 9, 3);

      final opening = await repository.createOpeningPosition(
        assetId: asset.id,
        quantity: AssetQuantity.parse('0.000125'),
        transactionDate: date,
      );

      expect(opening.quantityScaled, 12500);
      expect(opening.transactionDate, date);
      expect(opening.totalAmount, isNull);
      expect(opening.sourceTransactionId, isNull);
      expect(
        await repository.currentHolding(asset.id),
        AssetQuantity.parse('0.000125'),
      );
      expect(await database.select(database.transactions).get(), isEmpty);

      await expectLater(
        repository.createOpeningPosition(
          assetId: asset.id,
          quantity: AssetQuantity.parse('1'),
          transactionDate: date,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        await repository.updateOpeningPosition(
          id: opening.id,
          quantity: AssetQuantity.parse('0.015'),
          transactionDate: DateTime(2026, 9, 4),
          totalAmount: 2500000,
        ),
        isTrue,
      );
      final updated = await repository.getOpeningPosition(asset.id);
      expect(updated?.quantityScaled, 1500000);
      expect(updated?.transactionDate, DateTime(2026, 9, 4));
      expect(updated?.totalAmount, 2500000);
      expect(
        await repository.currentHolding(asset.id),
        AssetQuantity.parse('0.015'),
      );

      expect(await repository.removeOpeningPosition(opening.id), isTrue);
      expect(await repository.getOpeningPosition(asset.id), isNull);
      expect(
        await repository.currentHolding(asset.id),
        AssetQuantity.fromScaled(0),
      );
    },
  );

  test('supports exact fractional opening quantities and blocks removal with later activity', () async {
    final asset = await createAsset(AssetType.gold);
    final opening = await repository.createOpeningPosition(
      assetId: asset.id,
      quantity: AssetQuantity.parse('5.25'),
      transactionDate: DateTime(2026, 9, 3),
    );
    await repository.create(
      assetId: asset.id,
      action: AssetTransactionAction.buy,
      quantity: AssetQuantity.parse('1'),
      transactionDate: DateTime(2026, 9, 4),
    );

    expect(
      repository.removeOpeningPosition(opening.id),
      throwsA(isA<StateError>()),
    );
    expect(
      await repository.currentHolding(asset.id),
      AssetQuantity.parse('6.25'),
    );
  });

  test('opening position edit cannot make later holdings negative', () async {
    final asset = await createAsset(AssetType.gold);
    final opening = await repository.createOpeningPosition(
      assetId: asset.id,
      quantity: AssetQuantity.parse('5'),
      transactionDate: DateTime(2026, 9, 3),
    );
    await repository.create(
      assetId: asset.id,
      action: AssetTransactionAction.sell,
      quantity: AssetQuantity.parse('4'),
      transactionDate: DateTime(2026, 9, 4),
    );

    await expectLater(
      repository.updateOpeningPosition(
        id: opening.id,
        quantity: AssetQuantity.parse('3'),
        transactionDate: DateTime(2026, 9, 3),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await repository.currentHolding(asset.id), AssetQuantity.parse('1'));
  });
}
