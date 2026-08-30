import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/report_repository.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  _ReportPeriod _period = _ReportPeriod.month;
  DateTimeRange? _customRange;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = _reportRange(_period, _customRange, DateTime.now());
    final report = ref.watch(reportProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ----- Period selector -----
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.xs,
            ),
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                _periodChip('Hari ini', _ReportPeriod.today),
                _periodChip('Minggu ini', _ReportPeriod.week),
                _periodChip('Bulan ini', _ReportPeriod.month),
                ChoiceChip(
                  label: const Text('Rentang'),
                  selected: _period == _ReportPeriod.custom,
                  onSelected: (_) => _selectCustomRange(),
                ),
              ],
            ),
          ),
          if (_period == _ReportPeriod.custom && _customRange != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                0,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: Text(
                '${DateFormat('d MMM y', 'id_ID').format(_customRange!.start)} - '
                '${DateFormat('d MMM y', 'id_ID').format(_customRange!.end)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

          // ----- Content -----
          Expanded(
            child: report.when(
              loading: () => const AppLoadingState(),
              error: (error, stackTrace) => AppErrorState(
                message: 'Laporan belum dapat dimuat.',
                onRetry: () => ref.invalidate(reportProvider(range)),
              ),
              data: (data) => TabBarView(
                controller: _tabController,
                children: [
                  _SummaryTab(data: data),
                  _HistoryTab(data: data),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, _ReportPeriod period) {
    return ChoiceChip(
      label: Text(label),
      selected: _period == period,
      onSelected: (_) => setState(() => _period = period),
    );
  }

  Future<void> _selectCustomRange() async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange ?? DateTimeRange(start: today, end: today),
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _customRange = selected;
        _period = _ReportPeriod.custom;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Summary (balance + categories)
// ---------------------------------------------------------------------------

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const AppEmptyState(
        icon: Icons.summarize_outlined,
        message: 'Belum ada data pada periode ini.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        _CompactSummary(data: data),
        const SizedBox(height: AppSpacing.xl),
        if (data.topExpenseCategories.isNotEmpty) ...[
          _CategoryBreakdown(
            title: 'Pengeluaran per kategori',
            items: data.topExpenseCategories,
            total: data.totalExpense,
            isExpense: true,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (data.topIncomeCategories.isNotEmpty)
          _CategoryBreakdown(
            title: 'Pemasukan per kategori',
            items: data.topIncomeCategories,
            total: data.totalIncome,
            isExpense: false,
          ),
      ],
    );
  }
}

class _CompactSummary extends StatelessWidget {
  const _CompactSummary({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo periode',
            style: textTheme.labelLarge?.copyWith(
              color: colors.onSecondaryContainer.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatIdr(data.netBalance),
              style: textTheme.displayMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.south_west, size: 14, color: colors.incomeColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                formatIdr(data.totalIncome),
                style: textTheme.titleMedium?.copyWith(
                  color: colors.incomeColor,
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Icon(Icons.north_east, size: 14, color: colors.expenseColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                formatIdr(data.totalExpense),
                style: textTheme.titleMedium?.copyWith(
                  color: colors.expenseColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category breakdown with proportion bars
// ---------------------------------------------------------------------------

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.title,
    required this.items,
    required this.total,
    required this.isExpense,
  });

  final String title;
  final List<CategoryTotal> items;
  final int total;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final barColor = isExpense ? colors.expenseColor : colors.incomeColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _CategoryRow(
                  item: items[i],
                  fraction: total > 0 ? items[i].amount / total : 0,
                  barColor: barColor,
                  isExpense: isExpense,
                ),
                if (i < items.length - 1)
                  const Divider(indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.fraction,
    required this.barColor,
    required this.isExpense,
  });

  final CategoryTotal item;
  final double fraction;
  final Color barColor;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.categoryName, style: textTheme.bodyLarge),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(fraction * 100).round()}%',
                style: textTheme.labelMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatIdr(item.amount),
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.amountColor(isExpense: isExpense),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1).toDouble(),
              backgroundColor: barColor.withValues(alpha: 0.12),
              color: barColor,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Monthly history
// ---------------------------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    if (data.monthlyHistory.isEmpty) {
      return const AppEmptyState(
        icon: Icons.calendar_month_outlined,
        message: 'Belum ada riwayat bulanan.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        Card(
          child: Column(
            children: [
              for (var i = 0; i < data.monthlyHistory.length; i++) ...[
                _MonthlyRow(month: data.monthlyHistory[i]),
                if (i < data.monthlyHistory.length - 1)
                  const Divider(indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthlyRow extends StatelessWidget {
  const _MonthlyRow({required this.month});

  final MonthlyTotal month;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPositive = month.netBalance >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatMonth(month.month), style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '+${formatIdr(month.income)}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.incomeColor,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Text(
                '-${formatIdr(month.expense)}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.expenseColor,
                ),
              ),
              const Spacer(),
              Text(
                formatIdr(month.netBalance),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isPositive
                      ? colors.positiveBalance
                      : colors.negativeBalance,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ReportRange _reportRange(
  _ReportPeriod period,
  DateTimeRange? customRange,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    _ReportPeriod.today => ReportRange(start: today, end: today),
    _ReportPeriod.week => ReportRange(
      start: today.subtract(Duration(days: today.weekday - 1)),
      end: today.add(Duration(days: 7 - today.weekday)),
    ),
    _ReportPeriod.month => ReportRange(
      start: DateTime(today.year, today.month),
      end: DateTime(today.year, today.month + 1, 0),
    ),
    _ReportPeriod.custom => ReportRange(
      start: customRange?.start ?? today,
      end: customRange?.end ?? today,
    ),
  };
}

String _formatMonth(String month) =>
    DateFormat('MMMM y', 'id_ID').format(DateTime.parse('$month-01'));

enum _ReportPeriod { today, week, month, custom }
