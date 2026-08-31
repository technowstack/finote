import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters.dart';
import '../domain/financial_activity.dart';

class FinancialActivityRepository {
  FinancialActivityRepository(this._database);

  final AppDatabase _database;

  Stream<List<FinancialActivity>> watch(FinancialActivityQuery filter) {
    final variables = <Variable>[];
    final transactionWhere = <String>['t.deleted_at IS NULL'];
    final transferWhere = <String>['tr.deleted_at IS NULL'];
    final includeTransactions = filter.type != FinancialActivityType.transfer;
    final includeTransfers =
        filter.type == null || filter.type == FinancialActivityType.transfer;

    if (includeTransactions &&
        (filter.type == FinancialActivityType.income ||
            filter.type == FinancialActivityType.expense)) {
      transactionWhere.add('t.type = ?');
      variables.add(Variable.withString(filter.type!.name));
    }

    const dateConverter = DateOnlyConverter();
    if (includeTransactions && filter.startDate != null) {
      transactionWhere.add('t.transaction_date >= ?');
      variables.add(
        Variable.withString(dateConverter.toSql(filter.startDate!)),
      );
    }
    if (includeTransactions && filter.endDate != null) {
      transactionWhere.add('t.transaction_date <= ?');
      variables.add(Variable.withString(dateConverter.toSql(filter.endDate!)));
    }

    final search = filter.search.trim();
    if (includeTransactions && search.isNotEmpty) {
      transactionWhere.add(
        '(t.title LIKE ? ESCAPE \'\\\' OR t.note LIKE ? ESCAPE \'\\\' '
        'OR c.name LIKE ? ESCAPE \'\\\' OR a.name LIKE ? ESCAPE \'\\\')',
      );
      final pattern = _escapedLikePattern(search);
      for (var i = 0; i < 4; i++) {
        variables.add(Variable.withString(pattern));
      }
    }

    final transactionSql = !includeTransactions
        ? null
        : '''
          SELECT t.type AS activity_type,
                 t.id AS entity_id,
                 t.uuid AS uuid,
                 t.transaction_date AS activity_date,
                 t.created_at AS created_at,
                 0 AS sort_kind,
                 t.amount AS amount,
                 CASE WHEN t.title = '' THEN COALESCE(c.name, 'Transaksi') ELSE t.title END AS title,
                 COALESCE(a.name, 'Akun tidak tersedia') AS subtitle,
                 CASE WHEN t.title = '' THEN NULL ELSE c.name END AS category_name
          FROM transactions t
          LEFT JOIN categories c ON c.id = t.category_id
          LEFT JOIN accounts a ON a.id = t.account_id
          WHERE ${transactionWhere.join(' AND ')}
        ''';

    if (includeTransfers && filter.startDate != null) {
      transferWhere.add('tr.transfer_date >= ?');
      variables.add(
        Variable.withString(dateConverter.toSql(filter.startDate!)),
      );
    }
    if (includeTransfers && filter.endDate != null) {
      transferWhere.add('tr.transfer_date <= ?');
      variables.add(Variable.withString(dateConverter.toSql(filter.endDate!)));
    }
    if (includeTransfers && search.isNotEmpty) {
      transferWhere.add(
        '(tr.note LIKE ? ESCAPE \'\\\' OR source.name LIKE ? ESCAPE \'\\\' '
        'OR destination.name LIKE ? ESCAPE \'\\\')',
      );
      final pattern = _escapedLikePattern(search);
      for (var i = 0; i < 3; i++) {
        variables.add(Variable.withString(pattern));
      }
    }

    final transferSql = !includeTransfers
        ? null
        : '''
          SELECT 'transfer' AS activity_type,
                 tr.id AS entity_id,
                 tr.uuid AS uuid,
                 tr.transfer_date AS activity_date,
                 tr.created_at AS created_at,
                 1 AS sort_kind,
                 tr.amount AS amount,
                 'Transfer ke ' || COALESCE(destination.name, 'Akun tidak tersedia') AS title,
                 COALESCE(source.name, 'Akun tidak tersedia') || ' → ' ||
                   COALESCE(destination.name, 'Akun tidak tersedia') AS subtitle,
                 NULL AS category_name
          FROM transfers tr
          LEFT JOIN accounts source ON source.id = tr.from_account_id
          LEFT JOIN accounts destination ON destination.id = tr.to_account_id
          WHERE ${transferWhere.join(' AND ')}
        ''';

    final parts = [transactionSql, transferSql].nonNulls.toList();
    final limitSql = filter.limit == null ? '' : ' LIMIT ${filter.limit}';
    return _database
        .customSelect(
          '''
          ${parts.join(' UNION ALL ')}
          ORDER BY activity_date DESC, created_at DESC, sort_kind DESC, entity_id DESC
          $limitSql
          ''',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.transfers,
            _database.categories,
            _database.accounts,
          },
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              FinancialActivity(
                type: switch (row.read<String>('activity_type')) {
                  'income' => FinancialActivityType.income,
                  'expense' => FinancialActivityType.expense,
                  'transfer' => FinancialActivityType.transfer,
                  _ => throw const FormatException('Unknown activity type'),
                },
                entityId: row.read<int>('entity_id'),
                uuid: row.read<String>('uuid'),
                date: dateConverter.fromSql(row.read<String>('activity_date')),
                amount: row.read<int>('amount'),
                title: row.read<String>('title'),
                subtitle: row.read<String>('subtitle'),
                categoryName: row.readNullable<String>('category_name'),
              ),
          ],
        );
  }
}

class FinancialActivityQuery {
  const FinancialActivityQuery({
    this.type,
    this.startDate,
    this.endDate,
    this.search = '',
    this.limit,
  }) : assert(limit == null || limit > 0);

  final FinancialActivityType? type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String search;
  final int? limit;

  @override
  bool operator ==(Object other) =>
      other is FinancialActivityQuery &&
      other.type == type &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.search == search &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(type, startDate, endDate, search, limit);
}

final financialActivityRepositoryProvider =
    Provider<FinancialActivityRepository>(
      (ref) => FinancialActivityRepository(ref.watch(databaseProvider)),
    );

final financialActivityProvider = StreamProvider.autoDispose
    .family<List<FinancialActivity>, FinancialActivityQuery>(
      (ref, filter) =>
          ref.watch(financialActivityRepositoryProvider).watch(filter),
    );

String _escapedLikePattern(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
  return '%$escaped%';
}
