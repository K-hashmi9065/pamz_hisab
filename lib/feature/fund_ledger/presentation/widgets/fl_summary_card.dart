import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';

/// A compact summary metric card for the Fund Ledger.
/// Shows a label, formatted amount, and optional subtitle.
class FLSummaryCard extends StatelessWidget {
  const FLSummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final border = isDark ? AppColors.darkOutline : AppColors.outline;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
            border: Border.all(color: border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + label row
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs.w),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm.r),
                    ),
                    child: Icon(icon, size: 16.w, color: color),
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),
              // Amount
              Text(
                CurrencyFormatter.formatIndian(amount),
                style: AppTextStyles.h2.copyWith(
                  color: color,
                  fontSize: 18.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textDisabled,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
