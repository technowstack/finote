/// Sealed class yang memetakan setiap kegagalan deteksi database legacy
/// ke pesan yang ramah pengguna dalam Bahasa Indonesia.
sealed class LegacyDetectionError implements Exception {
  const LegacyDetectionError();

  /// File yang dipilih bukan database SQLite yang valid, atau tidak dapat
  /// dibaca.
  const factory LegacyDetectionError.notSqlite() = _NotSqlite;

  /// File adalah SQLite yang valid, namun tidak mengandung tabel-tabel
  /// minimum yang diperlukan untuk dikenali sebagai database legacy
  /// Catatan Keuangan.
  const factory LegacyDetectionError.incompatibleSchema({
    required Set<String> missingTables,
  }) = _IncompatibleSchema;

  /// Kesalahan tak terduga saat proses deteksi.
  const factory LegacyDetectionError.unknown(Object cause) = _Unknown;

  /// Pesan yang ditampilkan langsung ke pengguna.
  String toUserMessage();
}

// ---------------------------------------------------------------------------
// Implementasi internal
// ---------------------------------------------------------------------------

final class _NotSqlite extends LegacyDetectionError {
  const _NotSqlite();

  @override
  String toUserMessage() =>
      'File yang dipilih bukan database SQLite yang valid. '
      'Pastikan Anda memilih file backup dari aplikasi Catatan Keuangan lama.';
}

final class _IncompatibleSchema extends LegacyDetectionError {
  const _IncompatibleSchema({required this.missingTables});

  final Set<String> missingTables;

  @override
  String toUserMessage() {
    final tables = missingTables.map((t) => '"$t"').join(', ');
    return 'Database ini tidak kompatibel dengan format yang dikenal. '
        'Tabel yang diperlukan tidak ditemukan: $tables.';
  }
}

final class _Unknown extends LegacyDetectionError {
  const _Unknown(this.cause);

  final Object cause;

  @override
  String toUserMessage() =>
      'Terjadi kesalahan saat membaca database. '
      'Pastikan file tidak rusak dan coba lagi.';
}
