import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/financial_date_range.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account_summary.dart';
import '../../export/data/export_repository.dart';
import '../../export/data/export_service.dart';
import '../../export/domain/export_document.dart';
import '../../transactions/domain/transaction_type.dart';
import '../data/report_chart_providers.dart';
import '../data/report_repository.dart';
import '../domain/report_chart_data.dart';
import 'income_expense_chart.dart';
import 'report_chart_section.dart';

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
    final trend = ref.watch(financialTrendProvider(range));
    final accounts = ref.watch(accountSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            tooltip: 'Export laporan',
            onPressed: () => _openExport(range),
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
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
                _periodChip('Semua', _ReportPeriod.all),
                _periodChip('Hari ini', _ReportPeriod.today),
                _periodChip('Minggu ini', _ReportPeriod.week),
                _periodChip('Bulan ini', _ReportPeriod.month),
                _periodChip('Tahun ini', _ReportPeriod.year),
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
                  _SummaryTab(
                    data: data,
                    accounts: accounts,
                    trend: trend,
                    range: range,
                    onRetryTrend: () =>
                        ref.invalidate(financialTrendProvider(range)),
                  ),
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

  Future<void> _openExport(ReportRange range) async {
    try {
      final document = await ref
          .read(exportRepositoryProvider)
          .buildDocument(
            _period == _ReportPeriod.all
                ? const ExportFilter()
                : ExportFilter(startDate: range.start, endDate: range.end),
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _ExportDialog(document: document),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal membuat laporan.')));
      }
    }
  }
}

class _ExportDialog extends ConsumerStatefulWidget {
  const _ExportDialog({required this.document});

  final ExportDocument document;

