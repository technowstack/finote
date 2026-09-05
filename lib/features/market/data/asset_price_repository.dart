import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../assets/domain/asset_type.dart';
import '../domain/market_quote.dart';

class LocalAssetPrice {
  const LocalAssetPrice({
    required this.assetId,
    required this.price,
    required this.currency,
    required this.marketUpdatedAt,
    required this.fetchedAt,
    required this.isBackendStale,
  });

  final int assetId;
  final int price;
  final String currency;
  final DateTime? marketUpdatedAt;
  final DateTime fetchedAt;
  final bool isBackendStale;

  DateTime get updatedAt => fetchedAt;
}

class AssetPriceRepository {
  AssetPriceRepository(this._database);

  final AppDatabase _database;

  Stream<Map<int, LocalAssetPrice>> watchActive() {
    return _database
        .customSelect(
          'SELECT ap.* FROM asset_prices ap '
          'JOIN assets a ON a.id = ap.asset_id WHERE a.is_active = 1',
          readsFrom: {_database.assetPrices, _database.assets},
        )
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read<int>('asset_id'): LocalAssetPrice(
                assetId: row.read<int>('asset_id'),
                price: row.read<int>('price_amount'),
                currency: row.read<String>('currency'),
                marketUpdatedAt: row.readNullable<DateTime>(
                  'market_updated_at',
                ),
                fetchedAt: row.read<DateTime>('fetched_at'),
                isBackendStale: row.read<bool>('is_backend_stale'),
              ),
          },
        );
  }

  Future<Map<int, LocalAssetPrice>> getForAssets(Iterable<int> assetIds) async {
    final ids = assetIds.toSet().toList();
    if (ids.isEmpty) return {};
    final rows = await (_database.select(
      _database.assetPrices,
    )..where((price) => price.assetId.isIn(ids))).get();
    return {
      for (final row in rows)
        row.assetId: LocalAssetPrice(
          assetId: row.assetId,
          price: row.priceAmount,
          currency: row.currency,
          marketUpdatedAt: row.marketUpdatedAt,
          fetchedAt: row.fetchedAt,
          isBackendStale: row.isBackendStale,
        ),
    };
  }

  Future<void> saveQuotes(
    Map<int, MarketQuote> quotes, {
    DateTime? fetchedAt,
  }) async {
    if (quotes.isEmpty) return;
    final fetched = (fetchedAt ?? DateTime.now()).toUtc();
    await _database.transaction(() async {
      final assets = await (_database.select(
        _database.assets,
      )..where((asset) => asset.id.isIn(quotes.keys))).get();
      final assetsById = {for (final asset in assets) asset.id: asset};
      for (final entry in quotes.entries) {
        final quote = entry.value;
        final asset = assetsById[entry.key];
        if (asset == null ||
            !asset.isActive ||
            asset.pricingMode != AssetPricingMode.api ||
            asset.assetType != quote.assetType ||
            asset.normalizedSymbol != quote.symbol.trim().toUpperCase() ||
            asset.currency != quote.currency.trim().toUpperCase() ||
            quote.price <= 0) {
          continue;
        }
        final companion = AssetPricesCompanion(
          assetId: Value(entry.key),
          priceAmount: Value(quote.price),
          currency: Value(quote.currency),
          marketUpdatedAt: Value(quote.updatedAt),
          fetchedAt: Value(fetched),
          isBackendStale: Value(quote.isStale),
        );
        final updated = await (_database.update(
          _database.assetPrices,
        )..where((price) => price.assetId.equals(entry.key))).write(companion);
        if (updated == 0) {
          await _database.into(_database.assetPrices).insert(companion);
        }
      }
    });
  }

  Stream<LocalAssetPrice?> watchCurrentPrice(int assetId) {
    return (_database.select(_database.assetPrices)
          ..where((price) => price.assetId.equals(assetId)))
        .watchSingleOrNull()
        .map(_fromRecord);
  }

  Future<void> setManualPrice({
    required int assetId,
    required int price,
    String currency = 'IDR',
  }) async {
    if (price <= 0) {
      throw ArgumentError.value(price, 'price', 'Price must be greater than 0');
    }
    final asset = await (_database.select(
      _database.assets,
    )..where((asset) => asset.id.equals(assetId))).getSingleOrNull();
    if (asset == null || asset.pricingMode != AssetPricingMode.manual) {
      throw StateError('Manual price requires a manual-priced asset');
    }
    final normalizedCurrency = currency.trim().toUpperCase();
    if (normalizedCurrency.isEmpty) {
      throw ArgumentError.value(currency, 'currency', 'Currency is required');
    }
    final now = DateTime.now().toUtc();
    final companion = AssetPricesCompanion(
      assetId: Value(assetId),
      priceAmount: Value(price),
      currency: Value(normalizedCurrency),
      marketUpdatedAt: const Value(null),
      fetchedAt: Value(now),
      isBackendStale: const Value(false),
    );
    await _database.transaction(() async {
      final updated = await (_database.update(
        _database.assetPrices,
      )..where((row) => row.assetId.equals(assetId))).write(companion);
      if (updated == 0) {
        await _database.into(_database.assetPrices).insert(companion);
      }
    });
  }

  Future<void> clearManualPrice(int assetId) async {
    final asset = await (_database.select(
      _database.assets,
    )..where((asset) => asset.id.equals(assetId))).getSingleOrNull();
    if (asset == null || asset.pricingMode != AssetPricingMode.manual) {
      throw StateError('Manual price requires a manual-priced asset');
    }
    await deleteForAsset(assetId);
  }

  Future<void> deleteForAsset(int assetId) async {
    await (_database.delete(
      _database.assetPrices,
    )..where((price) => price.assetId.equals(assetId))).go();
  }

  LocalAssetPrice? _fromRecord(AssetPriceRecord? row) => row == null
      ? null
      : LocalAssetPrice(
          assetId: row.assetId,
          price: row.priceAmount,
          currency: row.currency,
          marketUpdatedAt: row.marketUpdatedAt,
          fetchedAt: row.fetchedAt,
          isBackendStale: row.isBackendStale,
        );
}

final assetPriceRepositoryProvider = Provider<AssetPriceRepository>(
  (ref) => AssetPriceRepository(ref.watch(databaseProvider)),
);

final activeAssetPricesProvider = StreamProvider<Map<int, LocalAssetPrice>>(
  (ref) => ref.watch(assetPriceRepositoryProvider).watchActive(),
);

final currentAssetPriceProvider = StreamProvider.autoDispose
    .family<LocalAssetPrice?, int>(
      (ref, assetId) =>
          ref.watch(assetPriceRepositoryProvider).watchCurrentPrice(assetId),
    );
