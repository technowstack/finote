import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/finance/net_worth.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../export/data/export_repository.dart';
import '../../export/domain/export_document.dart';
import '../data/report_chart_providers.dart';
import '../data/report_repository.dart';
import 'report_period.dart';
import 'widgets/report_export_dialog.dart';
import 'widgets/report_history_tab.dart';
import 'widgets/report_summary_tab.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  ReportPeriod _period = ReportPeriod.month;
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
    final range = resolveReportRange(_period, customRange: _customRange);
    final filter = ReportFilter(range: range);
    final report = ref.watch(reportProvider(filter));
    final investmentCashflow = ref.watch(investmentCashflowProvider(filter));
    final netWorth = ref.watch(netWorthProvider);
    final trend = ref.watch(financialTrendProvider(filter));
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
                _periodChip('Semua', ReportPeriod.all),
                _periodChip('Hari ini', ReportPeriod.today),
                _periodChip('Minggu ini', ReportPeriod.week),
                _periodChip('Bulan ini', ReportPeriod.month),
                _periodChip('Tahun ini', ReportPeriod.year),
                ChoiceChip(
                  label: const Text('Rentang'),
                  selected: _period == ReportPeriod.custom,
                  onSelected: (_) => _selectCustomRange(),
                ),
              ],
            ),
          ),
          if (_period == ReportPeriod.custom && _customRange != null)
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
                onRetry: () => ref.invalidate(reportProvider(filter)),
              ),
              data: (data) => TabBarView(
                controller: _tabController,
                children: [
                  ReportSummaryTab(
                    data: data,
                    investmentCashflow: investmentCashflow,
                    netWorth: netWorth,
                    accounts: accounts,
                    trend: trend,
                    range: range,
                    onRetryTrend: () =>
                        ref.invalidate(financialTrendProvider(filter)),
                  ),
                  ReportHistoryTab(data: data),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, ReportPeriod period) {
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
        _period = ReportPeriod.custom;
      });
    }
  }

  Future<void> _openExport(ReportRange range) async {
    try {
      final document = await ref
          .read(exportRepositoryProvider)
          .buildDocument(
            _period == ReportPeriod.all
                ? const ExportFilter()
                : ExportFilter(startDate: range.start, endDate: range.end),
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => ReportExportDialog(document: document),
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
