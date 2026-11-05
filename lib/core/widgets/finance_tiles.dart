import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transactions/domain/transaction_type.dart';
import '../preferences/balance_visibility_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/category_style.dart';
import '../theme/finote_colors.dart';
import '../utils/currency_formatter.dart';
import 'shared_widgets.dart';

/// 44×44 rounded icon tile in a category's colors.
class CategoryIconTile extends StatelessWidget {
  const CategoryIconTile({super.key, required this.style});

  final CategoryStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: AppRadius.mdAll,
      ),
      child: Icon(style.icon, color: style.foreground),
    );
  }
}

/// Shared row layout for Item/* tiles: 48dp minimum hit area, leading tile,
/// text column, trailing column. Switches the trailing column under the text
/// at large text scales so amounts never squeeze titles.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.leading,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.details = const [],
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// Extra muted lines under the subtitle, each on its own line.
  final List<String> details;
  final List<Widget> trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.labelLg.copyWith(color: theme.colorScheme.onSurface),
    );
    final trailingColumn = Column(
      crossAxisAlignment: largeText
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: trailing,
    );
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                leading,
                const SizedBox(width: AppSpacing.md),
                // Expanded + Flexible would split the space 50/50 and
                // truncate titles; cap the amount column instead so the
                // title takes whatever it leaves.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleText,
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      for (final line in details)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      if (largeText) trailingColumn,
                    ],
                  ),
                ),
                if (!largeText) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.45,
                    ),
                    child: trailingColumn,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// components.md `Item/Pengeluaran` & `Item/Pemasukan`: category icon,
