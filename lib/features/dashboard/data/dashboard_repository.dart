import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters.dart';
import '../../../core/utils/financial_date_range.dart';
import '../../transactions/data/transaction_repository.dart';

class DashboardRepository {
  DashboardRepository(this._database);

  final AppDatabase _database;

  Stream<DashboardSummary> watchSummary(DateTime referenceDate) {
    const converter = DateOnlyConverter();
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final month = resolveFinancialDateRange(FinancialPeriod.month, now: today);
    final monthStart = month.start;
    final monthEnd = month.end;

    return _database
        .customSelect(
          '''
SELECT
  (SELECT COALESCE(SUM(initial_balance), 0) FROM accounts) +
    (SELECT COALESCE(SUM(CASE
       WHEN type = 'income' THEN amount
       WHEN type = 'expense' THEN -amount
       ELSE 0
     END), 0)
     FROM transactions
     WHERE deleted_at IS NULL AND account_id IS NOT NULL) AS total_assets,
  COALESCE(SUM(CASE WHEN type = 'income' AND transaction_date BETWEEN ? AND ? THEN amount ELSE 0 END), 0) AS monthly_income,
  COALESCE(SUM(CASE WHEN type = 'expense' AND transaction_date BETWEEN ? AND ? THEN amount ELSE 0 END), 0) AS monthly_expense,
  COALESCE(SUM(CASE WHEN transaction_date = ? THEN 1 ELSE 0 END), 0) AS today_count
FROM transactions
WHERE deleted_at IS NULL
''',
          variables: [
            Variable.withString(converter.toSql(monthStart)),
            Variable.withString(converter.toSql(monthEnd)),
            Variable.withString(converter.toSql(monthStart)),
            Variable.withString(converter.toSql(monthEnd)),
            Variable.withString(converter.toSql(today)),
          ],
          readsFrom: {_database.accounts, _database.transactions},
        )
        .watchSingle()
        .map(
          (row) => DashboardSummary(
            totalAssets: row.read<int>('total_assets'),
            monthlyIncome: row.read<int>('monthly_income'),
            monthlyExpense: row.read<int>('monthly_expense'),
            todayTransactionCount: row.read<int>('today_count'),
          ),
        );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalAssets,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.todayTransactionCount,
  });

  final int totalAssets;
  final int monthlyIncome;
  final int monthlyExpense;
  final int todayTransactionCount;
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(databaseProvider)),
);

final dashboardSummaryProvider = StreamProvider<DashboardSummary>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchSummary(DateTime.now()),
);

final dashboardRecentTransactionsProvider =
    StreamProvider<List<TransactionListItem>>(
      (ref) => ref
          .watch(transactionRepositoryProvider)
          .watchHistory(const TransactionHistoryQuery(limit: 5)),
    );
