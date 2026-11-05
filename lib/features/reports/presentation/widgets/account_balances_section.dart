import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../accounts/domain/account_summary.dart';
import 'report_amount.dart';

class AccountBalancesSection extends StatelessWidget {
  const AccountBalancesSection({super.key, required this.accounts});

  final AsyncValue<List<AccountSummary>> accounts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saldo akun saat ini',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: accounts.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: LinearProgressIndicator(),
            ),
            error: (_, _) =>
                const ListTile(title: Text('Saldo akun belum dapat dimuat.')),
            data: (items) {
              final active = items
                  .where((item) => item.account.isActive)
                  .toList(growable: false);
              final archivedCount = items.length - active.length;
              final totalAssets = items.fold<int>(
                0,
                (total, item) => total + item.balance,
              );
              return Column(
                children: [
                  if (active.isEmpty)
                    const ListTile(title: Text('Belum ada akun aktif.')),
                  for (final item in active)
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: Text(item.account.name),
                      trailing: ReportAmount(
                        amount: item.balance,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    title: const Text('Kas & dompet'),
                    subtitle: archivedCount == 0
                        ? const Text('Saldo seluruh akun saat ini')
                        : Text(
                            'Saldo seluruh akun, termasuk $archivedCount akun diarsipkan',
                          ),
                    trailing: ReportAmount(
                      amount: totalAssets,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
