import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/receipt_scanner/data/local_receipt_category_suggestion_service.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_category_suggestion.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_data.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository categories;
  late LocalReceiptCategorySuggestionService service;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    categories = CategoryRepository(database);
    await categories.initializeDefaults();
    service = LocalReceiptCategorySuggestionService(database);
  });

  tearDown(() => database.close());

  test(
    'suggests receipt merchants and item keywords using active categories',
    () async {
      final receipt = await service.suggestReceiptCategory(
        merchant: 'KFC',
        rawText: '',
      );
      final item = await service.suggestItemCategory(
        const ReceiptItem(name: 'Susu UHT'),
      );

      expect(receipt?.source, CategorySuggestionSource.merchantHeuristic);
      expect(
        (await categories.findActiveById(receipt!.categoryId))!.name,
        'Makanan & Minuman',
      );
      expect(
        (await categories.findActiveById(item!.categoryId))!.name,
        'Makanan & Minuman',
      );
    },
  );

  test('history outranks keyword rules', () async {
    final transport =
        (await categories.watchByType(TransactionType.expense).first)
            .singleWhere((category) => category.name == 'Transportasi');
    await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: transport.id,
      amount: 50000,
      title: 'Pertamina',
      transactionDate: DateTime(2026, 8, 30),
      source: TransactionSource.manual,
    );

    final suggestion = await service.suggestReceiptCategory(
      merchant: 'PERTAMINA',
      rawText: 'PERTAMAX',
    );
    expect(suggestion?.source, CategorySuggestionSource.history);
    expect(suggestion?.categoryId, transport.id);
  });

  test(
    'learned mapping outranks rules and deleted categories are ignored',
    () async {
      final food = await categories.create(
        name: 'Khusus',
        type: TransactionType.expense,
      );
      await service.learnReceiptCategory(
        merchant: 'Toko Khusus',
        categoryId: food.id,
      );
      final learned = await service.suggestReceiptCategory(
        merchant: 'TOKO KHUSUS',
        rawText: '',
      );
      expect(learned?.source, CategorySuggestionSource.merchantMapping);
      expect(learned?.categoryId, food.id);

      await categories.softDelete(food.id);
      expect(
        (await service.suggestReceiptCategory(
          merchant: 'TOKO KHUSUS',
          rawText: '',
        )),
        isNull,
      );
    },
  );

  test(
    'weak evidence returns no suggestion until an explicit save learns it',
    () async {
      expect(
        await service.suggestReceiptCategory(
          merchant: 'Toko Acak',
          rawText: 'nota',
        ),
        isNull,
      );
      final home = (await categories.watchByType(TransactionType.expense).first)
          .singleWhere((category) => category.name == 'Rumah');
      await service.learnItemCategory(
        itemName: 'Sabun Lifebuoy',
        categoryId: home.id,
      );

      final learned = await service.suggestItemCategory(
        const ReceiptItem(name: 'SABUN LIFEBUOY'),
      );
      expect(learned?.source, CategorySuggestionSource.merchantMapping);
      expect(learned?.categoryId, home.id);
    },
  );
}
