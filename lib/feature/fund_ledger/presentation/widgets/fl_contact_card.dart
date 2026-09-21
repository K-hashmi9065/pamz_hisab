import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/fl_contact_providers.dart';

/// A list tile for a single Fund Ledger contact showing their summary metrics.
class FLContactCard extends StatelessWidget {
  const FLContactCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  final FLContactSummaryData summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final border = isDark ? AppColors.darkOutline : AppColors.outline;
    final isAvailable = summary.availableAmount >= 0;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
      child: InkWell(
        key: Key('fl_contact_card_${summary.contact.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
            border: Border.all(color: border, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(
                    width: 4.w,
                    color: isAvailable ? AppColors.credit : AppColors.debit,
                  ),
                  // Card content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.sm.h + 2.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contact identity row
                          Row(
                            children: [
                              _Avatar(name: summary.contact.name),
                              SizedBox(width: AppSpacing.sm.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      summary.contact.name,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      summary.contact.mobileNumber,
                                      style: AppTextStyles.caption.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: AppSpacing.sm.w),
                              // Available badge
                              _AvailableBadge(amount: summary.availableAmount),
                            ],
                          ),
                          SizedBox(height: AppSpacing.sm.h),
                          // Divider
                          Divider(
                            height: 1,
                            color: border,
                          ),
                          SizedBox(height: AppSpacing.sm.h),
                          // Metrics row
                          Row(
                            children: [
                              _MiniMetric(
                                label: 'Received',
                                amount: summary.totalReceived,
                                color: AppColors.credit,
                                icon: Icons.arrow_downward_rounded,
                              ),
                              _MiniMetric(
                                label: 'Utilized',
                                amount: summary.totalUtilized,
                                color: AppColors.info,
                                icon: Icons.shopping_bag_outlined,
                              ),
                              _MiniMetric(
                                label: 'Returned',
                                amount: summary.totalReturned,
                                color: AppColors.debit,
                                icon: Icons.arrow_upward_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 22.r,
      backgroundColor: AppColors.credit,
      child: Text(
        initial,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AvailableBadge extends StatelessWidget {
  const _AvailableBadge({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    final isPositive = amount >= 0;
    final color = isPositive ? AppColors.credit : AppColors.debit;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: 6.h,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
        border: Border.all(color: color.withAlpha(80), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.formatCompact(amount.abs()),
            style: AppTextStyles.amountSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13.sp,
            ),
          ),
          Text(
            isPositive ? 'Available' : 'Excess',
            style: AppTextStyles.caption.copyWith(
              color: color.withAlpha(160),
              fontSize: 9.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 2.h, right: 6.w),
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Icon(icon, size: 12.r, color: color),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 10.sp,
                  ),
                ),
                Text(
                  CurrencyFormatter.formatCompact(amount),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
