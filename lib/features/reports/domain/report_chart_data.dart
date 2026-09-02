import '../../accounts/domain/account_type.dart';

enum ChartGranularity { day, week, month }

class FinancialTrendPoint {
  const FinancialTrendPoint({
    required this.period,
    required this.income,
    required this.expense,
  });

  final DateTime period;
  final int income;
  final int expense;

  int get net => income - expense;
}

class CategoryChartPoint {
  const CategoryChartPoint({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  final int categoryId;
  final String categoryName;
  final int amount;
}

class AccountBalanceChartPoint {
  const AccountBalanceChartPoint({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.balance,
    required this.isActive,
  });

  final int accountId;
  final String accountName;
  final AccountType accountType;
  final int balance;
  final bool isActive;
}
