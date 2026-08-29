import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/transaction_source.dart';
import '../domain/transaction_type.dart';

class TransactionRepository {
  TransactionRepository(this._database);

  final AppDatabase _database;

  Stream<List<TransactionListItem>> watchAll() {
    final query =
        _database.select(_database.transactions).join([
            innerJoin(
              _database.categories,
              _database.categories.id.equalsExp(
                _database.transactions.categoryId,
              ),
            ),
          ])
          ..where(_database.transactions.deletedAt.isNull())
          ..orderBy([
            OrderingTerm.desc(_database.transactions.transactionDate),
            OrderingTerm.desc(_database.transactions.createdAt),
          ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => (
              transaction: row.readTable(_database.transactions),
              category: row.readTable(_database.categories),
            ),
          )
          .toList(),
    );
  }

  Future<TransactionRecord> create({
    required TransactionType type,
    required int categoryId,
    required int amount,
    required DateTime transactionDate,
    String title = '',
    String? note,
    TransactionSource source = TransactionSource.manual,
    String? legacySource,
    int? legacyId,
  }) {
    _validateAmount(amount);
    _validateLegacyIdentity(legacySource, legacyId);

    return _database.transaction(() async {
      await _requireMatchingCategory(categoryId, type);
      return _database
          .into(_database.transactions)
          .insertReturning(
            TransactionsCompanion.insert(
              type: type,
              categoryId: categoryId,
              amount: amount,
              title: Value(title.trim()),
              note: Value(note?.trim()),
              transactionDate: transactionDate,
              source: source,
              legacySource: Value(legacySource),
              legacyId: Value(legacyId),
            ),
          );
    });
  }

  Future<bool> update(TransactionRecord transaction) {
    _validateAmount(transaction.amount);
    _validateLegacyIdentity(transaction.legacySource, transaction.legacyId);
    if (transaction.deletedAt != null) {
      throw ArgumentError('Use softDelete to delete a transaction');
    }

    return _database.transaction(() async {
      await _requireMatchingCategory(transaction.categoryId, transaction.type);
      final updated = transaction.copyWith(updatedAt: DateTime.now().toUtc());
      final count =
          await (_database.update(_database.transactions)..where(
                (row) => row.id.equals(transaction.id) & row.deletedAt.isNull(),
              ))
              .write(updated.toCompanion(true));
      return count == 1;
    });
  }

  Future<bool> softDelete(int id) async {
    final now = DateTime.now().toUtc();
    final count =
        await (_database.update(_database.transactions)..where(
              (transaction) =>
                  transaction.id.equals(id) & transaction.deletedAt.isNull(),
            ))
            .write(
              TransactionsCompanion(
                updatedAt: Value(now),
                deletedAt: Value(now),
              ),
            );
    return count == 1;
  }

  Future<TransactionRecord?> findActiveById(int id) {
    return (_database.select(_database.transactions)..where(
          (transaction) =>
              transaction.id.equals(id) & transaction.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<void> _requireMatchingCategory(int id, TransactionType type) async {
    final category =
        await (_database.select(_database.categories)..where(
              (category) =>
                  category.id.equals(id) & category.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (category == null) {
      throw StateError('Active category not found');
    }
    if (category.type != type) {
      throw StateError('Transaction and category types must match');
    }
  }

  void _validateAmount(int amount) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive');
    }
  }

  void _validateLegacyIdentity(String? source, int? id) {
    if ((source == null) != (id == null)) {
      throw ArgumentError('Legacy source and id must be provided together');
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

final transactionsProvider = StreamProvider<List<TransactionListItem>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchAll(),
);

final transactionByIdProvider = FutureProvider.family<TransactionRecord?, int>(
  (ref, id) => ref.watch(transactionRepositoryProvider).findActiveById(id),
);

typedef TransactionListItem = ({
  TransactionRecord transaction,
  CategoryRecord category,
});
