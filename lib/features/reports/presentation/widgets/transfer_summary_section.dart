import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../data/report_repository.dart';
import 'report_amount.dart';

class TransferSummarySection extends StatelessWidget {
  const TransferSummarySection({super.key, required this.summary});

  final TransferReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transfer antar akun',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: summary.count == 0
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: AppEmptyState(
                    compact: true,
                    icon: Icons.swap_horiz,
                    message: 'Belum ada transfer',
                    subtitle: 'Transfer tidak memengaruhi total pemasukan dan pengeluaran.',
                  ),
                )
              : ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors.tertiaryContainer,
                    foregroundColor: colors.onTertiaryContainer,
                    child: const Icon(Icons.swap_horiz),
                  ),
                  title: Text('${summary.count} transfer'),
                  subtitle: const Text(
                    'Informasi periode ini, tidak memengaruhi pemasukan atau pengeluaran',
                  ),
                  trailing: ReportAmount(
                    amount: summary.volume,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
        ),
      ],
    );
  }
}
