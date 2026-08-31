import 'dart:convert';
import 'dart:io';

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
    final previousPathSource = await _pathSourceFor(filePath);

    return _database.transaction(() async {
      await _database.ensureDefaultAccount();
      for (final previousSource in {
        LegacySchema.legacySource,
        previousPathSource,
      }) {
        if (previousSource == legacySource) continue;
        await (_database.update(_database.transactions)
              ..where((row) => row.legacySource.equals(previousSource)))
            .write(TransactionsCompanion(legacySource: Value(legacySource)));
      }
      final imported = await (_database.select(
        _database.transactions,
      )..where((row) => row.legacySource.equals(legacySource))).get();
      final importedIds = imported.map((row) => row.legacyId).nonNulls.toSet();
      final newTransactions = data.transactions
          .where((transaction) => !importedIds.contains(transaction.id))
          .toList();
      final categoryIds = <(int, TransactionType), int>{};
      final existingCategories = {
        for (final category in await (_database.select(
          _database.categories,
        )..where((row) => row.deletedAt.isNull())).get())
          (category.name, category.type): category.id,
      };
      final defaultAccount = await (_database.select(
        _database.accounts,
      )..where((account) => account.isDefault.equals(true))).getSingleOrNull();
      if (defaultAccount == null || !defaultAccount.isActive) {
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

        final categoryKey = (name.trim(), transaction.type);
        final existingId = existingCategories[categoryKey];
        if (existingId != null) {
          categoryIds[key] = existingId;
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
        existingCategories[categoryKey] = category.id;
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
        destinationAccount: defaultAccount.name,
      );
    });
  }

  Future<String> _sourceFor(String filePath) async {
    final digest = await Sha256().hash(await File(filePath).readAsBytes());
    return '${LegacySchema.legacySource}:${_hex(digest.bytes)}';
  }

  Future<String> _pathSourceFor(String filePath) async {
    final digest = await Sha256().hash(utf8.encode(p.absolute(filePath)));
    return '${LegacySchema.legacySource}:${_hex(digest.bytes)}';
  }

  String _hex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  _LegacyData _readLegacy(String filePath) {
    final db = sqlite.sqlite3.open(filePath, mode: sqlite.OpenMode.readOnly);
    try {
      final categoryNames = <int, String>{
        for (final row in db.select(
          'SELECT ${LegacySchema.colCategoryId}, '
          '${LegacySchema.colCategoryName} FROM TransactionSubType',
        ))
          LegacySchema.readWholeInt(
            row[LegacySchema.colCategoryId],
            'category id',
          ): row[LegacySchema.colCategoryName] as String,
      };

      final transactions = db
          .select(
            'SELECT ${LegacySchema.colId}, ${LegacySchema.colType}, '
            '${LegacySchema.colAmount}, ${LegacySchema.colSubType}, '
            '${LegacySchema.colDate}, title FROM "Transaction" '
            'ORDER BY ${LegacySchema.colId}',
          )
          .map((row) {
            final type = switch (LegacySchema.readWholeInt(
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
            final amount = LegacySchema.readWholeInt(
              row[LegacySchema.colAmount],
              'transaction amount',
            );
            if (amount <= 0) {
              throw const FormatException('Nominal transaksi harus positif.');
            }
            return _LegacyTransaction(
              id: LegacySchema.readWholeInt(
                row[LegacySchema.colId],
                'transaction id',
              ),
              type: type,
              amount: amount,
              subType: LegacySchema.readWholeInt(
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
