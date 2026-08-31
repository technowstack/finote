import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
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
    final legacySource = await _sourceFor(filePath);

    return _database.transaction(() async {
      final imported =
          await (_database.select(_database.transactions)..where(
                (row) =>
                    row.legacySource.equals(legacySource) |
                    row.legacySource.equals(LegacySchema.legacySource),
              ))
              .get();
      final importedIds = imported.map((row) => row.legacyId).nonNulls.toSet();
      final newTransactions = data.transactions
          .where((transaction) => !importedIds.contains(transaction.id))
          .toList();
      final categoryIds = <(int, TransactionType), int>{};
      final defaultAccount =
          await (_database.select(_database.accounts)..where(
                (account) =>
                    account.isDefault.equals(true) &
                    account.isActive.equals(true),
              ))
              .getSingleOrNull();
      if (defaultAccount == null) {
        throw StateError('Default account is missing');
      }
      var categoriesCreated = 0;

      for (final transaction in newTransactions) {
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

      await _database.batch((batch) {
        batch.insertAll(_database.transactions, [
          for (final transaction in newTransactions)
            TransactionsCompanion.insert(
              type: transaction.type,
              accountId: Value(defaultAccount.id),
              categoryId: categoryIds[(transaction.subType, transaction.type)]!,
              amount: transaction.amount,
              title: Value(transaction.title.trim()),
              transactionDate: transaction.date.toLocal(),
              source: TransactionSource.legacyImport,
              legacySource: Value(legacySource),
              legacyId: Value(transaction.id),
            ),
        ]);
      });
      if (data.transactions.isNotEmpty) {
        onProgress?.call(data.transactions.length, data.transactions.length);
      }

      return LegacyImportSummary(
        newCount: newTransactions.length,
        duplicateCount: data.transactions.length - newTransactions.length,
        failedCount: 0,
        categoriesCreated: categoriesCreated,
        totalIncome: newTransactions
            .where((item) => item.type == TransactionType.income)
            .fold(0, (total, item) => total + item.amount),
        totalExpense: newTransactions
            .where((item) => item.type == TransactionType.expense)
            .fold(0, (total, item) => total + item.amount),
      );
    });
  }

  Future<String> _sourceFor(String filePath) async {
    final digest = await Sha256().hash(utf8.encode(p.absolute(filePath)));
    final fingerprint = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${LegacySchema.legacySource}:$fingerprint';
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
    double value when value.isFinite && value == value.truncateToDouble() =>
      value.toInt(),
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