  @override
  ConsumerState<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<_ExportDialog> {
  ExportFormat _format = ExportFormat.excel;
  TransactionType? _type;
  bool _busy = false;

  ExportDocument get _document => _type == null
      ? widget.document
      : ExportDocument(
          filter: ExportFilter(
            startDate: widget.document.filter.startDate,
            endDate: widget.document.filter.endDate,
            type: _type,
            categoryId: widget.document.filter.categoryId,
          ),
          generatedAt: widget.document.generatedAt,
          transactions: widget.document.transactions
              .where((row) => row.type == _type)
              .toList(growable: false),
          accounts: widget.document.accounts,
          transfers: const [],
        );

  @override
  Widget build(BuildContext context) {
    final document = _document;
    return AlertDialog(
      title: const Text('Export Laporan'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Periode: ${_periodLabel(document)}'),
            Text('${document.transactions.length} transaksi'),
            const SizedBox(height: AppSpacing.sm),
            Text('Pemasukan: ${formatIdr(document.totalIncome)}'),
            Text('Pengeluaran: ${formatIdr(document.totalExpense)}'),
            Text('Saldo periode: ${formatIdr(document.balance)}'),
            Text('Total aset saat ini: ${formatIdr(document.totalAssets)}'),
            Text(
              '${document.transfers.length} transfer: '
              '${formatIdr(document.transferVolume)}',
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ExportFormat>(
              initialValue: _format,
              decoration: const InputDecoration(labelText: 'Format'),
              items: [
                for (final format in ExportFormat.values)
                  DropdownMenuItem(value: format, child: Text(format.label)),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _format = value!),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<TransactionType?>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Jenis transaksi'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Semua jenis')),
                DropdownMenuItem(
                  value: TransactionType.income,
                  child: Text('Pemasukan'),
                ),
                DropdownMenuItem(
                  value: TransactionType.expense,
                  child: Text('Pengeluaran'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _type = value),
            ),
            if (document.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text('Tidak ada transaksi pada periode ini.'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _share,
          child: const Text('Bagikan'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() => _run(
    (service, document) => service.save(document, _format),
    'File berhasil dibuat.',
  );

  Future<void> _share() => _run((service, document) async {
    await service.share(document, _format);
    return true;
  }, 'File siap dibagikan.');

  Future<void> _run(
    Future<bool> Function(ExportService, ExportDocument) action,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      final result = await action(ref.read(exportServiceProvider), _document);
      if (!mounted) return;
      if (result) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan file.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

String _periodLabel(ExportDocument document) {
  final start = document.filter.startDate;
  final end = document.filter.endDate;
  if (start == null && end == null) return 'Semua transaksi';
  return '${DateFormat('d MMM y', 'id_ID').format(start!)} - ${DateFormat('d MMM y', 'id_ID').format(end!)}';
}

// ---------------------------------------------------------------------------
// Tab 1: Summary (balance + categories)
// ---------------------------------------------------------------------------

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.data,
    required this.accounts,
    required this.trend,
    required this.range,
    required this.onRetryTrend,
  });

  final ReportData data;
  final AsyncValue<List<AccountSummary>> accounts;
  final AsyncValue<List<FinancialTrendPoint>> trend;
  final ReportRange range;
  final VoidCallback onRetryTrend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        if (data.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.summarize_outlined),
              title: Text('Belum ada transaksi pada periode ini.'),
            ),
          )
        else
          _CompactSummary(data: data),
        const SizedBox(height: AppSpacing.xl),
        ReportChartSection<List<FinancialTrendPoint>>(
          title: 'Pemasukan vs Pengeluaran',
          subtitle: 'Perbandingan berdasarkan periode laporan',
          data: trend,
          isEmpty: (points) => !hasIncomeExpenseData(points),
          onRetry: onRetryTrend,
          height: 260,
          emptyMessage: 'Belum ada transaksi pada periode ini.',
          builder: (context, points) => IncomeExpenseChart(
            points: points,
            granularity: chartGranularityFor(range),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (data.topExpenseCategories.isNotEmpty) ...[
          _CategoryBreakdown(
            title: 'Pengeluaran per kategori',
            items: data.topExpenseCategories,
            total: data.totalExpense,
            isExpense: true,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (data.topIncomeCategories.isNotEmpty) ...[
          _CategoryBreakdown(
            title: 'Pemasukan per kategori',
            items: data.topIncomeCategories,
            total: data.totalIncome,
            isExpense: false,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _AccountBalancesSection(accounts: accounts),
        const SizedBox(height: AppSpacing.lg),
        _TransferSummarySection(summary: data.transferSummary),
      ],
    );
  }
}

class _AccountBalancesSection extends StatelessWidget {
  const _AccountBalancesSection({required this.accounts});

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
                      trailing: _ReportAmount(
                        amount: item.balance,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    title: const Text('Total aset'),
                    subtitle: archivedCount == 0
                        ? const Text('Saldo seluruh akun saat ini')
                        : Text(
                            'Saldo seluruh akun, termasuk $archivedCount akun diarsipkan',
                          ),
                    trailing: _ReportAmount(
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

class _TransferSummarySection extends StatelessWidget {
  const _TransferSummarySection({required this.summary});

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
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.tertiaryContainer,
              foregroundColor: colors.onTertiaryContainer,
              child: const Icon(Icons.swap_horiz),
            ),
            title: Text('${summary.count} transfer'),
            subtitle: const Text(
              'Informasi periode ini, tidak memengaruhi pemasukan atau pengeluaran',
            ),
            trailing: _ReportAmount(
              amount: summary.volume,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportAmount extends StatelessWidget {
  const _ReportAmount({required this.amount, this.style});

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
                _MonthlyRow(
                  month: data.monthlyHistory[i],
                  onTap: () => context.push(
                    '/reports/history/${data.monthlyHistory[i].month}',
                  ),
                ),
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
  const _MonthlyRow({required this.month, required this.onTap});

  final MonthlyTotal month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPositive = month.netBalance >= 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
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
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
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
  final periodRange = switch (period) {
    _ReportPeriod.all || _ReportPeriod.year => null,
    _ReportPeriod.today => resolveFinancialDateRange(
      FinancialPeriod.today,
      now: now,
    ),
    _ReportPeriod.week => resolveFinancialDateRange(
      FinancialPeriod.week,
      now: now,
    ),
    _ReportPeriod.month => resolveFinancialDateRange(
      FinancialPeriod.month,
      now: now,
    ),
    _ReportPeriod.custom => resolveFinancialDateRange(
      FinancialPeriod.custom,
      now: now,
      customStart: customRange?.start,
      customEnd: customRange?.end,
    ),
  };
  return switch (period) {
    _ReportPeriod.all => ReportRange(
      start: DateTime(2000, 1, 1),
      end: DateTime(2100, 12, 31),
    ),
    _ReportPeriod.year => ReportRange(
      start: DateTime(now.year),
      end: DateTime(now.year, 12, 31),
    ),
    _ReportPeriod.today || _ReportPeriod.week || _ReportPeriod.month =>
      ReportRange(start: periodRange!.start, end: periodRange.end),
    _ReportPeriod.custom => ReportRange(
      start: periodRange!.start,
      end: periodRange.end,
    ),
  };
}

String _formatMonth(String month) =>
    DateFormat('MMMM y', 'id_ID').format(DateTime.parse('$month-01'));

enum _ReportPeriod { all, today, week, month, year, custom }
