import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters.dart';
import '../../../core/finance/financial_summary.dart';
import '../domain/report_chart_data.dart';

class ReportRepository {
  ReportRepository(this._database);

  final AppDatabase _database;

  Stream<ReportData> watchReport(
    ReportRange range, {
    int? accountId,
    int? categoryId,
  }) {
    final transactionFilter = _transactionFilter(
      range,
      accountId: accountId,
      categoryId: categoryId,
    );
    const converter = DateOnlyConverter();
    return _database
        .customSelect(
          '''
WITH filtered AS (
  SELECT t.type, t.amount, t.category_id, t.transaction_date
  FROM transactions t
  WHERE ${transactionFilter.sql}
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
            ...transactionFilter.variables,
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

  Stream<List<FinancialTrendPoint>> watchFinancialTrend(
    ReportRange range, {
    int? accountId,
    int? categoryId,
  }) {
    final granularity = chartGranularityFor(range);
    final transactionFilter = _transactionFilter(
      range,
      accountId: accountId,
      categoryId: categoryId,
    );
    final bucket = switch (granularity) {
      ChartGranularity.day => 'transaction_date',
      ChartGranularity.week =>
        "date(transaction_date, '-' || "
            "((CAST(strftime('%w', transaction_date) AS INTEGER) + 6) % 7) "
            "|| ' days')",
      ChartGranularity.month => "substr(transaction_date, 1, 7) || '-01'",
    };
    const converter = DateOnlyConverter();
    return _database
        .customSelect(
          '''
SELECT $bucket AS period,
       COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0)
         AS income,
       COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0)
         AS expense
FROM transactions t
WHERE ${transactionFilter.sql}
GROUP BY period
ORDER BY period ASC
''',
          variables: transactionFilter.variables,
          readsFrom: {_database.transactions},
        )
        .watch()
        .map(
          (rows) => _completeTrend(range, granularity, {
            for (final row in rows)
              converter.fromSql(row.read<String>('period')): (
                income: row.read<int>('income'),
                expense: row.read<int>('expense'),
              ),
          }),
        );
  }

  Stream<List<CategoryChartPoint>> watchExpenseCategories(
    ReportRange range, {
    int? accountId,
    int? categoryId,
  }) {
    final transactionFilter = _transactionFilter(
      range,
      accountId: accountId,
      categoryId: categoryId,
    );
    return _database
        .customSelect(
          '''
SELECT t.category_id AS category_id,
       COALESCE(NULLIF(TRIM(c.name), ''), 'Kategori tidak tersedia')
         AS category_name,
       SUM(t.amount) AS amount
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
WHERE ${transactionFilter.sql}
  AND t.type = 'expense'
GROUP BY t.category_id, c.name
ORDER BY amount DESC, category_name COLLATE NOCASE ASC, t.category_id ASC
''',
          variables: transactionFilter.variables,
          readsFrom: {_database.transactions, _database.categories},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              CategoryChartPoint(
                categoryId: row.read<int>('category_id'),
                categoryName: row.read<String>('category_name'),
                amount: row.read<int>('amount'),
              ),
          ],
        );
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

ChartGranularity chartGranularityFor(ReportRange range) {
  final start = _dateOnly(range.start);
  final end = _dateOnly(range.end);
  if (start.isAfter(end)) throw ArgumentError('Invalid report range');
  final days = end.difference(start).inDays + 1;
  if (days <= 62) return ChartGranularity.day;
  if (days <= 180) return ChartGranularity.week;
  return ChartGranularity.month;
}

List<FinancialTrendPoint> _completeTrend(
  ReportRange range,
  ChartGranularity granularity,
  Map<DateTime, ({int income, int expense})> values,
) {
  if (values.isEmpty && range.isAll) return const [];
  final end = range.isAll
      ? values.keys.reduce((a, b) => a.isAfter(b) ? a : b)
      : _dateOnly(range.end);
  var period = switch (granularity) {
    ChartGranularity.day =>
      range.isAll
          ? values.keys.reduce((a, b) => a.isBefore(b) ? a : b)
          : _dateOnly(range.start),
    ChartGranularity.week =>
      range.isAll
          ? values.keys.reduce((a, b) => a.isBefore(b) ? a : b)
          : _dateOnly(range.start)
                .subtract(Duration(days: range.start.weekday - 1)),
    ChartGranularity.month =>
      range.isAll
          ? values.keys.reduce((a, b) => a.isBefore(b) ? a : b)
          : DateTime(range.start.year, range.start.month),
  };
  final points = <FinancialTrendPoint>[];
  while (!period.isAfter(end)) {
    final value = values[period];
    points.add(
      FinancialTrendPoint(
        period: period,
        income: value?.income ?? 0,
        expense: value?.expense ?? 0,
      ),
    );
    period = switch (granularity) {
      ChartGranularity.day => period.add(const Duration(days: 1)),
      ChartGranularity.week => period.add(const Duration(days: 7)),
      ChartGranularity.month => DateTime(period.year, period.month + 1),
    };
  }
  return points;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

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

  bool get isAll => start == DateTime(2000) && end == DateTime(2100, 12, 31);

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class ReportFilter {
  ReportFilter({required ReportRange range, this.accountId, this.categoryId})
    : range = _normalizedRange(range);

  final ReportRange range;
  final int? accountId;
  final int? categoryId;

  bool get hasTransactionFilter => accountId != null || categoryId != null;

  @override
  bool operator ==(Object other) =>
      other is ReportFilter &&
      other.range == range &&
      other.accountId == accountId &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(range, accountId, categoryId);
}

ReportRange _normalizedRange(ReportRange range) {
  final normalized = ReportRange(
    start: _dateOnly(range.start),
    end: _dateOnly(range.end),
  );
  if (normalized.start.isAfter(normalized.end)) {
    throw ArgumentError('Invalid report range');
  }
  return normalized;
}

({String sql, List<Variable<Object>> variables}) _transactionFilter(
  ReportRange range, {
  int? accountId,
  int? categoryId,
}) {
  const converter = DateOnlyConverter();
  final conditions = [
    't.deleted_at IS NULL',
    't.transaction_date BETWEEN ? AND ?',
    if (accountId != null) 't.account_id = ?',
    if (categoryId != null) 't.category_id = ?',
  ];
  return (
    sql: conditions.join(' AND '),
    variables: <Variable<Object>>[
      Variable.withString(converter.toSql(range.start)),
      Variable.withString(converter.toSql(range.end)),
      if (accountId != null) Variable.withInt(accountId),
      if (categoryId != null) Variable.withInt(categoryId),
    ],
  );
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(databaseProvider)),
);

final reportProvider = StreamProvider.autoDispose
    .family<ReportData, ReportFilter>(
      (ref, filter) => ref
          .watch(reportRepositoryProvider)
          .watchReport(
            filter.range,
            accountId: filter.accountId,
            categoryId: filter.categoryId,
          ),
    );
