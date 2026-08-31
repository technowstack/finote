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
  });

  final FinancialActivityType type;
  final int entityId;
  final String uuid;
  final DateTime date;
  final int amount;
  final String title;
  final String subtitle;
  final String? categoryName;

  String get identity =>
      '${type == FinancialActivityType.transfer ? 'transfer' : 'transaction'}:$uuid';
}
