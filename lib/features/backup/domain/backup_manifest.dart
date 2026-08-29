class BackupManifest {
  const BackupManifest({
    required this.application,
    required this.backupVersion,
    required this.databaseVersion,
    required this.createdAt,
    required this.appVersion,
  });

  static const currentBackupVersion = 1;
  static const applicationName = 'Catatan Keuangan';

  final String application;
  final int backupVersion;
  final int databaseVersion;
  final DateTime createdAt;
  final String appVersion;

  factory BackupManifest.create({
    required int databaseVersion,
    required DateTime createdAt,
    required String appVersion,
  }) {
    return BackupManifest(
      application: applicationName,
      backupVersion: currentBackupVersion,
      databaseVersion: databaseVersion,
      createdAt: createdAt.toUtc(),
      appVersion: appVersion,
    );
  }

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    final application = json['application'];
    final backupVersion = json['backupVersion'];
    final databaseVersion = json['databaseVersion'];
    final createdAtValue = json['createdAt'];
    final appVersion = json['appVersion'];
    final createdAt = createdAtValue is String
        ? DateTime.tryParse(createdAtValue)
        : null;

    if (application != applicationName ||
        backupVersion != currentBackupVersion ||
        databaseVersion is! int ||
        databaseVersion < 1 ||
        createdAt == null ||
        appVersion is! String ||
        appVersion.trim().isEmpty) {
      throw const FormatException('Invalid backup manifest');
    }

    return BackupManifest(
      application: application,
      backupVersion: backupVersion,
      databaseVersion: databaseVersion,
      createdAt: createdAt.toUtc(),
      appVersion: appVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'application': application,
    'backupVersion': backupVersion,
    'databaseVersion': databaseVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
  };
}
