import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../../core/database/app_database.dart';
import '../../transactions/domain/transaction_source.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/legacy_import_summary.dart';
import '../domain/legacy_schema.dart';
import 'legacy_detector.dart';

class LegacyImporter {
  const LegacyImporter(this._database);

  final AppDatabase _database;

  Future<LegacyImportSummary> import(
    String filePath, {
    void Function(int completed, int total)? onProgress,
  }) async {
    await const LegacyDetector().detect(filePath);
    final data = _readLegacy(filePath);

    return _database.transaction(() async {
      final categoryIds = <(int, TransactionType), int>{};
      var categoriesCreated = 0;

      for (final transaction in data.transactions) {
        final key = (transaction.subType, transaction.type);
        if (categoryIds.containsKey(key)) continue;

        final name = data.categoryNames[transaction.subType];
        if (name == null || name.trim().isEmpty) {
          throw FormatException(
            'Kategori legacy ${transaction.subType} tidak ditemukan.',
          );
        }

        final existing =
            await (_database.select(_database.categories)..where(
                  (row) =>
                      row.name.equals(name.trim()) &
                      row.type.equals(transaction.type.name) &
                      row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (existing != null) {
          categoryIds[key] = existing.id;
          continue;
        }

        final category = await _database
            .into(_database.categories)
            .insertReturning(
              CategoriesCompanion.insert(
                name: name.trim(),
                type: transaction.type,
              ),
            );
        categoryIds[key] = category.id;
        categoriesCreated++;
      }

      for (var index = 0; index < data.transactions.length; index++) {
        final transaction = data.transactions[index];
        await _database
            .into(_database.transactions)
            .insert(
              TransactionsCompanion.insert(
                type: transaction.type,
                categoryId:
                    categoryIds[(transaction.subType, transaction.type)]!,
                amount: transaction.amount,
                title: Value(transaction.title.trim()),
                transactionDate: transaction.date.toLocal(),
                source: TransactionSource.legacyImport,
                legacySource: const Value(LegacySchema.legacySource),
                legacyId: Value(transaction.id),
              ),
            );

        final completed = index + 1;
        if (completed == data.transactions.length || completed % 100 == 0) {
          onProgress?.call(completed, data.transactions.length);
          await Future<void>.delayed(Duration.zero);
        }
      }

      return LegacyImportSummary(
        transactionsImported: data.transactions.length,
        categoriesCreated: categoriesCreated,
        totalIncome: data.transactions
            .where((item) => item.type == TransactionType.income)
            .fold(0, (total, item) => total + item.amount),
        totalExpense: data.transactions
            .where((item) => item.type == TransactionType.expense)
            .fold(0, (total, item) => total + item.amount),
      );
    });
  }

  _LegacyData _readLegacy(String filePath) {
    final db = sqlite.sqlite3.open(filePath, mode: sqlite.OpenMode.readOnly);
    try {
      final categoryNames = <int, String>{
        for (final row in db.select(
          'SELECT ${LegacySchema.colCategoryId}, '
          '${LegacySchema.colCategoryName} FROM TransactionSubType',
        ))
          _readInt(row[LegacySchema.colCategoryId], 'category id'):
              row[LegacySchema.colCategoryName] as String,
      };

      final transactions = db
          .select(
            'SELECT ${LegacySchema.colId}, ${LegacySchema.colType}, '
            '${LegacySchema.colAmount}, ${LegacySchema.colSubType}, '
            '${LegacySchema.colDate}, title FROM "Transaction" '
            'ORDER BY ${LegacySchema.colId}',
          )
          .map((row) {
            final type = switch (_readInt(
              row[LegacySchema.colType],
              'transaction type',
            )) {
              0 => TransactionType.expense,
              1 => TransactionType.income,
              final value => throw FormatException(
                'Tipe transaksi legacy tidak dikenal: $value',
              ),
            };
            final date = LegacySchema.readDate(row[LegacySchema.colDate]);
            if (date == null) {
              throw const FormatException(
                'Tanggal transaksi legacy tidak valid.',
              );
            }
            final amount = _readInt(
              row[LegacySchema.colAmount],
              'transaction amount',
            );
            if (amount <= 0) {
              throw const FormatException('Nominal transaksi harus positif.');
            }
            return _LegacyTransaction(
              id: _readInt(row[LegacySchema.colId], 'transaction id'),
              type: type,
              amount: amount,
              subType: _readInt(
                row[LegacySchema.colSubType],
                'transaction subtype',
              ),
              date: date,
              title: row['title'] as String? ?? '',
            );
          })
          .toList();
      return _LegacyData(categoryNames, transactions);
    } finally {
      db.close();
    }
  }

  int _readInt(Object? value, String field) => switch (value) {
    int value => value,
    double value => value.toInt(),
    String value when int.tryParse(value) != null => int.parse(value),
    _ => throw FormatException('Nilai $field tidak valid.'),
  };
}

class _LegacyData {
  const _LegacyData(this.categoryNames, this.transactions);

  final Map<int, String> categoryNames;
  final List<_LegacyTransaction> transactions;
}

class _LegacyTransaction {
  const _LegacyTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.subType,
    required this.date,
    required this.title,
  });

  final int id;
  final TransactionType type;
  final int amount;
  final int subType;
  final DateTime date;
  final String title;
}
