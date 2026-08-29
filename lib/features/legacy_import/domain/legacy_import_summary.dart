class LegacyImportSummary {
  const LegacyImportSummary({
    required this.transactionsImported,
    required this.categoriesCreated,
    required this.totalIncome,
    required this.totalExpense,
  });

  final int transactionsImported;
  final int categoriesCreated;
  final int totalIncome;
  final int totalExpense;
}
