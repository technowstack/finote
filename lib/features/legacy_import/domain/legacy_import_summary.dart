class LegacyImportSummary {
  const LegacyImportSummary({
    required this.newCount,
    required this.duplicateCount,
    required this.failedCount,
    required this.categoriesCreated,
    required this.totalIncome,
    required this.totalExpense,
    required this.destinationAccount,
    required this.diagnostics,
  });

  final int newCount;
  final int duplicateCount;
  final int failedCount;
  final int categoriesCreated;
  final int totalIncome;
  final int totalExpense;
  final String destinationAccount;
  final LegacyImportDiagnostics diagnostics;
}

class LegacyImportDiagnostics {
  const LegacyImportDiagnostics({
    required this.totalSourceRows,
    required this.parsedRows,
    required this.eligibleRows,
    required this.importedRows,
    required this.existingRows,
    required this.skippedRows,
    required this.failedRows,
    required this.reasons,
    required this.issues,
  });

  final int totalSourceRows;
  final int parsedRows;
  final int eligibleRows;
  final int importedRows;
  final int existingRows;
  final int skippedRows;
  final int failedRows;
  final Map<String, int> reasons;
  final List<LegacyImportIssue> issues;

  bool get reconciles =>
      totalSourceRows == importedRows + existingRows + skippedRows + failedRows;
}

class LegacyImportIssue {
  const LegacyImportIssue({required this.reason, this.legacyId});

  final String reason;
  final int? legacyId;
}
