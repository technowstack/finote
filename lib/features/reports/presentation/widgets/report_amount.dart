import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';

class ReportAmount extends StatelessWidget {
  const ReportAmount({super.key, required this.amount, this.style});

  final int amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(formatIdr(amount), style: style),
      ),
    );
  }
}
