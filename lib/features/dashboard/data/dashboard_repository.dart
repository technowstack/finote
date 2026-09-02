import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters.dart';
import '../../../core/utils/financial_date_range.dart';
import '../../accounts/data/account_repository.dart';
import '../../transactions/data/transaction_repository.dart';

class DashboardRepository {
  DashboardRepository(this._database)
    : _accounts = AccountRepository(_database);

  final AppDatabase _database;
  final AccountRepository _accounts;

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

    final monthly = _database
        .customSelect(
          '''
SELECT
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
          readsFrom: {_database.transactions},
        )
        .watchSingle()
        .map(
          (row) => (
            monthlyIncome: row.read<int>('monthly_income'),
            monthlyExpense: row.read<int>('monthly_expense'),
            todayTransactionCount: row.read<int>('today_count'),
          ),
        );

    return _accounts.watchSummaries().asyncMap((accounts) async {
      final summary = await monthly.first;
      return DashboardSummary(
        totalAssets: accounts.fold(
          0,
          (total, account) => total + account.balance,
        ),
        monthlyIncome: summary.monthlyIncome,
        monthlyExpense: summary.monthlyExpense,
        todayTransactionCount: summary.todayTransactionCount,
      );
    });
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
