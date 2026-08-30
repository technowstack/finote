import 'receipt_data.dart';

class CategorySuggestion {
  const CategorySuggestion({required this.categoryId, required this.source});

  final int categoryId;
  final CategorySuggestionSource source;
}

enum CategorySuggestionSource {
  merchantMapping,
  history,
  keywordRule,
  merchantHeuristic,
}

abstract interface class ReceiptCategorySuggestionService {
  Future<CategorySuggestion?> suggestReceiptCategory({
    required String? merchant,
    required String rawText,
  });

  Future<CategorySuggestion?> suggestItemCategory(ReceiptItem item);

  Future<void> learnReceiptCategory({
    required String merchant,
    required int categoryId,
  });

  Future<void> learnItemCategory({
    required String itemName,
    required int categoryId,
  });
}
