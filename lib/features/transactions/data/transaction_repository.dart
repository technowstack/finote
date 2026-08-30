import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters.dart';
import '../domain/transaction_source.dart';
import '../domain/transaction_type.dart';

class TransactionRepository {
  TransactionRepository(this._database);

  final AppDatabase _database;

  Stream<List<TransactionListItem>> watchAll() {
    return watchHistory(const TransactionHistoryQuery());
  }

  Stream<List<TransactionListItem>> watchHistory(
    TransactionHistoryQuery filter,
  ) {
    final transactions = _database.transactions;
    final categories = _database.categories;
    final query =
        _database.select(transactions).join([
            innerJoin(
              categories,
              categories.id.equalsExp(transactions.categoryId),
            ),
          ])
          ..where(transactions.deletedAt.isNull())
          ..orderBy([
            OrderingTerm.desc(transactions.transactionDate),
            OrderingTerm.desc(transactions.createdAt),
          ]);

    final type = filter.type;
    if (type != null) query.where(transactions.type.equals(type.name));

    const dateConverter = DateOnlyConverter();
    final startDate = filter.startDate;
    if (startDate != null) {
      query.where(
        transactions.transactionDate.isBiggerOrEqualValue(
          dateConverter.toSql(startDate),
        ),
      );
    }
    final endDate = filter.endDate;
    if (endDate != null) {
      query.where(
        transactions.transactionDate.isSmallerOrEqualValue(
          dateConverter.toSql(endDate),
        ),
      );
    }

    final search = filter.search.trim();
    if (search.isNotEmpty) {
      final pattern = _escapedLikePattern(search);
      query.where(
        transactions.title.like(pattern, escapeChar: r'\') |
            transactions.note.like(pattern, escapeChar: r'\') |
            categories.name.like(pattern, escapeChar: r'\'),
      );
    }
    final limit = filter.limit;
    if (limit != null) query.limit(limit);

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

  Future<List<TransactionRecord>> createMany({
    required TransactionType type,
    required int categoryId,
    required List<({int amount, String title, DateTime transactionDate})>
    entries,
    TransactionSource source = TransactionSource.manual,
  }) {
    if (entries.isEmpty) throw ArgumentError('At least one entry is required');
    for (final entry in entries) {
      _validateAmount(entry.amount);
    }

    return _database.transaction(() async {
      await _requireMatchingCategory(categoryId, type);
      final result = <TransactionRecord>[];
      for (final entry in entries) {
        result.add(
          await _database
              .into(_database.transactions)
              .insertReturning(
                TransactionsCompanion.insert(
                  type: type,
                  categoryId: categoryId,
                  amount: entry.amount,
                  title: Value(entry.title.trim()),
                  transactionDate: entry.transactionDate,
                  source: source,
                ),
              ),
        );
      }
      return result;
    });
  }

  Future<List<TransactionRecord>> createManyWithCategories({
    required TransactionType type,
    required List<
      ({int amount, String title, DateTime transactionDate, int categoryId})
    >
    entries,
    TransactionSource source = TransactionSource.manual,
  }) async {
    if (entries.isEmpty) throw ArgumentError('At least one entry is required');
    for (final entry in entries) {
      _validateAmount(entry.amount);
    }

    return _database.transaction(() async {
      final result = <TransactionRecord>[];
      for (final entry in entries) {
        await _requireMatchingCategory(entry.categoryId, type);
        result.add(
          await _database
              .into(_database.transactions)
              .insertReturning(
                TransactionsCompanion.insert(
                  type: type,
                  categoryId: entry.categoryId,
                  amount: entry.amount,
                  title: Value(entry.title.trim()),
                  transactionDate: entry.transactionDate,
                  source: source,
                ),
              ),
        );
      }
      return result;
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

final transactionHistoryProvider = StreamProvider.autoDispose
    .family<List<TransactionListItem>, TransactionHistoryQuery>(
      (ref, filter) =>
          ref.watch(transactionRepositoryProvider).watchHistory(filter),
    );

final transactionByIdProvider = FutureProvider.family<TransactionRecord?, int>(
  (ref, id) => ref.watch(transactionRepositoryProvider).findActiveById(id),
);

typedef TransactionListItem = ({
  TransactionRecord transaction,
  CategoryRecord category,
});

class TransactionHistoryQuery {
  const TransactionHistoryQuery({
    this.type,
    this.startDate,
    this.endDate,
    this.search = '',
    this.limit,
  }) : assert(limit == null || limit > 0);

  final TransactionType? type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String search;
  final int? limit;

  @override
  bool operator ==(Object other) =>
      other is TransactionHistoryQuery &&
      other.type == type &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.search == search &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(type, startDate, endDate, search, limit);
}

String _escapedLikePattern(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
  return '%$escaped%';
}
