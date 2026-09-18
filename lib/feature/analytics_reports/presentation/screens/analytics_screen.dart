import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../data/models/analytics_models.dart';
import '../providers/analytics_providers.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _isExporting = false;

  final _horizons = const [
    (AnalyticsTimeHorizon.daily, 'Daily'),
    (AnalyticsTimeHorizon.weekly, 'Weekly'),
    (AnalyticsTimeHorizon.monthly, 'Monthly'),
    (AnalyticsTimeHorizon.yearly, 'Yearly'),
    (AnalyticsTimeHorizon.quarterly, 'Quarterly (Crop Cycles)'),
    (AnalyticsTimeHorizon.tenYear, '10-Year Trends'),
    (AnalyticsTimeHorizon.custom, 'Custom Range'),
  ];

  Future<void> _exportPdf(AnalyticsReportData report) async {
    setState(() => _isExporting = true);
    try {
      await ref.read(analyticsPdfServiceProvider).shareReportPdf(report);
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to export PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcel(AnalyticsReportData report) async {
    setState(() => _isExporting = true);
    try {
      await ref.read(analyticsExcelServiceProvider).shareReportExcel(report);
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to export Excel: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedHorizon = ref.watch(selectedHorizonProvider);
    final reportAsync = ref.watch(analyticsReportProvider);
    final customRange = ref.watch(customDateRangeProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Financial Reports & Analytics',
        actions: [
          if (reportAsync.hasValue) ...[
            IconButton(
              icon: _isExporting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export PDF Report',
              onPressed: _isExporting ? null : () => _exportPdf(reportAsync.value!),
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_rounded),
              tooltip: 'Export Excel Spreadsheet (.xlsx)',
              onPressed: _isExporting ? null : () => _exportExcel(reportAsync.value!),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Analytics',
            onPressed: () => ref.invalidate(analyticsReportProvider),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHorizonSelector(selectedHorizon),
          if (selectedHorizon == AnalyticsTimeHorizon.custom)
            _buildCustomDateRangePicker(customRange),
          const Divider(height: 1),
          Expanded(
            child: reportAsync.when(
              loading: () => const AppLoader(message: 'Calculating financial analytics...'),
              error: (err, _) => AppErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(analyticsReportProvider),
              ),
              data: (report) => _buildReportView(report),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonSelector(AnalyticsTimeHorizon selected) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _horizons.map((item) {
            final isSelected = item.$1 == selected;
            return Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm.w),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13.sp,
                ),
                onSelected: (_) {
                  ref.read(selectedHorizonProvider.notifier).state = item.$1;
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomDateRangePicker(DateTimeRange? range) {
    final dateFmt = DateFormat('dd MMM yyyy');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
      color: AppColors.primaryLight.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 20, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                range != null
                    ? '${dateFmt.format(range.start)} – ${dateFmt.format(range.end)}'
                    : 'Select Custom Date Range',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            ),
            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
            label: const Text('Change Dates'),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2015),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: range ??
                    DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 30)),
                      end: DateTime.now(),
                    ),
              );
              if (picked != null) {
                ref.read(customDateRangeProvider.notifier).state = picked;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportView(AnalyticsReportData report) {
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('dd MMM yyyy');
    final isWide = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    final hasData = report.summary.totalIncome > 0 ||
        report.summary.totalExpense > 0 ||
        report.summary.totalUdharLent > 0 ||
        report.summary.totalUdharCollected > 0;

    if (!hasData && report.categoryBreakdown.isEmpty) {
      return Center(
        child: AppEmptyState(
          title: 'No financial records for this period',
          subtitle: 'Log income, expenses, or Udhar entries to see full analytics and P&L statements.',
          icon: Icons.analytics_outlined,
          actionLabel: 'Refresh',
          onAction: () => ref.invalidate(analyticsReportProvider),
        ),
      );
    }

    final content = ListView(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      children: [
        // ── 1. Reporting Header Banner ──────────────────────────────────────
        Container(
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Statement Period',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${dateFmt.format(report.startDate)} — ${dateFmt.format(report.endDate)}',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('PDF'),
                    onPressed: () => _exportPdf(report),
                  ),
                  SizedBox(width: AppSpacing.sm.w),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text('Excel'),
                    onPressed: () => _exportExcel(report),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg.h),

        // ── 2. Executive Summary Metrics Grid ────────────────────────────────
        Text('Executive Summary', style: AppTextStyles.h3),
        SizedBox(height: AppSpacing.sm.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWideGrid = constraints.maxWidth >= AppConstants.tabletBreakpoint;
            return GridView.count(
              crossAxisCount: isWideGrid ? 4 : 2,
              crossAxisSpacing: AppSpacing.md.w,
              mainAxisSpacing: AppSpacing.md.h,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isWideGrid ? 1.6 : 1.35,
              children: [
                _buildSummaryCard(
                  title: 'Total Income',
                  value: currencyFmt.format(report.summary.totalIncome),
                  icon: Icons.trending_up_rounded,
                  color: AppColors.credit,
                  bgColor: AppColors.creditLight.withValues(alpha: 0.3),
                ),
                _buildSummaryCard(
                  title: 'Total Expenses',
                  value: currencyFmt.format(report.summary.totalExpense),
                  icon: Icons.trending_down_rounded,
                  color: AppColors.debit,
                  bgColor: AppColors.debitLight.withValues(alpha: 0.3),
                ),
                _buildSummaryCard(
                  title: 'Net Savings',
                  value: currencyFmt.format(report.summary.netSavings),
                  icon: Icons.account_balance_wallet_rounded,
                  color: report.summary.netSavings >= 0 ? AppColors.credit : AppColors.debit,
                  bgColor: (report.summary.netSavings >= 0 ? AppColors.creditLight : AppColors.debitLight)
                      .withValues(alpha: 0.3),
                ),
                _buildSummaryCard(
                  title: 'Udhar Lent / Recovered',
                  value: '${currencyFmt.format(report.summary.totalUdharLent)} / ${currencyFmt.format(report.summary.totalUdharCollected)}',
                  subtitle: 'Net Rec: ${currencyFmt.format(report.summary.netUdharReceivable)}',
                  icon: Icons.handshake_outlined,
                  color: AppColors.primary,
                  bgColor: AppColors.primaryLight.withValues(alpha: 0.3),
                ),
              ],
            );
          },
        ),
        SizedBox(height: AppSpacing.xl.h),

        // ── 3. Category Spending Breakdown ──────────────────────────────────
        if (report.categoryBreakdown.isNotEmpty) ...[
          Text('Expense Category Distribution', style: AppTextStyles.h3),
          SizedBox(height: AppSpacing.sm.h),
          AppCard(
            child: Column(
              children: report.categoryBreakdown.map((cat) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(cat.iconKey ?? '🛒', style: const TextStyle(fontSize: 18)),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              cat.categoryName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            currencyFmt.format(cat.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '(${cat.percentage.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      LinearProgressIndicator(
                        value: (cat.percentage / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        color: AppColors.primary,
                        minHeight: 6.h,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),
        ],

        // ── 4. Quarterly Agricultural Breakdown (Kishanganj) ────────────────
        if (report.horizon == AnalyticsTimeHorizon.quarterly && report.quarterlyBreakdown.isNotEmpty) ...[
          Text('Agricultural Crop-Cycle Analysis (Kishanganj, Bihar)', style: AppTextStyles.h3),
          SizedBox(height: AppSpacing.sm.h),
          AppCard(
            child: Column(
              children: report.quarterlyBreakdown.map((q) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      q.quarterName,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                  ),
                  title: Text(
                    '${q.agriculturalCycle} (${q.monthsLabel})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Income: ${currencyFmt.format(q.income)} • Expense: ${currencyFmt.format(q.expense)}',
                  ),
                  trailing: Text(
                    '${q.netProfit >= 0 ? '+' : ''}${currencyFmt.format(q.netProfit)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      color: q.netProfit >= 0 ? AppColors.credit : AppColors.debit,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),
        ],

        // ── 5. 10-Year Historical Lookback ──────────────────────────────────
        if (report.horizon == AnalyticsTimeHorizon.tenYear && report.tenYearComparison.isNotEmpty) ...[
          Text('10-Year Annual Trend Lookback', style: AppTextStyles.h3),
          SizedBox(height: AppSpacing.sm.h),
          AppCard(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Income', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Net Savings', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Udhar Lent', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Udhar Recovered', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: report.tenYearComparison.map((y) {
                  return DataRow(
                    cells: [
                      DataCell(Text('${y.year}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(currencyFmt.format(y.totalIncome))),
                      DataCell(Text(currencyFmt.format(y.totalExpense))),
                      DataCell(
                        Text(
                          currencyFmt.format(y.netSavings),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: y.netSavings >= 0 ? AppColors.credit : AppColors.debit,
                          ),
                        ),
                      ),
                      DataCell(Text(currencyFmt.format(y.udharLent))),
                      DataCell(Text(currencyFmt.format(y.udharCollected))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),
        ],

        // ── 6. Period PnL Breakdown Table ───────────────────────────────────
        if (report.pnlTrend.isNotEmpty && report.horizon != AnalyticsTimeHorizon.tenYear) ...[
          Text('Period Statement Breakdown', style: AppTextStyles.h3),
          SizedBox(height: AppSpacing.sm.h),
          AppCard(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: report.pnlTrend.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = report.pnlTrend[index];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.periodLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '+${currencyFmt.format(row.income)}',
                          style: const TextStyle(color: AppColors.credit),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '-${currencyFmt.format(row.expense)}',
                          style: const TextStyle(color: AppColors.debit),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${row.netProfit >= 0 ? '+' : ''}${currencyFmt.format(row.netProfit)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: row.netProfit >= 0 ? AppColors.credit : AppColors.debit,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );

    if (isWide) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 20.r, color: color),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
