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
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../domain/entities/category_budget.dart';
import '../providers/budget_providers.dart';
import '../widgets/budget_form_sheet.dart';

/// Budget Tracking Screen (FR-FE-003) — Monitor category spending against limits.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  void _openAddBudgetSheet(BuildContext context, DateTime selectedMonth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BudgetFormSheet(
        initialYear: selectedMonth.year,
        initialMonth: selectedMonth.month,
      ),
    );
  }

  void _openEditBudgetSheet(BuildContext context, CategoryBudget budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BudgetFormSheet(
        existingBudget: budget,
        initialYear: budget.year,
        initialMonth: budget.month,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedBudgetMonthProvider);
    final calculationsAsync = ref.watch(activeBudgetCalculationsProvider);

    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final isWide = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Budget Tracking',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Budget',
            onPressed: () => _openAddBudgetSheet(context, selectedMonth),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Month Navigation Selector ──────────────────────────────
          _MonthSelector(
            selectedMonth: selectedMonth,
            onMonthChanged: (newMonth) {
              ref.read(selectedBudgetMonthProvider.notifier).state = newMonth;
            },
          ),

          // ─── Budget Content Area ────────────────────────────────────
          Expanded(
            child: calculationsAsync.when(
              loading: () => const AppLoader(message: 'Loading budgets...'),
              error: (e, _) => AppErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(activeBudgetCalculationsProvider),
              ),
              data: (calculations) {
                if (calculations.isEmpty) {
                  return AppEmptyState(
                    title: 'No category budgets set',
                    subtitle:
                        'Set monthly limits for expense categories in ${DateFormat('MMMM yyyy').format(selectedMonth)} to monitor spending and get threshold alerts.',
                    icon: Icons.track_changes_rounded,
                    actionLabel: 'Set Category Budget',
                    onAction: () => _openAddBudgetSheet(context, selectedMonth),
                  );
                }

                // Calculate month totals across all budgets
                final totalLimit = calculations.fold<double>(
                  0.0,
                  (sum, c) => sum + c.budget.monthlyLimit,
                );
                final totalSpent = calculations.fold<double>(
                  0.0,
                  (sum, c) => sum + c.actualExpense,
                );
                final totalRemaining = totalLimit - totalSpent;
                final overallUsage =
                    totalLimit > 0 ? (totalSpent / totalLimit) * 100 : 0.0;

                final content = ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w,
                    vertical: AppSpacing.sm.h,
                  ),
                  children: [
                    // ─── Overview Summary Card ────────────────────────
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Monthly Budget Overview',
                                style: AppTextStyles.h3,
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: overallUsage > 100
                                      ? AppColors.debitLight
                                      : (overallUsage >= 80
                                          ? AppColors.warningLight
                                          : AppColors.creditLight),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      overallUsage > 100
                                          ? Icons.error_outline_rounded
                                          : (overallUsage >= 80
                                              ? Icons.warning_amber_rounded
                                              : Icons.check_circle_outline_rounded),
                                      size: 14.r,
                                      color: overallUsage > 100
                                          ? AppColors.debit
                                          : (overallUsage >= 80
                                              ? AppColors.warning
                                              : AppColors.credit),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '${overallUsage.toStringAsFixed(0)}% Used',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: overallUsage > 100
                                            ? AppColors.debit
                                            : (overallUsage >= 80
                                                ? AppColors.warning
                                                : AppColors.credit),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.md.h),

                          Row(
                            children: [
                              Expanded(
                                child: _OverviewMetric(
                                  label: 'Total Budget',
                                  value: currencyFormat.format(totalLimit),
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: AppSpacing.sm.w),
                              Expanded(
                                child: _OverviewMetric(
                                  label: 'Total Spent',
                                  value: currencyFormat.format(totalSpent),
                                  color: totalSpent > totalLimit
                                      ? AppColors.debit
                                      : AppColors.primary,
                                ),
                              ),
                              SizedBox(width: AppSpacing.sm.w),
                              Expanded(
                                child: _OverviewMetric(
                                  label: totalRemaining >= 0 ? 'Remaining' : 'Over Budget',
                                  value: currencyFormat.format(totalRemaining.abs()),
                                  color: totalRemaining >= 0
                                      ? AppColors.credit
                                      : AppColors.debit,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.md.h),

                          // Overall Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6.r),
                            child: LinearProgressIndicator(
                              value: (overallUsage / 100).clamp(0.0, 1.0),
                              minHeight: 8.h,
                              backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                overallUsage > 100
                                    ? AppColors.debit
                                    : (overallUsage >= 80
                                        ? AppColors.warning
                                        : AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg.h),

                    Text(
                      'Category Budgets',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),

                    // ─── List of Category Budgets ─────────────────────
                    ...calculations.map((calc) {
                      return _CategoryBudgetCard(
                        calculation: calc,
                        currencyFormat: currencyFormat,
                        onEdit: () => _openEditBudgetSheet(context, calc.budget),
                        onDelete: () async {
                          final confirmed = await ConfirmationDialog.show(
                            context: context,
                            title: 'Delete Budget',
                            message:
                                'Are you sure you want to delete the budget for "${calc.budget.categoryName ?? 'Category'}" in ${calc.budget.monthKey}?',
                            confirmLabel: 'Delete',
                            isDestructive: true,
                          );
                          if (confirmed == true) {
                            final success = await ref
                                .read(budgetNotifierProvider.notifier)
                                .deleteBudget(calc.budget.id);
                            if (success && context.mounted) {
                              AppSnackbar.showSuccess(
                                context,
                                'Budget removed successfully',
                              );
                            }
                          }
                        },
                      );
                    }),
                    SizedBox(height: 80.h),
                  ],
                );

                if (isWide) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: content,
                    ),
                  );
                }

                return content;
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddBudgetSheet(context, selectedMonth),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Budget'),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(selectedMonth);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous Month',
            onPressed: () {
              onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month - 1));
            },
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                onMonthChanged(DateTime(picked.year, picked.month));
              }
            },
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18.r, color: AppColors.primary),
                  SizedBox(width: 6.w),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next Month',
            onPressed: () {
              onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month + 1));
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2.h),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  const _CategoryBudgetCard({
    required this.calculation,
    required this.currencyFormat,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetCalculation calculation;
  final NumberFormat currencyFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final b = calculation.budget;
    final spent = calculation.actualExpense;
    final limit = b.monthlyLimit;
    final remaining = calculation.remainingAmount;
    final usagePercent = calculation.usagePercentage;
    final isExceeded = calculation.isExceeded;
    final isThreshold = calculation.isThresholdReached;

    final progressColor = isExceeded
        ? AppColors.debit
        : (isThreshold ? AppColors.warning : AppColors.primary);

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon, Name, Limit, Options
            Row(
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: AppColors.debitLight,
                  child: Text(
                    b.categoryIcon ?? '🏷️',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.categoryName ?? 'Expense Category',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Limit: ${currencyFormat.format(limit)} (Alert at ${b.thresholdPercentage.toStringAsFixed(0)}%)',
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Budget',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Delete Budget',
                  onPressed: onDelete,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md.h),

            // Spending breakdown row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: currencyFormat.format(spent),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.sp,
                            color: progressColor,
                          ),
                        ),
                        TextSpan(
                          text: ' spent',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isExceeded
                        ? 'Over by ${currencyFormat.format(remaining.abs())}'
                        : '${currencyFormat.format(remaining)} left',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isExceeded ? AppColors.debit : AppColors.credit,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs.h),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: (usagePercent / 100).clamp(0.0, 1.0),
                minHeight: 6.h,
                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),

            // Alert Status Banner (Threshold / Exceeded)
            if (isExceeded || isThreshold)
              Container(
                margin: EdgeInsets.only(top: 4.h),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isExceeded
                      ? AppColors.debitLight
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExceeded
                          ? Icons.error_outline_rounded
                          : Icons.warning_amber_rounded,
                      size: 14.r,
                      color: isExceeded ? AppColors.debit : AppColors.warning,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        isExceeded
                            ? 'Limit exceeded! Spending is at ${usagePercent.toStringAsFixed(0)}%.'
                            : 'Spending alert: ${usagePercent.toStringAsFixed(0)}% reached (Threshold: ${b.thresholdPercentage.toStringAsFixed(0)}%).',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: isExceeded
                              ? AppColors.debit
                              : AppColors.warning,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
