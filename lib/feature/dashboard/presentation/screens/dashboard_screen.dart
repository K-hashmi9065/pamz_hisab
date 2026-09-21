import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../analytics_reports/presentation/providers/analytics_providers.dart';
import '../../../direct_udhar/presentation/widgets/direct_udhar_form_sheet.dart';
import '../../../family_finance/presentation/providers/family_finance_providers.dart';
import '../../../family_finance/presentation/widgets/transaction_form_sheet.dart';

/// Dashboard screen — home screen of PAMZ Hisab.
/// Shows responsive summary metric cards, quick action buttons, and recent activity feed.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSummaryCards(context, ref),
                SizedBox(height: AppSpacing.xl.h),
                _buildQuickActions(context),
                SizedBox(height: AppSpacing.xl.h),
                const SectionHeader(title: 'Recent Activity'),
                SizedBox(height: AppSpacing.sm.h),
                _buildRecentActivity(context, ref),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return SliverAppBar(
      expandedHeight: 120.h,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          left: AppSpacing.lg.w,
          bottom: AppSpacing.md.h,
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting • ${AppDateUtils.toDisplay(now)}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.8),
                fontSize: 11.sp,
              ),
            ),
            Text(
              'PAMZ Hisab',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthlyExpenseAsync = ref.watch(currentMonthExpenseProvider);
    final monthlyIncomeAsync = ref.watch(currentMonthIncomeProvider);
    final reportAsync = ref.watch(analyticsReportProvider);

    final expenseVal = monthlyExpenseAsync.valueOrNull ?? 0.0;
    final incomeVal = monthlyIncomeAsync.valueOrNull ?? 0.0;
    final netSavings = incomeVal - expenseVal;
    final report = reportAsync.valueOrNull;
    final udharLent = report?.summary.totalUdharLent ?? 0.0;
    final udharCollected = report?.summary.totalUdharCollected ?? 0.0;
    final netUdharReceivable = report?.summary.netUdharReceivable ?? (udharLent - udharCollected);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppConstants.tabletBreakpoint;
        final crossAxisCount = isWide ? 4 : 2;
        final childAspectRatio = isWide ? 1.45 : 1.35;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md.w,
          mainAxisSpacing: AppSpacing.md.h,
          childAspectRatio: childAspectRatio,
          children: [
            _SummaryCard(
              title: 'Total Income',
              subtitle: 'This month',
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.credit,
              valueColor: AppColors.credit,
              asyncValue: incomeVal,
            ),
            _SummaryCard(
              title: 'Total Expense',
              subtitle: 'This month',
              icon: Icons.trending_down_rounded,
              iconColor: AppColors.debit,
              valueColor: AppColors.debit,
              asyncValue: expenseVal,
            ),
            _SummaryCard(
              title: 'Net Savings',
              subtitle: AppDateUtils.toMonthYear(now),
              icon: Icons.account_balance_wallet_rounded,
              iconColor: netSavings >= 0 ? AppColors.credit : AppColors.debit,
              valueColor: netSavings >= 0 ? AppColors.credit : AppColors.debit,
              asyncValue: netSavings,
            ),
            _SummaryCard(
              title: 'Udhar Lent / Recovered',
              subtitle: 'Net Rec: ${CurrencyFormatter.formatIndian(netUdharReceivable)}',
              customValueWidget: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: CurrencyFormatter.formatIndian(udharLent),
                      style: AppTextStyles.amountLarge.copyWith(
                        color: AppColors.debit,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' / ',
                      style: AppTextStyles.amountLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: CurrencyFormatter.formatIndian(udharCollected),
                      style: AppTextStyles.amountLarge.copyWith(
                        color: AppColors.credit,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              icon: Icons.handshake_outlined,
              iconColor: AppColors.primary,
              valueColor: AppColors.primary,
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: AppButton(
                label: '+ New Udhar',
                icon: Icons.handshake_outlined,
                isFullWidth: true,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const DirectUdharFormSheet(),
                  );
                },
              ),
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: AppButton(
                label: '+ Expense',
                icon: Icons.receipt_long_outlined,
                variant: AppButtonVariant.secondary,
                isFullWidth: true,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const TransactionFormSheet(initialType: 'expense'),
                  );
                },
              ),
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: AppButton(
                label: '+ Income',
                icon: Icons.add_circle_outline_rounded,
                variant: AppButtonVariant.secondary,
                isFullWidth: true,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const TransactionFormSheet(initialType: 'income'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivity(BuildContext context, WidgetRef ref) {
    final recentTxnsAsync = ref.watch(allTransactionsProvider);

    return recentTxnsAsync.when(
      loading: () => const AppLoader(message: 'Loading recent transactions...'),
      error: (err, _) => AppErrorView(
        message: err.toString(),
        onRetry: () => ref.invalidate(allTransactionsProvider),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return AppEmptyState(
            title: 'No recent activity',
            subtitle: 'Record your first income, expense, or Udhar loan above',
            icon: Icons.receipt_outlined,
            actionLabel: 'Add Expense',
            onAction: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const TransactionFormSheet(initialType: 'expense'),
              );
            },
          );
        }

        final recentList = transactions.take(5).toList();
        final currencyFormat = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );

        return AppCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentList.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Theme.of(context).dividerColor,
              indent: AppSpacing.lg.w + 40.w,
            ),
            itemBuilder: (context, index) {
              final txn = recentList[index];
              final isIncome = txn.isIncome;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isIncome
                      ? AppColors.creditLight
                      : AppColors.debitLight,
                  child: Text(
                    txn.categoryIcon ?? (isIncome ? '💰' : '🛒'),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                title: Text(
                  txn.categoryName ?? (isIncome ? 'Income' : 'Expense'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                    DateFormat('dd MMM yyyy').format(txn.transactionDate),
                    if (txn.accountName != null) txn.accountName,
                    if (txn.notes != null && txn.notes!.isNotEmpty) txn.notes,
                  ].whereType<String>().join(' • '),
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${isIncome ? '+' : '-'}${currencyFormat.format(txn.amount)}',
                  style: AppTextStyles.amount.copyWith(
                    fontSize: 15.sp,
                    color: isIncome ? AppColors.credit : AppColors.debit,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Summary card widget for dashboard metrics.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
    this.asyncValue,
    this.customValueWidget,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color valueColor;
  final double? asyncValue;
  final Widget? customValueWidget;

  @override
  Widget build(BuildContext context) {
    final amount = asyncValue ?? 0.0;
    final display = CurrencyFormatter.formatIndian(amount);

    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm.w),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
                ),
                child: Icon(icon, size: 28.r, color: iconColor),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: customValueWidget ??
                Text(
                  display,
                  style: AppTextStyles.amountLarge.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          ),
          SizedBox(height: 2.h),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12.sp,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
