import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/assets.dart';
import '../domain/asset_quantity.dart';
import '../domain/asset_transaction_action.dart';

class AssetTransactionRepository {
  AssetTransactionRepository(this._database);

  final AppDatabase _database;

  Stream<List<AssetTransactionRecord>> watchByAsset(int assetId) {
    return (_database.select(_database.assetTransactions)
          ..where(
            (activity) =>
                activity.assetId.equals(assetId) & activity.deletedAt.isNull(),
          )
          ..orderBy([
            (activity) => OrderingTerm.desc(activity.transactionDate),
            (activity) => OrderingTerm.desc(activity.createdAt),
            (activity) => OrderingTerm.desc(activity.id),
          ]))
        .watch();
  }

  Future<AssetTransactionRecord> create({
    required int assetId,
    required AssetTransactionAction action,
    required AssetQuantity quantity,
    int? priceAmount,
    int? totalAmount,
    required DateTime transactionDate,
    String? note,
    int? sourceTransactionId,
  }) async {
    _validate(action, quantity, priceAmount, totalAmount);
    if (action == AssetTransactionAction.openingPosition &&
        await getOpeningPosition(assetId) != null) {
      throw StateError('Opening position already exists');
    }
    return _database
        .into(_database.assetTransactions)
        .insertReturning(
          AssetTransactionsCompanion.insert(
            assetId: assetId,
            action: action,
            quantityScaled: quantity.scaled,
            priceAmount: Value(priceAmount),
            totalAmount: Value(totalAmount),
            transactionDate: transactionDate,
            note: Value(note?.trim()),
            sourceTransactionId: Value(sourceTransactionId),
          ),
        );
  }

