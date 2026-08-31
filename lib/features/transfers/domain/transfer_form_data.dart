class TransferFormData {
  const TransferFormData({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.transferDate,
    required this.note,
  });

  final int fromAccountId;
  final int toAccountId;
  final int amount;
  final DateTime transferDate;
  final String? note;
}
