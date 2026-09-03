import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/market/data/asset_price_repository.dart';
import 'package:finote/features/market/data/portfolio_valuation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<AssetRecord> makeAsset(AssetType type) => database
      .into(database.assets)
      .insertReturning(
        AssetsCompanion.insert(
          name: type.label,
          assetType: type,
          pricingMode: type.defaultPricingMode,
        ),
      );

  LocalAssetPrice makePrice(int assetId, int amount, {bool stale = false}) =>
      LocalAssetPrice(
        assetId: assetId,
        price: amount,
        currency: 'IDR',
        marketUpdatedAt: null,
        fetchedAt: DateTime.utc(2026, 9, 3),
        isBackendStale: stale,
      );

  test('values canonical stock shares, not displayed lots', () async {
    final asset = await makeAsset(AssetType.stock);
    final valuation = PortfolioValuationService().valueFor(
      AssetHolding(
        asset: asset,
        quantity: AssetQuantity.parse('1300'),
        hasActivity: true,
      ),
      makePrice(asset.id, 9200),
    );

    expect(valuation.currentValue, 11960000);
    expect(valuation.currentValue, isNot(119600));
  });

  test('values fractional crypto, gold, and mutual fund quantities', () async {
    final service = PortfolioValuationService();
    final crypto = await makeAsset(AssetType.crypto);
    final gold = await makeAsset(AssetType.gold);
    final fund = await makeAsset(AssetType.mutualFund);

    expect(
      service
          .valueFor(
            AssetHolding(
              asset: crypto,
              quantity: AssetQuantity.parse('0.015'),
              hasActivity: true,
            ),
            makePrice(crypto.id, 1100000000),
          )
          .currentValue,
      16500000,
    );
    expect(
      service
          .valueFor(
            AssetHolding(
              asset: gold,
              quantity: AssetQuantity.parse('5.25'),
              hasActivity: true,
            ),
            makePrice(gold.id, 1500000),
          )
          .currentValue,
      7875000,
    );
    expect(
      service
          .valueFor(
            AssetHolding(
              asset: fund,
              quantity: AssetQuantity.parse('123.4567'),
              hasActivity: true,
            ),
            makePrice(fund.id, 1845),
          )
          .currentValue,
      227778,
    );
  });

  test(
    'snapshot handles partial, zero, empty, stale, and negative states',
    () async {
      final service = PortfolioValuationService();
      final priced = await makeAsset(AssetType.stock);
      final missing = await makeAsset(AssetType.crypto);
      final zero = await makeAsset(AssetType.other);
      final noPosition = await makeAsset(AssetType.mutualFund);
      final negative = await makeAsset(AssetType.stock);
      final snapshot = service.buildSnapshot(
        [
          AssetHolding(
            asset: priced,
            quantity: AssetQuantity.parse('5'),
            hasActivity: true,
          ),
          AssetHolding(
            asset: missing,
            quantity: AssetQuantity.parse('1'),
            hasActivity: true,
          ),
          AssetHolding(
            asset: zero,
            quantity: AssetQuantity.fromScaled(0),
            hasActivity: true,
          ),
          AssetHolding(
            asset: noPosition,
            quantity: AssetQuantity.fromScaled(0),
            hasActivity: false,
          ),
          AssetHolding(
            asset: negative,
            quantity: AssetQuantity.fromScaled(-1),
            hasActivity: true,
          ),
        ],
        {
          priced.id: makePrice(priced.id, 1500000, stale: true),
          zero.id: makePrice(zero.id, 500000),
          noPosition.id: makePrice(noPosition.id, 1000),
        },
      );

      expect(snapshot.totalKnownValue, 7500000);
      expect(snapshot.isPartial, isTrue);
      expect(snapshot.valuedAssetCount, 2);
      expect(snapshot.unvaluedAssetCount, 2);
      expect(snapshot.integrityIssueCount, 1);
      expect(snapshot.groups[AssetType.stock]?.knownValue, 7500000);
      expect(snapshot.groups[AssetType.other]?.knownValue, 0);
      expect(snapshot.byAssetId[priced.id]?.isBackendStale, isTrue);
    },
  );
}
