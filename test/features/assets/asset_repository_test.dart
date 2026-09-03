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
  late AssetRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = AssetRepository(database);
  });

  tearDown(() => database.close());

  test(
    'creates all supported asset types with safe pricing defaults',
    () async {
      final assets = <AssetRecord>[];
      for (final type in AssetType.values) {
        assets.add(
          await repository.create(
            symbol: type == AssetType.stock ? 'bbca' : null,
            name: type.label,
            assetType: type,
            pricingMode: type.defaultPricingMode,
            unitLabel: type.defaultUnitLabel,
          ),
        );
      }

      expect(assets.map((asset) => asset.assetType), AssetType.values);
      expect(assets.first.symbol, 'bbca');
      expect(assets.first.normalizedSymbol, 'BBCA');
      expect(assets.map((asset) => asset.pricingMode), [
        AssetPricingMode.api,
        AssetPricingMode.api,
        AssetPricingMode.manual,
        AssetPricingMode.manual,
        AssetPricingMode.manual,
      ]);
    },
  );

  test('rejects duplicate symbols only within the same asset type', () async {
    await repository.create(
      symbol: 'bbca',
      name: 'Bank Central Asia',
      assetType: AssetType.stock,
      pricingMode: AssetPricingMode.api,
    );

    expect(
      () => repository.create(
        symbol: ' BBCA ',
        name: 'Bank Central Asia 2',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.api,
      ),
      throwsA(isA<StateError>()),
    );
    await repository.create(
      symbol: 'bbca',
      name: 'Manual BBCA Reference',
      assetType: AssetType.other,
      pricingMode: AssetPricingMode.manual,
    );
  });

  test('updates metadata without changing identity', () async {
    final asset = await repository.create(
      symbol: 'BTC',
      name: 'Bitcoin',
      assetType: AssetType.crypto,
      pricingMode: AssetPricingMode.api,
    );

    expect(
      await repository.update(
        id: asset.id,
        symbol: 'eth',
        name: 'Ethereum',
        assetType: AssetType.crypto,
        pricingMode: AssetPricingMode.api,
      ),
      isTrue,
    );
    final updated = await repository.findById(asset.id);
    expect(updated?.uuid, asset.uuid);
    expect(updated?.name, 'Ethereum');
    expect(updated?.normalizedSymbol, 'ETH');
  });

  test('archives, restores, and deletes only unused assets', () async {
    final asset = await repository.create(
      name: 'Emas',
      assetType: AssetType.gold,
      pricingMode: AssetPricingMode.manual,
    );
    expect(await repository.archive(asset.id), isTrue);
    expect((await repository.findById(asset.id))?.isActive, isFalse);
    expect(await repository.reactivate(asset.id), isTrue);
    expect((await repository.findById(asset.id))?.isActive, isTrue);
    expect(await repository.deleteUnused(asset.id), isTrue);
    expect(await repository.findById(asset.id), isNull);
  });

  test('protects assets with activity from hard delete', () async {
    final asset = await repository.create(
      name: 'BBCA',
      assetType: AssetType.stock,
      pricingMode: AssetPricingMode.api,
    );
    await AssetTransactionRepository(database).create(
      assetId: asset.id,
      action: AssetTransactionAction.openingPosition,
      quantity: AssetQuantity.parse('1'),
      transactionDate: DateTime(2026, 9, 3),
    );

    expect(await repository.canDelete(asset.id), isFalse);
    expect(await repository.deleteUnused(asset.id), isFalse);
    expect(
      await database.select(database.assetTransactions).get(),
      hasLength(1),
    );
    expect(await repository.archive(asset.id), isTrue);
  });
}
