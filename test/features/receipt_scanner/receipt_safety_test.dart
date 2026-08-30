import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/receipt_scanner/data/receipt_duplicate_detector.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_data.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_duplicate.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late int categoryId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final categories = CategoryRepository(database);
    await categories.initializeDefaults();
    categoryId = (await categories.watchByType(TransactionType.expense).first)
        .singleWhere((category) => category.name == 'Belanja')
        .id;
  });

  tearDown(() => database.close());

  test(
    'detects strong and possible duplicates but ignores changed identity',
    () async {
      final detector = ReceiptDuplicateDetector(database);
      final identity = ReceiptIdentity(
        merchant: 'Indomaret',
        date: DateTime(2026, 8, 30),
        total: 87500,
        receiptNumber: 'ABC123',
        items: const [ReceiptItem(name: 'Roti', lineTotal: 87500)],
      );
      final fingerprint = await identity.fingerprint();
      await TransactionRepository(database).create(
        type: TransactionType.expense,
        categoryId: categoryId,
        amount: 87500,
        title: 'Indomaret',
        transactionDate: identity.date,
        source: TransactionSource.receiptScan,
        receiptFingerprint: fingerprint,
      );

      expect(
        (await detector.findDuplicate(identity))!.level,
        ReceiptDuplicateLevel.strong,
      );
      expect(
        (await detector.findDuplicate(identity.copyWithoutReceiptNumber()))!
            .level,
        ReceiptDuplicateLevel.possible,
      );
      expect(
        await detector.findDuplicate(
          ReceiptIdentity(
            merchant: 'Indomaret',
            date: DateTime(2026, 8, 31),
            total: 87500,
            receiptNumber: 'OTHER',
            items: identity.items,
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'reconciliation distinguishes match, missing, excess, and explanations',
    () {
      expect(
        ReceiptReviewData(
          total: 30000,
          items: const [ReceiptItem(name: 'Roti', lineTotal: 30000)],
        ).reconciliationMessage,
        'Total item sesuai dengan total struk.',
      );
      expect(
        ReceiptReviewData(
          total: 30000,
          items: const [ReceiptItem(name: 'Roti', lineTotal: 25000)],
        ).reconciliationMessage,
        'Ada kemungkinan item belum terbaca.',
      );
      expect(
        ReceiptReviewData(
          total: 30000,
          items: const [ReceiptItem(name: 'Roti', lineTotal: 35000)],
        ).reconciliationMessage,
        'Total item lebih besar dari total struk.',
      );
      expect(
        ReceiptReviewData(
          total: 33000,
          tax: 3000,
          items: const [ReceiptItem(name: 'Roti', lineTotal: 30000)],
        ).reconciliationMessage,
        'Total item sesuai setelah pajak terdeteksi.',
      );
    },
  );

  test('itemized save rolls back when a later category is invalid', () async {
    final repository = TransactionRepository(database);
    await expectLater(
      repository.createManyWithCategories(
        type: TransactionType.expense,
        entries: [
          (
            amount: 1000,
            title: 'Valid',
            transactionDate: DateTime(2026, 8, 30),
            categoryId: categoryId,
          ),
          (
            amount: 2000,
            title: 'Invalid',
            transactionDate: DateTime(2026, 8, 30),
            categoryId: 999999,
          ),
        ],
        source: TransactionSource.receiptScan,
      ),
      throwsStateError,
    );
    expect(await database.select(database.transactions).get(), isEmpty);
  });
}

extension on ReceiptIdentity {
  ReceiptIdentity copyWithoutReceiptNumber() => ReceiptIdentity(
    merchant: merchant,
    date: date,
    total: total,
    receiptNumber: null,
    items: items,
  );
}
