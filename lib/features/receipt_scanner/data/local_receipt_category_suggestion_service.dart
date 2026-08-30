import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/receipt_category_suggestion.dart';
import '../domain/receipt_data.dart';

class LocalReceiptCategorySuggestionService
    implements ReceiptCategorySuggestionService {
  LocalReceiptCategorySuggestionService(this._database);

  final AppDatabase _database;
  Future<List<({String title, int categoryId})>>? _history;

  static const _merchantMappingKey = 'receipt_category_merchant_mappings';
  static const _itemMappingKey = 'receipt_category_item_mappings';

  @override
  Future<CategorySuggestion?> suggestReceiptCategory({
    required String? merchant,
    required String rawText,
  }) async {
    final categories = await _expenseCategories();
    final merchantKey = normalizeReceiptText(merchant ?? '');
    final text = normalizeReceiptText('$merchant $rawText');
    final mappings = await _readMappings(_merchantMappingKey);
    final mapped = _mappedCategory(categories, mappings, merchantKey);
    if (mapped != null) {
      return CategorySuggestion(
        categoryId: mapped.id,
        source: CategorySuggestionSource.merchantMapping,
      );
    }

    final historical = await _historyCategory(categories, merchantKey);
    if (historical != null) {
      return CategorySuggestion(
        categoryId: historical,
        source: CategorySuggestionSource.history,
      );
    }

    final keyword = _matchKeyword(categories, text);
    if (keyword != null) {
      return CategorySuggestion(
        categoryId: keyword,
        source: CategorySuggestionSource.keywordRule,
      );
    }

    final heuristic = _matchMerchant(categories, merchantKey);
    return heuristic == null
        ? null
        : CategorySuggestion(
            categoryId: heuristic,
            source: CategorySuggestionSource.merchantHeuristic,
          );
  }

  @override
  Future<CategorySuggestion?> suggestItemCategory(ReceiptItem item) async {
    final categories = await _expenseCategories();
    final text = normalizeReceiptText(item.name);
    final mappings = await _readMappings(_itemMappingKey);
    final mapped = _mappedCategory(categories, mappings, text);
    if (mapped != null) {
      return CategorySuggestion(
        categoryId: mapped.id,
        source: CategorySuggestionSource.merchantMapping,
      );
    }
    final historical = await _historyCategory(categories, text);
    if (historical != null) {
      return CategorySuggestion(
        categoryId: historical,
        source: CategorySuggestionSource.history,
      );
    }
    final keyword = _matchKeyword(categories, text);
    return keyword == null
        ? null
        : CategorySuggestion(
            categoryId: keyword,
            source: CategorySuggestionSource.keywordRule,
          );
  }

  @override
  Future<void> learnReceiptCategory({
    required String merchant,
    required int categoryId,
  }) => _writeMapping(_merchantMappingKey, merchant, categoryId);

  @override
  Future<void> learnItemCategory({
    required String itemName,
    required int categoryId,
  }) => _writeMapping(_itemMappingKey, itemName, categoryId);

  Future<List<CategoryRecord>> _expenseCategories() {
    return (_database.select(_database.categories)..where(
          (category) =>
              category.type.equals(TransactionType.expense.name) &
              category.deletedAt.isNull(),
        ))
        .get();
  }

  Future<List<({String title, int categoryId})>> _historyRows() {
    return _history ??= (() async {
      final rows =
          await (_database.select(_database.transactions)..where(
                (transaction) =>
                    transaction.type.equals(TransactionType.expense.name) &
                    transaction.deletedAt.isNull(),
              ))
              .get();
      return [
        for (final row in rows) (title: row.title, categoryId: row.categoryId),
      ];
    })();
  }

  Future<int?> _historyCategory(
    List<CategoryRecord> categories,
    String merchant,
  ) async {
    if (merchant.isEmpty) return null;
    final activeIds = categories.map((category) => category.id).toSet();
    final counts = <int, int>{};
    for (final row in await _historyRows()) {
      if (activeIds.contains(row.categoryId) &&
          normalizeReceiptText(row.title).contains(merchant)) {
        counts.update(row.categoryId, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Future<Map<String, int>> _readMappings(String key) async {
    final row = await (_database.select(
      _database.settings,
    )..where((setting) => setting.key.equals(key))).getSingleOrNull();
    if (row == null) return {};
    final decoded = jsonDecode(row.value);
    return {
      for (final entry in (decoded as Map<String, dynamic>).entries)
        entry.key: entry.value as int,
    };
  }

  Future<void> _writeMapping(String key, String value, int categoryId) async {
    final normalized = normalizeReceiptText(value);
    if (normalized.isEmpty || await _categoryById(categoryId) == null) return;
    final mappings = await _readMappings(key);
    mappings[normalized] = categoryId;
    await _database
        .into(_database.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: jsonEncode(mappings)),
        );
  }

  Future<CategoryRecord?> _categoryById(int id) {
    return (_database.select(_database.categories)..where(
          (category) => category.id.equals(id) & category.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  CategoryRecord? _category(List<CategoryRecord> categories, int? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  CategoryRecord? _mappedCategory(
    List<CategoryRecord> categories,
    Map<String, int> mappings,
    String text,
  ) {
    for (final entry in mappings.entries) {
      if (text == entry.key || text.startsWith('${entry.key} ')) {
        final category = _category(categories, entry.value);
        if (category != null) return category;
      }
    }
    return null;
  }

  int? _matchKeyword(List<CategoryRecord> categories, String text) {
    const rules = {
      'Makanan & Minuman': [
        'makan',
        'ayam',
        'nasi',
        'roti',
        'susu',
        'kopi',
        'resto',
        'restaurant',
        'cafe',
      ],
      'Transportasi': [
        'bensin',
        'pertamax',
        'pertalite',
        'solar',
        'parkir',
        'tol',
      ],
      'Kesehatan': ['obat', 'apotek', 'vitamin', 'paracetamol'],
      'Rumah': ['sabun', 'deterjen', 'tissue', 'pembersih'],
      'Tagihan': ['pln', 'listrik', 'internet', 'tagihan'],
    };
    for (final rule in rules.entries) {
      if (rule.value.any(text.contains)) {
        final category = categories.where((item) => item.name == rule.key);
        if (category.isNotEmpty) return category.first.id;
      }
    }
    return null;
  }

  int? _matchMerchant(List<CategoryRecord> categories, String merchant) {
    const rules = {
      'Transportasi': ['pertamina'],
      'Kesehatan': ['apotek', 'kimia farma'],
      'Makanan & Minuman': ['kfc'],
      'Tagihan': ['pln'],
      'Belanja': ['indomaret'],
    };
    for (final rule in rules.entries) {
      if (rule.value.any(merchant.contains)) {
        final category = categories.where((item) => item.name == rule.key);
        if (category.isNotEmpty) return category.first.id;
      }
    }
    return null;
  }
}

String normalizeReceiptText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceFirst(RegExp(r'\s+\d+$'), '');

final receiptCategorySuggestionServiceProvider =
    Provider<ReceiptCategorySuggestionService>(
      (ref) =>
          LocalReceiptCategorySuggestionService(ref.watch(databaseProvider)),
    );
