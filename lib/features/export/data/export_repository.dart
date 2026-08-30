import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters.dart';
import '../domain/export_document.dart';

class ExportRepository {
  ExportRepository(this._database);

  final AppDatabase _database;

  Future<ExportDocument> buildDocument(ExportFilter filter) async {
    final transactions = _database.transactions;
    final categories = _database.categories;
    final query = _database.select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])..where(transactions.deletedAt.isNull());
    const converter = DateOnlyConverter();
    if (filter.startDate != null) {
      query.where(
        transactions.transactionDate.isBiggerOrEqualValue(
          converter.toSql(filter.startDate!),
        ),
      );
    }
    if (filter.endDate != null) {
      query.where(
        transactions.transactionDate.isSmallerOrEqualValue(
          converter.toSql(filter.endDate!),
        ),
      );
    }
    if (filter.type != null) {
      query.where(transactions.type.equals(filter.type!.name));
    }
    if (filter.categoryId != null) {
      query.where(transactions.categoryId.equals(filter.categoryId!));
    }

    final rows = await query.get();
    return ExportDocument(
      filter: filter,
      generatedAt: DateTime.now(),
      transactions: rows
          .map((row) {
            final transaction = row.readTable(transactions);
            final category = row.readTable(categories);
            return ExportTransaction(
              date: transaction.transactionDate,
              type: transaction.type,
              category: category.name,
              title: transaction.title,
              note: transaction.note,
              amount: transaction.amount,
            );
          })
          .toList(growable: false),
    );
  }
}

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(databaseProvider)),
);
