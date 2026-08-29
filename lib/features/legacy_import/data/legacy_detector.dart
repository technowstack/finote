import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../domain/legacy_detection_error.dart';
import '../domain/legacy_detection_result.dart';
import '../domain/legacy_schema.dart';

/// Service yang mendeteksi dan membaca metadata dari database legacy
/// Catatan Keuangan secara **read-only**.
///
/// Tidak ada penulisan, INSERT, UPDATE, maupun DELETE yang dilakukan.
/// Koneksi selalu dibuka dengan [OpenMode.readOnly].
class LegacyDetector {
  const LegacyDetector();

  /// Membuka [filePath] dan mengembalikan [LegacyDetectionResult] jika
  /// database kompatibel.
  ///
  /// Melempar [LegacyDetectionError] jika:
  /// - File tidak ada / bukan SQLite → [LegacyDetectionError.notSqlite]
  /// - Tabel wajib tidak ditemukan  → [LegacyDetectionError.incompatibleSchema]
  /// - Error tak terduga            → [LegacyDetectionError.unknown]
  Future<LegacyDetectionResult> detect(String filePath) async {
    // Pastikan file ada
    final file = File(filePath);
    if (!file.existsSync()) {
      throw const LegacyDetectionError.notSqlite();
    }

    Database? db;
    try {
      // Buka read-only — TIDAK ada flag write
      db = _openReadOnly(filePath);

      // 1. Baca daftar tabel
      final tablesFound = _readTableNames(db);

      // 2. Bandingkan dengan schema yang dikenal
      final tablesRecognised = tablesFound.intersection(
        LegacySchema.knownTables,
      );
      final tablesMissing = LegacySchema.requiredTables.difference(tablesFound);

      // 3. Jika tabel wajib tidak ada → incompatible
      if (tablesMissing.isNotEmpty) {
        throw LegacyDetectionError.incompatibleSchema(
          missingTables: tablesMissing,
        );
      }

      // 4. Baca metadata dari tabel Transaction (read-only)
      final meta = _readTransactionMeta(db);

      return LegacyDetectionResult(
        tablesFound: tablesFound,
        tablesRecognised: tablesRecognised,
        tablesMissing: tablesMissing,
        transactionCount: meta.count,
        categoryCount: meta.categoryCount,
        oldestTransactionAt: meta.oldest,
        newestTransactionAt: meta.newest,
      );
    } on LegacyDetectionError {
      rethrow;
    } catch (e) {
      throw LegacyDetectionError.unknown(e);
    } finally {
      db?.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers — semua read-only
  // ---------------------------------------------------------------------------

  /// Membuka database dengan mode read-only.
  ///
  /// Jika file bukan SQLite yang valid, [sqlite3] akan melempar exception
  /// yang kemudian di-catch di [detect] dan dikonversi ke [LegacyDetectionError.notSqlite].
  Database _openReadOnly(String filePath) {
    try {
      final db = sqlite3.open(filePath, mode: OpenMode.readOnly);
      // Verifikasi cepat: integrity_check ringan
      final result = db.select('PRAGMA integrity_check(1)').first;
      if (result['integrity_check'] != 'ok') {
        db.close();
        throw const LegacyDetectionError.notSqlite();
      }
      return db;
    } on LegacyDetectionError {
      rethrow;
    } catch (_) {
      throw const LegacyDetectionError.notSqlite();
    }
  }

  /// Membaca nama semua tabel dari `sqlite_master`.
  Set<String> _readTableNames(Database db) {
    final rows = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
    );
    return {for (final row in rows) row['name'] as String};
  }

  /// Membaca jumlah transaksi, jumlah kategori unik, dan rentang tanggal
  /// dari tabel `Transaction`.
  ///
  /// Legacy menyimpan tanggal sebagai Unix timestamp dalam **milidetik**.
  _TransactionMeta _readTransactionMeta(Database db) {
    const tableName = 'Transaction';

    // Jumlah baris dan jumlah subType unik
    final countRow = db
        .select(
          'SELECT '
          '  COUNT(*) AS txCount, '
          '  COUNT(DISTINCT ${LegacySchema.colSubType}) AS catCount '
          'FROM "$tableName"',
        )
        .first;

    final txCount = (countRow['txCount'] as int?) ?? 0;
    final catCount = (countRow['catCount'] as int?) ?? 0;

    if (txCount == 0) {
      return _TransactionMeta(
        count: 0,
        categoryCount: 0,
        oldest: null,
        newest: null,
      );
    }

    // Rentang tanggal (Unix ms → DateTime)
    final dateRow = db
        .select(
          'SELECT '
          '  MIN(${LegacySchema.colDate}) AS minDate, '
          '  MAX(${LegacySchema.colDate}) AS maxDate '
          'FROM "$tableName"',
        )
        .first;

    final minMs = dateRow['minDate'];
    final maxMs = dateRow['maxDate'];

    return _TransactionMeta(
      count: txCount,
      categoryCount: catCount,
      oldest: minMs is int
          ? DateTime.fromMillisecondsSinceEpoch(minMs, isUtc: true)
          : null,
      newest: maxMs is int
          ? DateTime.fromMillisecondsSinceEpoch(maxMs, isUtc: true)
          : null,
    );
  }
}

/// Data internal untuk metadata tabel Transaction.
class _TransactionMeta {
  const _TransactionMeta({
    required this.count,
    required this.categoryCount,
    required this.oldest,
    required this.newest,
  });

  final int count;
  final int categoryCount;
  final DateTime? oldest;
  final DateTime? newest;
}
