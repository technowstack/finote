import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters.dart';
import '../../../core/finance/financial_summary.dart';

class ReportRepository {
  ReportRepository(this._database);

  final AppDatabase _database;

  Stream<ReportData> watchReport(ReportRange range) {
    const converter = DateOnlyConverter();
    return _database
        .customSelect(
          '''
WITH filtered AS (
  SELECT type, amount, category_id, transaction_date
  FROM transactions
  WHERE deleted_at IS NULL AND transaction_date BETWEEN ? AND ?
),
filtered_transfers AS (
  SELECT amount
  FROM transfers
  WHERE deleted_at IS NULL AND transfer_date BETWEEN ? AND ?
),
expense_categories AS (
  SELECT c.name AS label, SUM(f.amount) AS amount
  FROM filtered f
  JOIN categories c ON c.id = f.category_id
  WHERE f.type = 'expense'
  GROUP BY c.id, c.name
  ORDER BY amount DESC, c.name ASC
  LIMIT 5
),
income_categories AS (
  SELECT c.name AS label, SUM(f.amount) AS amount
  FROM filtered f
  JOIN categories c ON c.id = f.category_id
  WHERE f.type = 'income'
  GROUP BY c.id, c.name
  ORDER BY amount DESC, c.name ASC
  LIMIT 5
),
monthly AS (
  SELECT
    substr(transaction_date, 1, 7) AS label,
    SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) AS income,
    SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS expense
  FROM filtered
  GROUP BY substr(transaction_date, 1, 7)
)
 SELECT kind, label, income, expense, amount, transaction_count
FROM (
  SELECT
    'summary' AS kind,
    '' AS label,
    COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
    COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense,
     0 AS amount,
     COUNT(*) AS transaction_count,
     0 AS sort_group
  FROM filtered
  UNION ALL
   SELECT 'expense_category', label, 0, 0, amount, 0, 1 FROM expense_categories
  UNION ALL
   SELECT 'income_category', label, 0, 0, amount, 0, 2 FROM income_categories
  UNION ALL
   SELECT 'month', label, income, expense, 0, 0, 3 FROM monthly
  UNION ALL
   SELECT
     'transfer_summary',
     '',
     0,
     0,
     COALESCE(SUM(amount), 0),
     COUNT(*),
     4
   FROM filtered_transfers
)
ORDER BY
  sort_group,
  CASE WHEN kind = 'month' THEN label END DESC,
  amount DESC,
  label ASC
''',
          variables: [
            Variable.withString(converter.toSql(range.start)),
            Variable.withString(converter.toSql(range.end)),
            Variable.withString(converter.toSql(range.start)),
            Variable.withString(converter.toSql(range.end)),
          ],
          readsFrom: {
            _database.transactions,
            _database.categories,
            _database.transfers,
          },
        )
        .watch()
        .map(_mapRows);
  }

  ReportData _mapRows(List<QueryRow> rows) {
    var income = 0;
    var expense = 0;
    var transactionCount = 0;
    final expenseCategories = <CategoryTotal>[];
    final incomeCategories = <CategoryTotal>[];
    final monthlyHistory = <MonthlyTotal>[];
    var transferCount = 0;
    var transferVolume = 0;

    for (final row in rows) {
      switch (row.read<String>('kind')) {
        case 'summary':
          income = row.read<int>('income');
          expense = row.read<int>('expense');
          transactionCount = row.read<int>('transaction_count');
        case 'expense_category':
          expenseCategories.add(
            CategoryTotal(
              categoryName: row.read<String>('label'),
              amount: row.read<int>('amount'),
            ),
          );
        case 'income_category':
          incomeCategories.add(
            CategoryTotal(
              categoryName: row.read<String>('label'),
              amount: row.read<int>('amount'),
            ),
          );
        case 'month':
          monthlyHistory.add(
            MonthlyTotal(
              month: row.read<String>('label'),
              income: row.read<int>('income'),
              expense: row.read<int>('expense'),
            ),
          );
        case 'transfer_summary':
          transferCount = row.read<int>('transaction_count');
          transferVolume = row.read<int>('amount');
      }
    }

    return ReportData(
      totalIncome: income,
      totalExpense: expense,
      transactionCount: transactionCount,
      topExpenseCategories: expenseCategories,
      topIncomeCategories: incomeCategories,
      monthlyHistory: monthlyHistory,
      transferSummary: TransferReportSummary(
        count: transferCount,
        volume: transferVolume,
      ),
    );
  }
}

class ReportData extends FinancialSummary {
  const ReportData({
    required super.totalIncome,
    required super.totalExpense,
    required super.transactionCount,
    required this.topExpenseCategories,
    required this.topIncomeCategories,
    required this.monthlyHistory,
    required this.transferSummary,
  });

  final List<CategoryTotal> topExpenseCategories;
  final List<CategoryTotal> topIncomeCategories;
  final List<MonthlyTotal> monthlyHistory;
  final TransferReportSummary transferSummary;

  int get netBalance => balance;
  bool get isEmpty => transactionCount == 0;
}

class TransferReportSummary {
  const TransferReportSummary({required this.count, required this.volume});

  final int count;
  final int volume;
}

class CategoryTotal {
  const CategoryTotal({required this.categoryName, required this.amount});

  final String categoryName;
  final int amount;
}

class MonthlyTotal {
  const MonthlyTotal({
    required this.month,
    required this.income,
    required this.expense,
  });

  final String month;
  final int income;
  final int expense;

  int get netBalance => income - expense;
}

class ReportRange {
  const ReportRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(databaseProvider)),
);

final reportProvider = StreamProvider.autoDispose
    .family<ReportData, ReportRange>(
      (ref, range) => ref.watch(reportRepositoryProvider).watchReport(range),
    );
