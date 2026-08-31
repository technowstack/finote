import '../../transactions/domain/transaction_type.dart';
import '../../../core/finance/financial_summary.dart';

class ExportFilter {
  const ExportFilter({
    this.startDate,
    this.endDate,
    this.type,
    this.categoryId,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final TransactionType? type;
  final int? categoryId;
}

class ExportDocument {
  const ExportDocument({
    required this.filter,
    required this.generatedAt,
    required this.transactions,
    required this.accounts,
    required this.transfers,
  });

  final ExportFilter filter;
  final DateTime generatedAt;
  final List<ExportTransaction> transactions;
  final List<ExportAccount> accounts;
  final List<ExportTransfer> transfers;

  FinancialSummary get summary => FinancialSummary(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    transactionCount: transactions.length,
  );

  int get totalIncome => transactions
      .where((row) => row.type == TransactionType.income)
      .fold(0, (sum, row) => sum + row.amount);

  int get totalExpense => transactions
      .where((row) => row.type == TransactionType.expense)
      .fold(0, (sum, row) => sum + row.amount);

  int get balance => summary.balance;
  int get totalAssets => accounts.fold(0, (sum, row) => sum + row.balance);
  int get transferVolume => transfers.fold(0, (sum, row) => sum + row.amount);
}

class ExportTransaction {
  const ExportTransaction({
    required this.date,
    required this.type,
    required this.account,
    required this.category,
    required this.title,
    required this.note,
    required this.amount,
  });

  final DateTime date;
  final TransactionType type;
  final String account;
  final String category;
  final String title;
  final String? note;
  final int amount;
}

class ExportAccount {
  const ExportAccount({
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.incomingTransfers,
    required this.outgoingTransfers,
    required this.balance,
    required this.isActive,
  });

  final String name;
  final String type;
  final int initialBalance;
  final int totalIncome;
  final int totalExpense;
  final int incomingTransfers;
  final int outgoingTransfers;
  final int balance;
  final bool isActive;
}

class ExportTransfer {
  const ExportTransfer({
    required this.date,
    required this.fromAccount,
    required this.toAccount,
    required this.note,
    required this.amount,
  });

  final DateTime date;
  final String fromAccount;
  final String toAccount;
  final String? note;
  final int amount;
}