/// red/green only on the signed amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.title,
    required this.categoryName,
    required this.amount,
    required this.type,
    this.subtitle,
    this.details = const [],
    this.caption,
    this.maskable = false,
    this.onTap,
  });

  /// Optional user title; falls back to the category name.
  final String title;
  final String categoryName;
  final int amount;
  final TransactionType type;

  /// Line under the title. When null it falls back to the category name for
  /// titled rows (the original Beranda behavior).
  final String? subtitle;

  /// Extra muted lines under the subtitle (e.g. a note), one per line.
  final List<String> details;

  /// Small muted text under the amount (e.g. the category).
  final String? caption;

  /// Mask the amount while the user hides balances.
  final bool maskable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ItemRow(
      onTap: onTap,
      leading: CategoryIconTile(
        style: theme.finote.categoryStyle(categoryName),
      ),
      title: title.isEmpty ? categoryName : title,
      subtitle: subtitle ?? (title.isEmpty ? null : categoryName),
      details: details,
      trailing: [
        CurrencyText(amount: amount, type: type, maskable: maskable),
        if (caption != null)
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

/// components.md `Item/Transfer`: neutral colors; a transfer is neither
/// income nor expense.
class TransferTile extends StatelessWidget {
  const TransferTile({
    super.key,
    required this.title,
    required this.route,
    required this.amount,
    this.maskable = false,
    this.onTap,
  });

  final String title;

  /// e.g. "BCA → Dompet tunai · 09.15".
  final String route;
  final int amount;

  /// Mask the amount while the user hides balances.
  final bool maskable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ItemRow(
      onTap: onTap,
      leading: CategoryIconTile(style: theme.finote.transferStyle),
      title: title,
      subtitle: route,
      trailing: [
        CurrencyText(
          amount: amount,
          maskable: maskable,
          style: AppTypography.amountItem.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text('Transfer', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// components.md `Item/Aset`. A null [value] means no known price; it reads
/// "Belum ada harga" and is never shown as zero.
class AssetTile extends StatelessWidget {
  const AssetTile({
    super.key,
    required this.name,
    required this.value,
    this.code,
    this.info,
    this.change,
    this.changePositive,
    this.emptyLabel = 'Belum ada harga',
    this.maskable = false,
    this.trailing,
    this.onTap,
  });

  final String name;

  /// Current value in rupiah, or null when it is unknown (never zero).
  final int? value;
  final String? code;
  final String? info;
  final String? change;
  final bool? changePositive;

  /// Shown instead of the value when it is unknown; pass null to show nothing.
  final String? emptyLabel;

  /// Mask the value while the user hides balances.
  final bool maskable;

  /// Optional trailing control (e.g. an actions menu). It must bring its own
  /// 48dp hit area.
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;

    final heading = Wrap(
      spacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          name,
          style: AppTypography.labelLg.copyWith(color: colors.onSurface),
        ),
        if (code != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: AppRadius.smAll,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              child: Text(
                code!,
                style: AppTypography.captionMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );

    final valueColumn = Column(
      crossAxisAlignment: largeText
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          CurrencyText(
            amount: value!,
            maskable: maskable,
            alignment: largeText ? Alignment.centerLeft : Alignment.centerRight,
            style: AppTypography.amountMd.copyWith(color: colors.onSurface),
          )
        else if (emptyLabel != null)
          Text(emptyLabel!, style: theme.textTheme.bodySmall),
        if (change != null)
          Text(
            change!,
            style: AppTypography.amountXs.copyWith(
              fontWeight: FontWeight.w500,
              color: changePositive == null
                  ? colors.onSurfaceVariant
                  : colors.amountColor(isExpense: !changePositive!),
            ),
          ),
      ],
    );

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      if (info != null)
                        Text(
                          info!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      if (largeText) ...[
                        const SizedBox(height: AppSpacing.xs),
                        valueColumn,
                      ],
                    ],
                  ),
                ),
                if (!largeText) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.45,
                    ),
                    child: valueColumn,
                  ),
                ],
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// components.md `Header Tanggal`: date label with an optional signed daily
/// total (green when positive, red when negative).
class DateHeader extends StatelessWidget {
  const DateHeader({
    super.key,
    required this.label,
    this.total,
    this.maskable = false,
  });

  final String label;
  final int? total;

  /// Mask the total while the user hides balances.
  final bool maskable;

  @override
  Widget build(BuildContext context) {
    if (!maskable) return _content(context, hidden: false);
    return Consumer(
      builder: (context, ref, _) =>
          _content(context, hidden: watchBalanceHidden(ref)),
    );
  }

  Widget _content(BuildContext context, {required bool hidden}) {
    final colors = Theme.of(context).colorScheme;
    final total = this.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.sm,
        children: [
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          if (total != null)
            Text(
              hidden
                  ? maskedAmount
                  : total == 0
                  ? formatIdr(0)
                  : '${total < 0 ? '-' : '+'}${formatIdr(total.abs())}',
              style: AppTypography.amountXs.copyWith(
                color: hidden || total == 0
                    ? colors.onSurfaceVariant
                    : colors.amountColor(isExpense: total < 0),
              ),
            ),
        ],
      ),
    );
  }
}

/// components.md `Bar Kategori`: name · percent, amount, and a track in the
/// category's colors. [fraction] is 0..1 of the period total.
class CategoryBar extends StatelessWidget {
  const CategoryBar({
    super.key,
    required this.name,
    required this.fraction,
    required this.amount,
    this.isExpense = true,
    this.maskable = false,
  });

  final String name;
  final double fraction;
  final int amount;

  /// Picks the red/green amount color; the bar itself uses the category color.
  final bool isExpense;

  /// Mask the amount while the user hides balances.
  final bool maskable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.finote.categoryStyle(name);
    final percent = (fraction * 100).round();
    return Semantics(
      label: '$name $percent persen, ${formatIdr(amount)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.sm,
            children: [
              Text(
                '$name · $percent%',
                style: AppTypography.bodyMd.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              CurrencyText(
                amount: amount,
                maskable: maskable,
                alignment: Alignment.centerRight,
                style: AppTypography.amountSm.copyWith(
                  color: theme.colorScheme.amountColor(isExpense: isExpense),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 8,
              color: style.foreground,
              backgroundColor: style.background,
            ),
          ),
        ],
      ),
    );
  }
}
