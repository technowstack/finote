import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'asset_transaction_repository.dart';
import '../domain/asset_quantity.dart';
import '../domain/asset_transaction_action.dart';
import '../domain/asset_type.dart';
import '../../transactions/domain/transaction_source.dart';
import '../../transactions/domain/transaction_type.dart';

class AssetActivityService {
  AssetActivityService(this._database);

  final AppDatabase _database;

  AssetTransactionRepository get _holdings =>
      AssetTransactionRepository(_database);

  Future<AssetTransactionRecord> createBuy({
    required int assetId,
    required AssetQuantity quantity,
    required int priceAmount,
    required int accountId,
    required DateTime date,
    String? note,
  }) => _createCashflowActivity(
    assetId: assetId,
    action: AssetTransactionAction.buy,
    quantity: quantity,
    priceAmount: priceAmount,
    accountId: accountId,
    date: date,
    note: note,
    type: TransactionType.expense,
    categoryName: 'Pembelian Aset',
    titlePrefix: 'Beli',
  );

  Future<AssetTransactionRecord> createSell({
    required int assetId,
    required AssetQuantity quantity,
    required int priceAmount,
    required int accountId,
    required DateTime date,
    String? note,
  }) async {
    return _createCashflowActivity(
      assetId: assetId,
      action: AssetTransactionAction.sell,
      quantity: quantity,
      priceAmount: priceAmount,
      accountId: accountId,
      date: date,
      note: note,
      type: TransactionType.income,
      categoryName: 'Penjualan Aset',
      titlePrefix: 'Jual',
    );
  }

  Future<AssetTransactionRecord> createAdjustment({
    required int assetId,
    required AssetQuantity quantity,
    required DateTime date,
    String? note,
  }) async {
    if (quantity.isZero) throw ArgumentError('Adjustment cannot be zero');
    return _database.transaction(() async {
      final current = await _holdings.currentHolding(assetId);
      if ((current + quantity).scaled < 0) {
        throw StateError('Adjustment would make holdings negative');
      }
      return _insertActivity(
        assetId: assetId,
        action: AssetTransactionAction.adjustment,
        quantity: quantity,
        date: date,
        note: note,
      );
    });
  }

  Future<AssetTransactionRecord> updateBuy({
    required int activityId,
    required AssetQuantity quantity,
    required int priceAmount,
    required int accountId,
    required DateTime date,
    String? note,
  }) => _updateCashflowActivity(
    activityId: activityId,
    action: AssetTransactionAction.buy,
    quantity: quantity,
    priceAmount: priceAmount,
    accountId: accountId,
    date: date,
    note: note,
    type: TransactionType.expense,
    categoryName: 'Pembelian Aset',
    titlePrefix: 'Beli',
  );

  Future<AssetTransactionRecord> updateSell({
    required int activityId,
    required AssetQuantity quantity,
    required int priceAmount,
    required int accountId,
    required DateTime date,
    String? note,
  }) => _updateCashflowActivity(
    activityId: activityId,
    action: AssetTransactionAction.sell,
    quantity: quantity,
    priceAmount: priceAmount,
    accountId: accountId,
    date: date,
    note: note,
    type: TransactionType.income,
    categoryName: 'Penjualan Aset',
    titlePrefix: 'Jual',
  );

  Future<AssetTransactionRecord> updateAdjustment({
    required int activityId,
    required AssetQuantity quantity,
    required DateTime date,
    String? note,
  }) async {
    if (quantity.isZero) throw ArgumentError('Adjustment cannot be zero');
    return _database.transaction(() async {
      final current = await _activity(activityId);
      if (current == null ||
          current.action != AssetTransactionAction.adjustment) {
        throw StateError('Adjustment not found');
      }
      final base = await _holdings.currentHoldingExcluding(
        current.assetId,
        activityId,
      );
      if ((base + quantity).scaled < 0) {
        throw StateError('Adjustment would make holdings negative');
      }
      await _updateActivityRow(
        activityId: activityId,
        quantity: quantity,
        date: date,
        note: note,
      );
      return (await _activity(activityId))!;
    });
  }

