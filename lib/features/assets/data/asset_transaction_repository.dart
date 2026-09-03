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
            (activity) => OrderingTerm.asc(activity.transactionDate),
            (activity) => OrderingTerm.asc(activity.createdAt),
            (activity) => OrderingTerm.asc(activity.id),
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

  Future<AssetQuantity> currentHolding(int assetId) async {
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
WHERE asset_id = ? AND deleted_at IS NULL
''',
          variables: [Variable.withInt(assetId)],
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

  Stream<List<AssetHolding>> watchHoldings() {
    return _database
        .customSelect(
          '''
SELECT a.*, COALESCE(SUM(
  CASE
    WHEN at.action IN ('openingPosition', 'buy') THEN at.quantity_scaled
    WHEN at.action = 'sell' THEN -at.quantity_scaled
    ELSE at.quantity_scaled
  END
), 0) AS holding_quantity_scaled
FROM assets a
LEFT JOIN asset_transactions at
  ON at.asset_id = a.id AND at.deleted_at IS NULL
GROUP BY a.id
ORDER BY a.is_active DESC, a.name ASC
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
              ),
          ],
        );
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
  const AssetHolding({required this.asset, required this.quantity});

  final AssetRecord asset;
  final AssetQuantity quantity;
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
