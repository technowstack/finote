class LegacyImportSummary {
  const LegacyImportSummary({
    required this.newCount,
    required this.duplicateCount,
    required this.failedCount,
    required this.categoriesCreated,
    required this.totalIncome,
    required this.totalExpense,
    required this.destinationAccount,
  });

  final int newCount;
  final int duplicateCount;
  final int failedCount;
  final int categoriesCreated;
  final int totalIncome;
  final int totalExpense;
  final String destinationAccount;
}
