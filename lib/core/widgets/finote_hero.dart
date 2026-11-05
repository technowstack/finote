import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preferences/balance_visibility_provider.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/finote_colors.dart';
import 'shared_widgets.dart';

/// Gradient hero card (components.md `Hero/*`): only hero and FAB carry a
/// shadow. Use it for point-in-time totals, never period cashflow.
class FinoteHero extends StatelessWidget {
  const FinoteHero({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).finote;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: f.heroGradient,
        borderRadius: AppRadius.xlAll,
        boxShadow: f.heroShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.labelMd.copyWith(color: f.onHeroMuted),
                  ),
                ),
                ?action,
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// The main hero amount; masked while balances are hidden.
class FinoteHeroAmount extends StatelessWidget {
  const FinoteHeroAmount({super.key, required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return CurrencyText(
      amount: amount,
      maskable: true,
      alignment: Alignment.centerLeft,
      style: AppTypography.amountHero.copyWith(
        color: Theme.of(context).finote.onHero,
      ),
    );
  }
}

/// Eye toggle that hides/shows balances app-wide (persisted preference).
class BalanceVisibilityButton extends ConsumerWidget {
  const BalanceVisibilityButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = Theme.of(context).finote;
    final hidden = watchBalanceHidden(ref);
    return IconButton(
      tooltip: hidden ? 'Tampilkan saldo' : 'Sembunyikan saldo',
      onPressed: () => ref.read(balanceHiddenProvider.notifier).toggle(),
      style: IconButton.styleFrom(
        backgroundColor: f.onHeroChip,
        foregroundColor: f.onHero,
        fixedSize: const Size(40, 40),
      ),
      icon: Icon(
        hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }
}

/// Translucent sub-block inside a hero (e.g. "Kas & Dompet"). A null
/// [amount] reads "Belum tersedia" — unknown is never shown as zero.
class FinoteHeroTile extends StatelessWidget {
  const FinoteHeroTile({
    super.key,
    required this.label,
    required this.amount,
    this.onTap,
  });

  final String label;
  final int? amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).finote;
    final valueStyle = AppTypography.amountItem.copyWith(color: f.onHero);
    return Material(
      color: f.onHeroChip,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.captionRegular.copyWith(
                          color: f.onHeroMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (amount == null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Belum tersedia', style: valueStyle),
                        )
                      else
                        CurrencyText(
                          amount: amount!,
                          maskable: true,
                          alignment: Alignment.centerLeft,
                          style: valueStyle,
                        ),
                    ],
                  ),
                ),
                if (onTap != null) Icon(Icons.chevron_right, color: f.onHero),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
