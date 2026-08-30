import '../../transactions/domain/transaction_type.dart';

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
  });

  final ExportFilter filter;
  final DateTime generatedAt;
  final List<ExportTransaction> transactions;

  int get totalIncome => transactions
      .where((row) => row.type == TransactionType.income)
      .fold(0, (sum, row) => sum + row.amount);

  int get totalExpense => transactions
      .where((row) => row.type == TransactionType.expense)
      .fold(0, (sum, row) => sum + row.amount);

  int get balance => totalIncome - totalExpense;
}

class ExportTransaction {
  const ExportTransaction({
    required this.date,
    required this.type,
    required this.category,
    required this.title,
    required this.note,
    required this.amount,
  });

  final DateTime date;
  final TransactionType type;
  final String category;
  final String title;
  final String? note;
  final int amount;
}