  Future<AssetTransactionRecord?> getOpeningPosition(int assetId) {
    return (_database.select(_database.assetTransactions)..where(
          (activity) =>
              activity.assetId.equals(assetId) &
              activity.action.equals(
                AssetTransactionAction.openingPosition.name,
              ) &
              activity.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<AssetTransactionRecord> createOpeningPosition({
    required int assetId,
    required AssetQuantity quantity,
    required DateTime transactionDate,
    int? totalAmount,
    String? note,
  }) async {
    return _database.transaction(() async {
      if (await getOpeningPosition(assetId) != null) {
        throw StateError('Opening position already exists');
      }
      return create(
        assetId: assetId,
        action: AssetTransactionAction.openingPosition,
        quantity: quantity,
        transactionDate: transactionDate,
        totalAmount: totalAmount,
        note: note,
      );
    });
  }

  Future<bool> updateOpeningPosition({
    required int id,
    required AssetQuantity quantity,
    required DateTime transactionDate,
    int? totalAmount,
    String? note,
  }) async {
    _validate(
      AssetTransactionAction.openingPosition,
      quantity,
      null,
      totalAmount,
    );
    final count =
        await (_database.update(_database.assetTransactions)..where(
              (activity) =>
                  activity.id.equals(id) &
                  activity.action.equals(
                    AssetTransactionAction.openingPosition.name,
                  ) &
                  activity.deletedAt.isNull(),
            ))
            .write(
              AssetTransactionsCompanion(
                quantityScaled: Value(quantity.scaled),
                totalAmount: Value(totalAmount),
                transactionDate: Value(transactionDate),
                note: Value(note?.trim()),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    return count == 1;
  }

  Future<bool> removeOpeningPosition(int id) async {
    final opening =
        await (_database.select(_database.assetTransactions)..where(
              (activity) =>
                  activity.id.equals(id) &
                  activity.action.equals(
                    AssetTransactionAction.openingPosition.name,
                  ) &
                  activity.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (opening == null) return false;
    final laterActivities =
        await (_database.select(_database.assetTransactions)..where(
              (activity) =>
                  activity.assetId.equals(opening.assetId) &
                  activity.id.isNotIn([id]) &
                  activity.deletedAt.isNull(),
            ))
            .get();
    if (laterActivities.isNotEmpty) {
      throw StateError('Opening position has later activities');
    }
    return softDelete(id);
  }

  Future<AssetQuantity> currentHolding(int assetId) async {
    return currentHoldingExcluding(assetId);
  }

  Future<AssetQuantity> currentHoldingExcluding(
    int assetId, [
    int? excludedId,
  ]) async {
    final row = await _database
        .customSelect(
          '''
SELECT COALESCE(SUM(
  CASE
    WHEN action IN ('openingPosition', 'buy') THEN quantity_scaled
    WHEN action = 'sell' THEN -quantity_scaled
    ELSE quantity_scaled
  END
), 0) AS quantity_scaled
FROM asset_transactions
WHERE asset_id = ? AND deleted_at IS NULL ${excludedId == null ? '' : 'AND id <> ?'}
''',
          variables: [
            Variable.withInt(assetId),
            if (excludedId != null) Variable.withInt(excludedId),
          ],
          readsFrom: {_database.assetTransactions},
        )
        .getSingle();
    return AssetQuantity.fromScaled(row.read<int>('quantity_scaled'));
  }

  Future<bool> softDelete(int id) async {
    final now = DateTime.now().toUtc();
    final count =
        await (_database.update(_database.assetTransactions)..where(
              (activity) =>
                  activity.id.equals(id) & activity.deletedAt.isNull(),
            ))
            .write(
              AssetTransactionsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
    return count == 1;
  }

  Stream<List<AssetHolding>> watchHoldings() =>
      _watchHoldings(activeOnly: true);

  Stream<List<AssetHolding>> watchAllHoldings() =>
      _watchHoldings(activeOnly: false);

  Stream<List<AssetHolding>> _watchHoldings({required bool activeOnly}) {
    return _database
        .customSelect(
          '''
SELECT a.*, COALESCE(SUM(
  CASE
    WHEN at.action IN ('openingPosition', 'buy') THEN at.quantity_scaled
    WHEN at.action = 'sell' THEN -at.quantity_scaled
    ELSE at.quantity_scaled
  END
 ), 0) AS holding_quantity_scaled,
 COUNT(at.id) > 0 AS has_activity
FROM assets a
LEFT JOIN asset_transactions at
  ON at.asset_id = a.id AND at.deleted_at IS NULL
${activeOnly ? 'WHERE a.is_active = 1' : ''}
GROUP BY a.id
ORDER BY a.name ASC
''',
          readsFrom: {_database.assets, _database.assetTransactions},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              AssetHolding(
                asset: AssetRecord(
                  id: row.read<int>('id'),
                  uuid: row.read<String>('uuid'),
                  symbol: row.readNullable<String>('symbol'),
                  normalizedSymbol: row.readNullable<String>(
                    'normalized_symbol',
                  ),
                  name: row.read<String>('name'),
                  assetType: const AssetTypeConverter().fromSql(
                    row.read<String>('asset_type'),
                  ),
                  pricingMode: const AssetPricingModeConverter().fromSql(
                    row.read<String>('pricing_mode'),
                  ),
                  currency: row.read<String>('currency'),
                  unitLabel: row.readNullable<String>('unit_label'),
                  isActive: row.read<bool>('is_active'),
                  createdAt: row.read<DateTime>('created_at'),
                  updatedAt: row.read<DateTime>('updated_at'),
                ),
                quantity: AssetQuantity.fromScaled(
                  row.read<int>('holding_quantity_scaled'),
                ),
                hasActivity: row.read<bool>('has_activity'),
              ),
          ],
        );
  }

  Future<List<AssetHolding>> findNegativeHoldings() async {
    final rows = await _watchHoldings(activeOnly: false).first;
    return rows.where((holding) => holding.quantity.isNegative).toList();
  }

  void _validate(
    AssetTransactionAction action,
    AssetQuantity quantity,
    int? priceAmount,
    int? totalAmount,
  ) {
    if (quantity.isZero) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Quantity cannot be zero',
      );
    }
    if (action != AssetTransactionAction.adjustment && quantity.isNegative) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Opening, buy, and sell quantities must be positive',
      );
    }
    if (priceAmount != null && priceAmount < 0) {
      throw ArgumentError.value(
        priceAmount,
        'priceAmount',
        'Price cannot be negative',
      );
    }
    if (totalAmount != null && totalAmount < 0) {
      throw ArgumentError.value(
        totalAmount,
        'totalAmount',
        'Total amount cannot be negative',
      );
    }
  }
}

class AssetHolding {
  const AssetHolding({
    required this.asset,
    required this.quantity,
    required this.hasActivity,
  });

  final AssetRecord asset;
  final AssetQuantity quantity;
  final bool hasActivity;

  bool get isConsistent => !quantity.isNegative;
}

final assetTransactionRepositoryProvider = Provider<AssetTransactionRepository>(
  (ref) => AssetTransactionRepository(ref.watch(databaseProvider)),
);

final assetActivitiesProvider =
    StreamProvider.family<List<AssetTransactionRecord>, int>((ref, assetId) {
      return ref
          .watch(assetTransactionRepositoryProvider)
          .watchByAsset(assetId);
    });

final assetHoldingsProvider = StreamProvider<List<AssetHolding>>(
  (ref) => ref.watch(assetTransactionRepositoryProvider).watchHoldings(),
);

final allAssetHoldingsProvider = StreamProvider<List<AssetHolding>>(
  (ref) => ref.watch(assetTransactionRepositoryProvider).watchAllHoldings(),
);

final holdingProvider = Provider.family<AsyncValue<AssetHolding?>, int>(
  (ref, assetId) => ref
      .watch(allAssetHoldingsProvider)
      .whenData(
        (holdings) => holdings
            .where((holding) => holding.asset.id == assetId)
            .firstOrNull,
      ),
);
