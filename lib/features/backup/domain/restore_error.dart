/// Sealed class yang memetakan setiap kondisi kegagalan restore
/// ke pesan yang ramah pengguna dalam Bahasa Indonesia.
sealed class RestoreError implements Exception {
  const RestoreError();

  /// File yang dipilih bukan ZIP yang valid atau tidak dapat dibaca.
  const factory RestoreError.invalidZip() = _InvalidZip;

  /// File manifest di dalam ZIP tidak ada, rusak, atau memiliki field yang
  /// hilang / tidak valid.
  const factory RestoreError.invalidManifest() = _InvalidManifest;

  /// Versi backup ([found]) lebih baru dari versi yang didukung ([required]).
  const factory RestoreError.unsupportedVersion({
    required int found,
    required int required,
  }) = _UnsupportedVersion;

  /// Versi database di dalam backup tidak sama dengan versi database live
  /// saat ini sehingga tidak dapat dipulihkan secara langsung.
  const factory RestoreError.databaseMismatch({
    required int backupVersion,
    required int currentVersion,
  }) = _DatabaseMismatch;

  /// SQLite integrity_check pada file database di dalam backup gagal —
  /// file mungkin korup.
  const factory RestoreError.integrityCheckFailed() = _IntegrityCheckFailed;

  /// Kesalahan tak terduga saat proses restore.
  const factory RestoreError.unknown(Object cause) = _Unknown;

  /// Pesan yang ditampilkan langsung ke pengguna.
  String toUserMessage();
}

// ---------------------------------------------------------------------------
// Implementasi internal
// ---------------------------------------------------------------------------

final class _InvalidZip extends RestoreError {
  const _InvalidZip();

  @override
  String toUserMessage() =>
      'File yang dipilih bukan backup yang valid. '
      'Pastikan Anda memilih file .zip hasil ekspor Catatan Keuangan.';
}

final class _InvalidManifest extends RestoreError {
  const _InvalidManifest();

  @override
  String toUserMessage() =>
      'File backup tidak dapat dibaca: informasi versi di dalamnya rusak '
      'atau tidak lengkap.';
}

final class _UnsupportedVersion extends RestoreError {
  const _UnsupportedVersion({required this.found, required this.required});

  final int found;
  final int required;

  @override
  String toUserMessage() =>
      'Format backup (versi $found) tidak didukung oleh versi aplikasi ini '
      '(mendukung hingga versi $required). '
      'Perbarui aplikasi untuk memulihkan backup ini.';
}

final class _DatabaseMismatch extends RestoreError {
  const _DatabaseMismatch({
    required this.backupVersion,
    required this.currentVersion,
  });

  final int backupVersion;
  final int currentVersion;

  @override
  String toUserMessage() =>
      'Versi database backup ($backupVersion) tidak cocok dengan versi '
      'database aplikasi saat ini ($currentVersion). '
      'Restore tidak dapat dilanjutkan.';
}

final class _IntegrityCheckFailed extends RestoreError {
  const _IntegrityCheckFailed();

  @override
  String toUserMessage() =>
      'File database di dalam backup tampaknya korup dan tidak dapat '
      'dipulihkan. Data Anda saat ini tidak berubah.';
}

final class _Unknown extends RestoreError {
  const _Unknown(this.cause);

  final Object cause;

  @override
  String toUserMessage() =>
      'Terjadi kesalahan tak terduga saat memulihkan backup. '
      'Data Anda sebelumnya tetap aman. Silakan coba lagi.';
}
