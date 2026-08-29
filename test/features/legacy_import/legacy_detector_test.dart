import 'dart:io';
import 'dart:typed_data';

import 'package:finote/features/legacy_import/data/legacy_detector.dart';
import 'package:finote/features/legacy_import/domain/legacy_detection_error.dart';
import 'package:finote/features/legacy_import/domain/legacy_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finote_legacy_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // ---------------------------------------------------------------------------
  // Helper: membuat file SQLite minimal di tempDir
  // ---------------------------------------------------------------------------
  Future<String> createSqliteFile(
    String name,
    void Function(Database db) setup,
  ) async {
    final path = '${tempDir.path}/$name';
    final db = sqlite3.open(path);
    try {
      setup(db);
    } finally {
      db.close();
    }
    return path;
  }

  // ---------------------------------------------------------------------------
  // Helper: membuat database dengan schema legacy lengkap
  // ---------------------------------------------------------------------------
  Future<String> createLegacyDb(
    String name, {
    List<Map<String, Object?>> transactions = const [],
  }) async {
    return createSqliteFile(name, (db) {
      // Tabel-tabel legacy
      db.execute('''
        CREATE TABLE "Transaction" (
          id       INTEGER PRIMARY KEY,
          type     INTEGER NOT NULL,
          amount   INTEGER NOT NULL,
          subType  INTEGER NOT NULL,
          date     INTEGER NOT NULL,
          title    TEXT
        )
      ''');
      db.execute('''
        CREATE TABLE TransactionSubType (
          id   INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      db.execute('''
        CREATE TABLE TransactionDay (
          id   INTEGER PRIMARY KEY,
          date INTEGER NOT NULL
        )
      ''');
      db.execute('''
        CREATE TABLE TransactionType (
          id   INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      db.execute('''
        CREATE TABLE AppSetting (
          key   TEXT PRIMARY KEY,
          value TEXT
        )
      ''');

      for (final tx in transactions) {
        db.execute(
          'INSERT INTO "Transaction" (type, amount, subType, date, title) '
          'VALUES (?, ?, ?, ?, ?)',
          [tx['type'], tx['amount'], tx['subType'], tx['date'], tx['title']],
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 1. File bukan SQLite
  // ---------------------------------------------------------------------------
  test('file bukan SQLite melempar LegacyDetectionError.notSqlite', () async {
    final path = '${tempDir.path}/not_sqlite.db';
    // Tulis bytes acak
    await File(path)
        .writeAsBytes(Uint8List.fromList(List.generate(512, (i) => i % 256)));

    await expectLater(
      const LegacyDetector().detect(path),
      throwsA(isA<LegacyDetectionError>()),
    );

    try {
      await const LegacyDetector().detect(path);
    } on LegacyDetectionError catch (e) {
      expect(e.toUserMessage(), isNotEmpty);
    }
  });

  test('file tidak ada melempar LegacyDetectionError.notSqlite', () async {
    await expectLater(
      const LegacyDetector().detect('${tempDir.path}/nonexistent.db'),
      throwsA(isA<LegacyDetectionError>()),
    );
  });

  // ---------------------------------------------------------------------------
  // 2. SQLite valid tapi tabel wajib tidak ada
  // ---------------------------------------------------------------------------
  test(
    'SQLite tanpa tabel wajib melempar LegacyDetectionError.incompatibleSchema',
    () async {
      final path = await createSqliteFile('no_tables.db', (db) {
        // Buat tabel acak, bukan legacy
        db.execute('CREATE TABLE foo (id INTEGER PRIMARY KEY)');
      });

      try {
        await const LegacyDetector().detect(path);
        fail('Expected LegacyDetectionError.incompatibleSchema');
      } on LegacyDetectionError catch (e) {
        final msg = e.toUserMessage();
        expect(msg, isNotEmpty);
        // Pesan harus menyebutkan tabel yang hilang
        expect(
          msg,
          anyOf(
            contains('Transaction'),
            contains('TransactionSubType'),
            contains('diperlukan'),
          ),
        );
      }
    },
  );

  test(
    'SQLite dengan sebagian tabel wajib melempar incompatibleSchema',
    () async {
      // Hanya ada Transaction, TransactionSubType tidak ada
      final path = await createSqliteFile('partial.db', (db) {
        db.execute(
          'CREATE TABLE "Transaction" (id INTEGER PRIMARY KEY, type INTEGER, '
          'amount INTEGER, subType INTEGER, date INTEGER)',
        );
        // TransactionSubType sengaja tidak dibuat
      });

      await expectLater(
        const LegacyDetector().detect(path),
        throwsA(isA<LegacyDetectionError>()),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // 3. Schema kompatibel, 0 transaksi
  // ---------------------------------------------------------------------------
  test('schema kompatibel tanpa transaksi mengembalikan count = 0', () async {
    final path = await createLegacyDb('empty.db');
    final result = await const LegacyDetector().detect(path);

    expect(result.isCompatible, isTrue);
    expect(result.transactionCount, 0);
    expect(result.categoryCount, 0);
    expect(result.oldestTransactionAt, isNull);
    expect(result.newestTransactionAt, isNull);
    expect(result.tablesRecognised, containsAll(LegacySchema.requiredTables));
  });

  // ---------------------------------------------------------------------------
  // 4. Schema kompatibel, data ada — verifikasi count dan rentang tanggal
  // ---------------------------------------------------------------------------
  test(
    'schema kompatibel dengan transaksi mengembalikan metadata yang benar',
    () async {
      // Unix ms untuk 1 Jan 2023 dan 31 Des 2023
      const dateOldest = 1672531200000; // 2023-01-01 00:00:00 UTC
      const dateNewest = 1703980800000; // 2023-12-31 00:00:00 UTC

      final path = await createLegacyDb(
        'with_data.db',
        transactions: [
          {
            'type': 0,
            'amount': 25000,
            'subType': 1,
            'date': dateOldest,
            'title': 'Makan',
          },
          {
            'type': 1,
            'amount': 500000,
            'subType': 2,
            'date': dateNewest,
            'title': 'Gaji',
          },
          {
            'type': 0,
            'amount': 10000,
            'subType': 1,
            'date': dateOldest + 86400000,
            'title': 'Bensin',
          },
        ],
      );

      final result = await const LegacyDetector().detect(path);

      expect(result.isCompatible, isTrue);
      expect(result.transactionCount, 3);
      // 2 subType unik: 1 dan 2
      expect(result.categoryCount, 2);
      expect(
        result.oldestTransactionAt,
        DateTime.fromMillisecondsSinceEpoch(dateOldest, isUtc: true),
      );
      expect(
        result.newestTransactionAt,
        DateTime.fromMillisecondsSinceEpoch(dateNewest, isUtc: true),
      );
      // Semua 5 tabel legacy ditemukan
      expect(result.tablesFound.length, 5);
      expect(result.tablesRecognised, equals(LegacySchema.knownTables));
      expect(result.tablesMissing, isEmpty);
    },
  );
}
