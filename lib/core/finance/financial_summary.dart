class FinancialSummary {
  const FinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
  });

  final int totalIncome;
  final int totalExpense;
  final int transactionCount;

  int get balance => totalIncome - totalExpense;
}
