import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account_type.dart';
import '../domain/export_document.dart';

class ExportRepository {
  ExportRepository(this._database);

  final AppDatabase _database;

  Future<ExportDocument> buildDocument(ExportFilter filter) async {
    final transactions = _database.transactions;
    final categories = _database.categories;
    final accounts = _database.accounts;
    final query = _database.select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
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

    final rowsFuture = query.get();
    final summariesFuture = AccountRepository(_database).watchSummaries().first;
    final transfersFuture = _loadTransfers(filter);
    final rows = await rowsFuture;
    final summaries = await summariesFuture;
    final transferRows = await transfersFuture;
    return ExportDocument(
      filter: filter,
      generatedAt: DateTime.now(),
      transactions: rows
          .map((row) {
            final transaction = row.readTable(transactions);
            final category = row.readTable(categories);
            final account = row.readTableOrNull(accounts);
            return ExportTransaction(
              date: transaction.transactionDate,
              type: transaction.type,
              account: account?.name ?? 'Akun tidak tersedia',
              category: category.name,
              title: transaction.title,
              note: transaction.note,
              amount: transaction.amount,
            );
          })
          .toList(growable: false),
      accounts: [
        for (final summary in summaries)
          ExportAccount(
            name: summary.account.name,
            type: summary.account.type.label,
            initialBalance: summary.account.initialBalance,
            totalIncome: summary.totalIncome,
            totalExpense: summary.totalExpense,
            incomingTransfers: summary.totalIncomingTransfer,
            outgoingTransfers: summary.totalOutgoingTransfer,
            balance: summary.balance,
            isActive: summary.account.isActive,
          ),
      ],
      transfers: transferRows,
    );
  }

  Future<List<ExportTransfer>> _loadTransfers(ExportFilter filter) async {
    if (filter.type != null || filter.categoryId != null) return const [];

    const converter = DateOnlyConverter();
    final conditions = <String>['t.deleted_at IS NULL'];
    final variables = <Variable<String>>[];
    if (filter.startDate != null) {
      conditions.add('t.transfer_date >= ?');
      variables.add(Variable.withString(converter.toSql(filter.startDate!)));
    }
    if (filter.endDate != null) {
      conditions.add('t.transfer_date <= ?');
      variables.add(Variable.withString(converter.toSql(filter.endDate!)));
    }

    return [
      for (final row
          in await _database
              .customSelect(
                '''
SELECT t.transfer_date,
       t.note,
       t.amount,
       COALESCE(source.name, 'Akun tidak tersedia') AS from_account,
       COALESCE(destination.name, 'Akun tidak tersedia') AS to_account
FROM transfers t
LEFT JOIN accounts source ON source.id = t.from_account_id
LEFT JOIN accounts destination ON destination.id = t.to_account_id
WHERE ${conditions.join(' AND ')}
ORDER BY t.transfer_date ASC, t.id ASC
''',
                variables: variables,
                readsFrom: {_database.transfers, _database.accounts},
              )
              .get())
        ExportTransfer(
          date: converter.fromSql(row.read<String>('transfer_date')),
          fromAccount: row.read<String>('from_account'),
          toAccount: row.read<String>('to_account'),
          note: row.readNullable<String>('note'),
          amount: row.read<int>('amount'),
        ),
    ];
  }
}

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(databaseProvider)),
);
