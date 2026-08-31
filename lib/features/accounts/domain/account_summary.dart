import '../../../core/database/app_database.dart';

class AccountSummary {
  const AccountSummary({
    required this.account,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalIncomingTransfer,
    required this.totalOutgoingTransfer,
  });

  final AccountRecord account;
  final int totalIncome;
  final int totalExpense;
  final int totalIncomingTransfer;
  final int totalOutgoingTransfer;

  int get balance =>
      account.initialBalance +
      totalIncome -
      totalExpense +
      totalIncomingTransfer -
      totalOutgoingTransfer;
}
