import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/shared_widgets.dart';

class ReportChartSection<T> extends StatelessWidget {
  const ReportChartSection({
    super.key,
    required this.title,
    required this.data,
    required this.isEmpty,
    required this.builder,
    required this.onRetry,
    this.subtitle,
    this.height = 240,

    /// Minimum height of the loading/empty/error placeholder only.
    this.emptyMessage = 'Belum ada data untuk ditampilkan.',
  });

  final String title;
  final String? subtitle;
  final AsyncValue<T> data;
  final bool Function(T data) isEmpty;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final double height;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: data.when(
                loading: () =>
                    SizedBox(height: height, child: const AppLoadingState()),
                error: (_, _) => SizedBox(
                  height: height,
                  child: AppErrorState(
                    message: 'Gagal memuat grafik.',
                    onRetry: onRetry,
                  ),
                ),
                // Charts size themselves from their content, so the card
                // grows with large text instead of clipping or overflowing.
                data: (value) => isEmpty(value)
                    ? SizedBox(
                        height: height,
                        child: AppEmptyState(
                          icon: Icons.insert_chart_outlined,
                          message: emptyMessage,
                        ),
                      )
                    : builder(context, value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
