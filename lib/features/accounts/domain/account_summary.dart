import '../../../core/database/app_database.dart';

class AccountSummary {
  const AccountSummary({
    required this.account,
    required this.totalIncome,
    required this.totalExpense,
  });

  final AccountRecord account;
  final int totalIncome;
  final int totalExpense;

  int get balance => account.initialBalance + totalIncome - totalExpense;
}
