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

        final name = data.categoryNames[transaction.subType]?.trim();
        final categoryName = name == null || name.isEmpty
            ? 'Tanpa Kategori'
            : name;
        if (name == null || name.isEmpty) {
          data.reasonCounts.update(
            'missing_category_fallback',
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }

        final categoryKey = (categoryName, transaction.type);
        final existingId = existingCategories[categoryKey];
        if (existingId != null) {
          categoryIds[key] = existingId;
          continue;
        }

        final category = await _database
            .into(_database.categories)
            .insertReturning(
              CategoriesCompanion.insert(
                name: categoryName,
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
        diagnostics: LegacyImportDiagnostics(
          totalSourceRows: data.sourceRowCount,
          parsedRows: data.transactions.length,
          eligibleRows: data.transactions.length,
          importedRows: newTransactions.length,
          existingRows: data.transactions.length - newTransactions.length,
          skippedRows: data.issues.length,
          failedRows: 0,
          reasons: data.reasonCounts,
          issues: data.issues,
        ),
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
      final categoryNames = <int, String>{};
      for (final row in db.select(
        'SELECT ${LegacySchema.colCategoryId}, '
        '${LegacySchema.colCategoryName} FROM TransactionSubType',
      )) {
        try {
          final id = LegacySchema.readWholeInt(
            row[LegacySchema.colCategoryId],
            'category id',
          );
          final name = row[LegacySchema.colCategoryName];
          if (name is String && name.trim().isNotEmpty) {
            categoryNames[id] = name;
          }
        } on FormatException {
          // Invalid category metadata is handled by the row fallback.
        }
      }

      final rows = db.select(
        'SELECT ${LegacySchema.colId}, ${LegacySchema.colType}, '
        '${LegacySchema.colAmount}, ${LegacySchema.colSubType}, '
        '${LegacySchema.colDate}, title FROM "Transaction" '
        'ORDER BY ${LegacySchema.colId}',
      );
      final transactions = <_LegacyTransaction>[];
      final issues = <LegacyImportIssue>[];
      final reasonCounts = <String, int>{};
      for (final row in rows) {
        int? legacyId;
        String? reason;
        try {
          legacyId = LegacySchema.readWholeInt(
            row[LegacySchema.colId],
            'transaction id',
          );
          final typeValue = LegacySchema.readWholeInt(
            row[LegacySchema.colType],
            'transaction type',
          );
          final type = switch (typeValue) {
            0 => TransactionType.expense,
            1 => TransactionType.income,
            _ => throw const FormatException('unknown_type'),
          };
          final date = _readDate(row[LegacySchema.colDate]);
          if (date == null || date.year < 1970 || date.year > 2100) {
            throw const FormatException('invalid_date');
          }
          final amount = LegacySchema.readWholeInt(
            row[LegacySchema.colAmount],
            'transaction amount',
          );
          if (amount <= 0) throw const FormatException('invalid_amount');
          final subType = LegacySchema.readWholeInt(
            row[LegacySchema.colSubType],
            'transaction subtype',
          );
          transactions.add(
            _LegacyTransaction(
              id: legacyId,
              type: type,
              amount: amount,
              subType: subType,
              date: date,
              title: row['title'] as String? ?? '',
            ),
          );
        } on FormatException catch (error) {
          reason = _reasonCode(error.message.toString());
        } on Object {
          reason = 'unsupported_row';
        }
        if (reason != null) {
          issues.add(LegacyImportIssue(reason: reason, legacyId: legacyId));
          reasonCounts.update(reason, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      return _LegacyData(
        categoryNames,
        transactions,
        sourceRowCount: rows.length,
        issues: issues,
        reasonCounts: reasonCounts,
      );
    } finally {
      db.close();
    }
  }

  String _reasonCode(String message) {
    if (message.startsWith('Nilai transaction id')) {
      return 'invalid_primary_key';
    }
    if (message.startsWith('Nilai transaction type')) {
      return 'unknown_type';
    }
    if (message.startsWith('Nilai transaction amount') ||
        message == 'invalid_amount') {
      return 'invalid_amount';
    }
    if (message.startsWith('Nilai transaction subtype')) {
      return 'invalid_category';
    }
    return message;
  }

  DateTime? _readDate(Object? value) {
    try {
      return LegacySchema.readDate(value);
    } on Object {
      return null;
    }
  }
}

class _LegacyData {
  const _LegacyData(
    this.categoryNames,
    this.transactions, {
    required this.sourceRowCount,
    required this.issues,
    required this.reasonCounts,
  });

  final Map<int, String> categoryNames;
  final List<_LegacyTransaction> transactions;
  final int sourceRowCount;
  final List<LegacyImportIssue> issues;
  final Map<String, int> reasonCounts;
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