  Future<bool> delete(int activityId) async {
    return _database.transaction(() async {
      final activity = await _activity(activityId);
      if (activity == null) return false;
      final remaining = await _holdings.currentHoldingExcluding(
        activity.assetId,
        activityId,
      );
      if (remaining.isNegative) {
        throw StateError('Delete would make holdings negative');
      }
      final now = DateTime.now().toUtc();
      if (activity.sourceTransactionId case final transactionId?) {
        await (_database.update(_database.transactions)..where(
              (row) => row.id.equals(transactionId) & row.deletedAt.isNull(),
            ))
            .write(
              TransactionsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
      return (await (_database.update(_database.assetTransactions)..where(
                (row) => row.id.equals(activityId) & row.deletedAt.isNull(),
              ))
              .write(
                AssetTransactionsCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                ),
              )) ==
          1;
    });
  }

  Future<AssetTransactionRecord> _createCashflowActivity({
    required int assetId,
    required AssetTransactionAction action,
    required AssetQuantity quantity,
    required int priceAmount,
    required int accountId,
    required DateTime date,
    required String? note,
    required TransactionType type,
    required String categoryName,
    required String titlePrefix,
  }) async {
    _validatePrice(priceAmount);
    _validatePositive(quantity);
    return _database.transaction(() async {
      final asset = await _requireAsset(assetId);
      if (action == AssetTransactionAction.sell) {
        await _requireSellable(assetId, quantity);
      }
      await _requireAccount(accountId);
      final categoryId = await _requireCategory(categoryName, type);
      final total = _total(quantity, priceAmount, asset.assetType);
      final transaction = await _database
          .into(_database.transactions)
          .insertReturning(
            TransactionsCompanion.insert(
              type: type,
              accountId: Value(accountId),
              categoryId: categoryId,
              amount: total,
              title: Value('$titlePrefix ${asset.symbol ?? asset.name}'),
              note: Value(note?.trim()),
              transactionDate: date,
              source: TransactionSource.manual,
            ),
          );
      return _insertActivity(
        assetId: assetId,
        action: action,
        quantity: quantity,
        priceAmount: priceAmount,
        totalAmount: total,
        date: date,
        note: note,
        sourceTransactionId: transaction.id,
      );
    });
  }

  Future<AssetTransactionRecord> _updateCashflowActivity({
    required int activityId,
    required AssetTransactionAction action,
    required AssetQuantity quantity,
    required int priceAmount,
    required int accountId,
    required DateTime date,
    required String? note,
    required TransactionType type,
    required String categoryName,
    required String titlePrefix,
  }) async {
    _validatePrice(priceAmount);
    _validatePositive(quantity);
    return _database.transaction(() async {
      final activity = await _activity(activityId);
      if (activity == null || activity.action != action) {
        throw StateError('Asset activity not found');
      }
      final base = await _holdings.currentHoldingExcluding(
        activity.assetId,
        activityId,
      );
      final result = action == AssetTransactionAction.sell
          ? base - quantity
          : base + quantity;
      if (result.isNegative) {
        throw StateError(
          action == AssetTransactionAction.sell
              ? 'Sell quantity exceeds holdings'
              : 'Activity would make holdings negative',
        );
      }
      final asset = await _requireAsset(activity.assetId);
      final categoryId = await _requireCategory(categoryName, type);
      final total = _total(quantity, priceAmount, asset.assetType);
      final transactionId = activity.sourceTransactionId;
      if (transactionId == null) throw StateError('Linked cashflow is missing');
      final transaction =
          await (_database.select(_database.transactions)..where(
                (row) => row.id.equals(transactionId) & row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (transaction == null) throw StateError('Linked cashflow is missing');
      await _requireAccountForUpdate(accountId, transaction.accountId);
      await (_database.update(_database.transactions)..where(
            (row) => row.id.equals(transactionId) & row.deletedAt.isNull(),
          ))
          .write(
            transaction
                .copyWith(
                  type: type,
                  categoryId: categoryId,
                  accountId: Value(accountId),
                  amount: total,
                  title: '$titlePrefix ${asset.symbol ?? asset.name}',
                  note: Value(note?.trim()),
                  transactionDate: date,
                  updatedAt: DateTime.now().toUtc(),
                )
                .toCompanion(true),
          );
      await _updateActivityRow(
        activityId: activityId,
        quantity: quantity,
        priceAmount: priceAmount,
        totalAmount: total,
        date: date,
        note: note,
      );
      return (await _activity(activityId))!;
    });
  }

  Future<AssetTransactionRecord> _insertActivity({
    required int assetId,
    required AssetTransactionAction action,
    required AssetQuantity quantity,
    required DateTime date,
    String? note,
    int? priceAmount,
    int? totalAmount,
    int? sourceTransactionId,
  }) {
    return _database
        .into(_database.assetTransactions)
        .insertReturning(
          AssetTransactionsCompanion.insert(
            assetId: assetId,
            action: action,
            quantityScaled: quantity.scaled,
            priceAmount: Value(priceAmount),
            totalAmount: Value(totalAmount),
            transactionDate: date,
            note: Value(note?.trim()),
            sourceTransactionId: Value(sourceTransactionId),
          ),
        );
  }

  Future<void> _updateActivityRow({
    required int activityId,
    required AssetQuantity quantity,
    required DateTime date,
    String? note,
    int? priceAmount,
    int? totalAmount,
  }) async {
    await (_database.update(_database.assetTransactions)
          ..where((row) => row.id.equals(activityId) & row.deletedAt.isNull()))
        .write(
          AssetTransactionsCompanion(
            quantityScaled: Value(quantity.scaled),
            priceAmount: Value(priceAmount),
            totalAmount: Value(totalAmount),
            transactionDate: Value(date),
            note: Value(note?.trim()),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<AssetTransactionRecord?> _activity(int id) {
    return (_database.select(_database.assetTransactions)
          ..where((row) => row.id.equals(id) & row.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<AssetRecord> _requireAsset(int id) async {
    final asset =
        await (_database.select(_database.assets)
              ..where((row) => row.id.equals(id) & row.isActive.equals(true)))
            .getSingleOrNull();
    if (asset == null) throw StateError('Active asset not found');
    return asset;
  }

  Future<void> _requireAccount(int id) async {
    final account =
        await (_database.select(_database.accounts)
              ..where((row) => row.id.equals(id) & row.isActive.equals(true)))
            .getSingleOrNull();
    if (account == null) throw StateError('Active account not found');
  }

  Future<void> _requireAccountForUpdate(int id, int? currentAccountId) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (account == null || (!account.isActive && currentAccountId != id)) {
      throw StateError('Active account not found');
    }
  }

  Future<int> _requireCategory(String name, TransactionType type) async {
    final category =
        await (_database.select(_database.categories)..where(
              (row) =>
                  row.name.equals(name) &
                  row.type.equals(type.name) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (category == null) throw StateError('$name category is unavailable');
    return category.id;
  }

  Future<void> _requireSellable(int assetId, AssetQuantity quantity) async {
    _validatePositive(quantity);
    if ((await _holdings.currentHolding(assetId)).scaled < quantity.scaled) {
      throw StateError('Sell quantity exceeds holdings');
    }
  }

  int _total(AssetQuantity quantity, int price, AssetType type) {
    final units = type == AssetType.stock
        ? BigInt.from(quantity.scaled ~/ AssetQuantity.scale)
        : BigInt.from(quantity.scaled);
    final divisor = type == AssetType.stock
        ? BigInt.one
        : BigInt.from(AssetQuantity.scale);
    final result = units * BigInt.from(price) ~/ divisor;
    if (result <= BigInt.zero || result > BigInt.from(9223372036854775807)) {
      throw ArgumentError('Total amount is out of range');
    }
    return result.toInt();
  }

  void _validatePositive(AssetQuantity quantity) {
    if (quantity.isZero || quantity.isNegative) {
      throw ArgumentError('Quantity must be positive');
    }
  }

  void _validatePrice(int price) {
    if (price <= 0) throw ArgumentError('Price must be positive');
  }
}

final assetActivityServiceProvider = Provider<AssetActivityService>(
  (ref) => AssetActivityService(ref.watch(databaseProvider)),
);
