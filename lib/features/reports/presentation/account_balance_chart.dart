import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../accounts/domain/account_type.dart';
import '../domain/report_chart_data.dart';

List<AccountBalanceChartPoint> visibleAccountBalances(
  List<AccountBalanceChartPoint> points,
) {
  return [...points.where((point) => point.isActive)]..sort((a, b) {
    final byBalance = b.balance.compareTo(a.balance);
    if (byBalance != 0) return byBalance;
    final byName = a.accountName.toLowerCase().compareTo(
      b.accountName.toLowerCase(),
    );
    return byName != 0 ? byName : a.accountId.compareTo(b.accountId);
  });
}

class AccountBalanceChart extends StatelessWidget {
  const AccountBalanceChart({
    super.key,
    required this.points,
    required this.totalAssets,
    required this.archivedCount,
  });

  final List<AccountBalanceChartPoint> points;
  final int totalAssets;
  final int archivedCount;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AppEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: 'Belum ada akun untuk ditampilkan.',
      );
    }

    final lowest = min(0, points.map((point) => point.balance).reduce(min));
    final highest = max(0, points.map((point) => point.balance).reduce(max));
    final span = max(1, highest - lowest);
    return Semantics(
      container: true,
      label: _semanticLabel(),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              _TotalAssets(amount: totalAssets, archivedCount: archivedCount),
              const SizedBox(height: AppSpacing.md),
              for (final point in points)
                Expanded(
                  child: _AccountBar(point: point, lowest: lowest, span: span),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _semanticLabel() {
    final archived = archivedCount == 0
        ? ''
        : ', termasuk $archivedCount akun diarsipkan';
    return 'Saldo per Akun. Total Aset ${formatIdr(totalAssets)}$archived. '
        '${points.map((point) => '${point.accountName}, ${point.accountType.label}, ${formatIdr(point.balance)}').join('. ')}';
  }
}

class _TotalAssets extends StatelessWidget {
  const _TotalAssets({required this.amount, required this.archivedCount});

  final int amount;
  final int archivedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Aset', style: Theme.of(context).textTheme.labelLarge),
              Text(
                archivedCount == 0
                    ? 'Saldo seluruh akun saat ini'
                    : 'Termasuk $archivedCount akun diarsipkan',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              formatIdr(amount),
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountBar extends StatelessWidget {
  const _AccountBar({
    required this.point,
    required this.lowest,
    required this.span,
  });

  final AccountBalanceChartPoint point;
  final int lowest;
  final int span;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final barColor = point.balance.isNegative
        ? colors.expenseColor
        : colors.primary;
    return Semantics(
      container: true,
      label:
          '${point.accountName}, ${point.accountType.label}, ${formatIdr(point.balance)}',
      child: Tooltip(
        message:
            '${point.accountName}\n${point.accountType.label}\n${formatIdr(point.balance)}',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            point.accountName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            point.accountType.label,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      formatCompactIdr(point.balance),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: barColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 10,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final zero = -lowest / span * constraints.maxWidth;
                        final width =
                            point.balance.abs() / span * constraints.maxWidth;
                        return Stack(
                          children: [
                            ColoredBox(
                              color: colors.primary.withValues(alpha: 0.1),
                              child: const SizedBox.expand(),
                            ),
                            Positioned(
                              left: point.balance.isNegative
                                  ? zero - width
                                  : zero,
                              width: width,
                              top: 0,
                              bottom: 0,
                              child: ColoredBox(
                                key: Key(
                                  'account-balance-bar-${point.accountId}',
                                ),
                                color: barColor,
                              ),
                            ),
                            Positioned(
                              key: Key(
                                'account-balance-zero-${point.accountId}',
                              ),
                              left: zero.clamp(0, constraints.maxWidth - 1),
                              top: 0,
                              bottom: 0,
                              child: ColoredBox(color: colors.onSurfaceVariant),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
