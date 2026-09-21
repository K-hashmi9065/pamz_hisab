import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../providers/family_finance_providers.dart';

/// Financial summary cards for the Family Finance tab.
/// Displays Total Income, Total Expense, and Net Balance with responsive layout.
class FamilyFinanceSummaryCards extends ConsumerWidget {
  const FamilyFinanceSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(familyFinanceSummaryProvider);
    final summary = summaryAsync.valueOrNull ?? FamilyFinanceSummary.empty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        final incomeCard = _SummaryMetricCard(
          title: 'Total Income',
          amount: summary.totalIncome,
          icon: Icons.trending_up_rounded,
          color: AppColors.credit,
        );

        final expenseCard = _SummaryMetricCard(
          title: 'Total Expense',
          amount: summary.totalExpense,
          icon: Icons.trending_down_rounded,
          color: AppColors.debit,
        );

        final isNetPositive = summary.netBalance >= 0;
        final netColor = isNetPositive ? AppColors.credit : AppColors.debit;

        final netCard = _SummaryMetricCard(
          title: 'Net Balance',
          amount: summary.netBalance,
          icon: Icons.account_balance_wallet_rounded,
          color: netColor,
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: incomeCard),
              SizedBox(width: AppSpacing.md.w),
              Expanded(child: expenseCard),
              SizedBox(width: AppSpacing.md.w),
              Expanded(child: netCard),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: incomeCard),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(child: expenseCard),
              ],
            ),
            SizedBox(height: AppSpacing.sm.h),
            netCard,
          ],
        );
      },
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedAmount = CurrencyFormatter.formatIndian(amount);

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.md.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.xs.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
                ),
                child: Icon(icon, size: AppSpacing.iconMd.w, color: color),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formattedAmount,
              style: AppTextStyles.amountLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
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
