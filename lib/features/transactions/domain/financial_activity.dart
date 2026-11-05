enum FinancialActivityType { income, expense, transfer }

class FinancialActivity {
  const FinancialActivity({
    required this.type,
    required this.entityId,
    required this.uuid,
    required this.date,
    required this.amount,
    required this.title,
    required this.subtitle,
    this.categoryName,
    this.note,
    this.createdAt,
    this.isDefaultAccount = false,
  });

  final FinancialActivityType type;
  final int entityId;
  final String uuid;
  final DateTime date;
  final int amount;
  final String title;
  final String subtitle;
  final String? categoryName;

  /// Display-only extras; filters and search never read these.
  final String? note;

  /// When the record was entered (UTC). It is not the transaction date, so
  /// callers must not present it as the time of the transaction by itself.
  final DateTime? createdAt;

  /// True when the transaction belongs to the default account, whose name is
  /// omitted from list rows. Always false for transfers.
  final bool isDefaultAccount;

  String get identity =>
      '${type == FinancialActivityType.transfer ? 'transfer' : 'transaction'}:$uuid';
}
