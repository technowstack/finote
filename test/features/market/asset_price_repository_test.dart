import 'dart:io';

import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_transaction_action.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/market/data/asset_price_repository.dart';
import 'package:finote/features/market/domain/market_quote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AssetRepository assets;
  late AssetTransactionRepository activities;
  late AssetPriceRepository prices;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    assets = AssetRepository(database);
    activities = AssetTransactionRepository(database);
    prices = AssetPriceRepository(database);
  });

  tearDown(() => database.close());

  test(
    'manual price is exact, updates in place, and clear preserves holding',
    () async {
      final gold = await assets.create(
        name: 'Emas',
        assetType: AssetType.gold,
        pricingMode: AssetPricingMode.manual,
      );
      await activities.create(
        assetId: gold.id,
        action: AssetTransactionAction.buy,
        quantity: AssetQuantity.parse('5'),
        transactionDate: DateTime(2026, 9, 3),
      );

      await prices.setManualPrice(assetId: gold.id, price: 1500000);
      final first = await prices.getForAssets([gold.id]);
      expect(first[gold.id]?.price, 1500000);
      expect(first[gold.id]?.currency, 'IDR');
      expect(first[gold.id]?.isBackendStale, isFalse);

      await prices.setManualPrice(assetId: gold.id, price: 1550000);
      final updated = await prices.getForAssets([gold.id]);
      expect(updated, hasLength(1));
      expect(updated[gold.id]?.price, 1550000);
      expect(
        await activities.currentHolding(gold.id),
        AssetQuantity.parse('5'),
      );

      await prices.clearManualPrice(gold.id);
      expect(await prices.getForAssets([gold.id]), isEmpty);
      expect(
        await activities.currentHolding(gold.id),
        AssetQuantity.parse('5'),
      );
    },
  );

  test('manual price survives archive and display identity edits', () async {
    final fund = await assets.create(
      symbol: 'FUND',
      name: 'Reksadana ABC',
      assetType: AssetType.mutualFund,
      pricingMode: AssetPricingMode.manual,
    );
    await prices.setManualPrice(assetId: fund.id, price: 1845);

    expect(await assets.archive(fund.id), isTrue);
    expect((await prices.getForAssets([fund.id]))[fund.id]?.price, 1845);
    expect(
      await assets.update(
        id: fund.id,
        symbol: 'FUND2',
        name: 'Reksadana ABC Baru',
        assetType: AssetType.mutualFund,
        pricingMode: AssetPricingMode.manual,
      ),
      isTrue,
    );
    expect((await prices.getForAssets([fund.id]))[fund.id]?.price, 1845);
  });

  test('pricing mode changes never reuse the other source price', () async {
    final apiAsset = await assets.create(
      symbol: 'BBCA',
      name: 'Bank Central Asia',
      assetType: AssetType.stock,
      pricingMode: AssetPricingMode.api,
    );
    final apiQuote = MarketQuote(
      symbol: 'BBCA',
      name: null,
      assetType: AssetType.stock,
      price: 9200,
      currency: 'IDR',
      change: null,
      changePercent: null,
      marketStatus: MarketStatus.unknown,
      isStale: false,
      updatedAt: null,
    );
    await prices.saveQuotes({apiAsset.id: apiQuote});
    expect(
      (await prices.getForAssets([apiAsset.id]))[apiAsset.id]?.price,
      9200,
    );

    expect(
      await assets.update(
        id: apiAsset.id,
        symbol: 'BBCA',
        name: 'Bank Central Asia',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.manual,
      ),
      isTrue,
    );
    expect(await prices.getForAssets([apiAsset.id]), isEmpty);

    await prices.setManualPrice(assetId: apiAsset.id, price: 10000);
    expect(
      await assets.update(
        id: apiAsset.id,
        symbol: 'BBCA',
        name: 'Bank Central Asia',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.api,
      ),
      isTrue,
    );
    expect(await prices.getForAssets([apiAsset.id]), isEmpty);
  });

  test('zero manual price is rejected and no record is created', () async {
    final other = await assets.create(
      name: 'Koleksi',
      assetType: AssetType.other,
      pricingMode: AssetPricingMode.manual,
    );

    await expectLater(
      prices.setManualPrice(assetId: other.id, price: 0),
      throwsArgumentError,
    );
    expect(await prices.getForAssets([other.id]), isEmpty);
  });

  test('manual price survives reopening the SQLite database', () async {
    final directory = await Directory.systemTemp.createTemp('finote-price-');
    final path = '${directory.path}/finote.sqlite';
    final first = AppDatabase(NativeDatabase(File(path)));
    final other = await AssetRepository(first).create(
      name: 'Koleksi',
      assetType: AssetType.other,
      pricingMode: AssetPricingMode.manual,
    );
    await AssetPriceRepository(first)
        .setManualPrice(assetId: other.id, price: 500000);
    await first.close();

    final reopened = AppDatabase(NativeDatabase(File(path)));
    try {
      final restored = await AssetPriceRepository(reopened)
          .getForAssets([other.id]);
      expect(restored[other.id]?.price, 500000);
    } finally {
      await reopened.close();
      await directory.delete(recursive: true);
    }
  });
}
