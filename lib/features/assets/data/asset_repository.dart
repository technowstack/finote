import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/asset_type.dart';

class AssetRepository {
  AssetRepository(this._database);

  final AppDatabase _database;

  Stream<List<AssetRecord>> watchActive() {
    return (_database.select(_database.assets)
          ..where((asset) => asset.isActive.equals(true))
          ..orderBy([(asset) => OrderingTerm.asc(asset.name)]))
        .watch();
  }

  Stream<List<AssetRecord>> watchAll() {
    return (_database.select(_database.assets)..orderBy([
          (asset) => OrderingTerm.desc(asset.isActive),
          (asset) => OrderingTerm.asc(asset.name),
        ]))
        .watch();
  }

  Future<AssetRecord?> findById(int id) {
    return (_database.select(
      _database.assets,
    )..where((asset) => asset.id.equals(id))).getSingleOrNull();
  }

  Stream<AssetRecord?> watchById(int id) {
    return (_database.select(
      _database.assets,
    )..where((asset) => asset.id.equals(id))).watchSingleOrNull();
  }

  Future<AssetUsage?> getUsage(int id) async {
    final row = await _database
        .customSelect(
          '''
          SELECT a.id,
                 (SELECT COUNT(*) FROM asset_transactions at
                  WHERE at.asset_id = a.id) AS activity_count
          FROM assets a
          WHERE a.id = ?
          ''',
          variables: [Variable.withInt(id)],
          readsFrom: {_database.assets, _database.assetTransactions},
        )
        .getSingleOrNull();
    if (row == null) return null;
    return AssetUsage(activityCount: row.read<int>('activity_count'));
  }

  Future<bool> canDelete(int id) async =>
      (await getUsage(id))?.canDelete ?? false;

  Future<bool> deleteUnused(int id) {
    return _database.transaction(() async {
      final usage = await getUsage(id);
      if (usage == null || !usage.canDelete) return false;
      await (_database.delete(
        _database.assetPrices,
      )..where((price) => price.assetId.equals(id))).go();
      final deleted = await (_database.delete(
        _database.assets,
      )..where((asset) => asset.id.equals(id))).go();
      return deleted == 1;
    });
  }

  Future<bool> update({
    required int id,
    String? symbol,
    required String name,
    required AssetType assetType,
    required AssetPricingMode pricingMode,
    String currency = 'IDR',
    String? unitLabel,
  }) async {
    final normalizedName = _validateName(name);
    final normalizedCurrency = _validateCurrency(currency);
    final normalizedSymbol = _normalizeSymbol(symbol);
    await _requireUniqueSymbol(assetType, normalizedSymbol, excludingId: id);
    return _database.transaction(() async {
      final existing = await findById(id);
      if (existing == null) return false;
      final pricingSemanticsChanged =
          existing.assetType != assetType ||
          existing.pricingMode != pricingMode ||
          existing.currency != normalizedCurrency;
      final apiSymbolChanged =
          existing.pricingMode == AssetPricingMode.api &&
          existing.normalizedSymbol != normalizedSymbol;
      final count =
          await (_database.update(
            _database.assets,
          )..where((asset) => asset.id.equals(id))).write(
            AssetsCompanion(
              symbol: Value(symbol?.trim()),
              normalizedSymbol: Value(normalizedSymbol),
              name: Value(normalizedName),
              assetType: Value(assetType),
              pricingMode: Value(pricingMode),
              currency: Value(normalizedCurrency),
              unitLabel: Value(unitLabel?.trim()),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      if (pricingSemanticsChanged || apiSymbolChanged) {
        await (_database.delete(
          _database.assetPrices,
        )..where((price) => price.assetId.equals(id))).go();
      }
      return count == 1;
    });
  }

  Future<AssetRecord> create({
    String? symbol,
    required String name,
    required AssetType assetType,
    required AssetPricingMode pricingMode,
    String currency = 'IDR',
    String? unitLabel,
  }) async {
    final normalizedName = _validateName(name);
    final normalizedCurrency = _validateCurrency(currency);
    final normalizedSymbol = _normalizeSymbol(symbol);
    await _requireUniqueSymbol(assetType, normalizedSymbol);
    return _database
        .into(_database.assets)
        .insertReturning(
          AssetsCompanion.insert(
            symbol: Value(symbol?.trim()),
            normalizedSymbol: Value(normalizedSymbol),
            name: normalizedName,
            assetType: assetType,
            pricingMode: pricingMode,
            currency: Value(normalizedCurrency),
            unitLabel: Value(unitLabel?.trim()),
          ),
        );
  }

  Future<bool> archive(int id) async {
    final count =
        await (_database.update(_database.assets)..where(
              (asset) => asset.id.equals(id) & asset.isActive.equals(true),
            ))
            .write(
              AssetsCompanion(
                isActive: const Value(false),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    return count == 1;
  }

  Future<bool> reactivate(int id) async {
    final count =
        await (_database.update(_database.assets)..where(
              (asset) => asset.id.equals(id) & asset.isActive.equals(false),
            ))
            .write(
              AssetsCompanion(
                isActive: const Value(true),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    return count == 1;
  }

  String _validateName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'name', 'Asset name cannot be empty');
    }
    return normalized;
  }

  String _validateCurrency(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'currency',
        'Asset currency cannot be empty',
      );
    }
    return normalized;
  }

  String? _normalizeSymbol(String? value) {
    final normalized = value?.trim().toUpperCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<void> _requireUniqueSymbol(
    AssetType type,
    String? symbol, {
    int? excludingId,
  }) async {
    if (symbol == null) return;
    final existing =
        await (_database.select(_database.assets)..where(
              (asset) =>
                  asset.assetType.equals(type.databaseValue) &
                  asset.normalizedSymbol.equals(symbol),
            ))
            .getSingleOrNull();
    if (existing != null && existing.id != excludingId) {
      throw StateError('Asset symbol already exists');
    }
  }
}

class AssetUsage {
  const AssetUsage({required this.activityCount});

  final int activityCount;

  bool get canDelete => activityCount == 0;
}

final assetRepositoryProvider = Provider<AssetRepository>(
  (ref) => AssetRepository(ref.watch(databaseProvider)),
);

final assetsProvider = StreamProvider<List<AssetRecord>>(
  (ref) => ref.watch(assetRepositoryProvider).watchActive(),
);

final allAssetsProvider = StreamProvider<List<AssetRecord>>(
  (ref) => ref.watch(assetRepositoryProvider).watchAll(),
);

final assetByIdProvider = StreamProvider.autoDispose.family<AssetRecord?, int>(
  (ref, id) => ref.watch(assetRepositoryProvider).watchById(id),
);
