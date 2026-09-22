import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/fl_contact_providers.dart';
import 'fl_receive_form.dart';
import 'fl_return_form.dart';
import 'fl_utilize_form.dart';

/// Prominent header card for Contact Detail screen showing balance and quick action buttons.
class FLContactDetailHeader extends ConsumerWidget {
  const FLContactDetailHeader({
    super.key,
    required this.contactId,
  });

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(flContactSummaryProvider(contactId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return summaryAsync.when(
      loading: () => Container(
        height: 200.h,
        margin: EdgeInsets.all(AppSpacing.md.r),
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Container(
        margin: EdgeInsets.all(AppSpacing.md.r),
        padding: EdgeInsets.all(AppSpacing.md.r),
        child: Text('Error loading summary: $e',
            style: AppTextStyles.body.copyWith(color: AppColors.error)),
      ),
      data: (summary) {
        if (summary == null) return const SizedBox.shrink();

        final available = summary.availableAmount;
        final isPositive = available >= 0;

        return Card(
          margin: EdgeInsets.all(AppSpacing.md.r),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
            side: BorderSide(
              color: isDark ? AppColors.darkOutline : AppColors.outline,
              width: 1,
            ),
          ),
          color:
              isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Available Balance Headline
                Text(
                  'AVAILABLE FUND RESPONSIBILITY',
                  style: AppTextStyles.label.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Text(
                      CurrencyFormatter.formatIndian(available),
                      style: AppTextStyles.display.copyWith(
                        color: isPositive ? AppColors.credit : AppColors.debit,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  'Available = Received - Returned',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                const Divider(height: 1),
                SizedBox(height: AppSpacing.md.h),

                // 3-Column Metrics: Received, Utilized, Returned
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricColumn(
                      label: 'Received',
                      amount: summary.totalReceived,
                      color: AppColors.credit,
                      isDark: isDark,
                    ),
                    _metricColumn(
                      label: 'Utilized',
                      amount: summary.totalUtilized,
                      color: AppColors.info,
                      isDark: isDark,
                    ),
                    _metricColumn(
                      label: 'Returned',
                      amount: summary.totalReturned,
                      color: AppColors.debit,
                      isDark: isDark,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg.h),

                // Action Buttons (Receive, Utilize, Return)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon:
                            const Icon(Icons.arrow_downward_rounded, size: 16),
                        label: const Text('Receive'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.credit,
                          minimumSize: const Size(0, 52),
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                        ),
                        onPressed: () => FLReceiveForm.show(
                          context,
                          contactId: contactId,
                          onSuccess: () => ref
                              .invalidate(flContactSummaryProvider(contactId)),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                        label: const Text('Utilize'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.info,
                          foregroundColor: AppColors.onPrimary,
                          minimumSize: const Size(0, 52),
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                        ),
                        onPressed: () => FLUtilizeForm.show(
                          context,
                          contactId: contactId,
                          onSuccess: () => ref
                              .invalidate(flContactSummaryProvider(contactId)),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                        label: const Text('Return'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.debit,
                          minimumSize: const Size(0, 52),
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                        ),
                        onPressed: () => FLReturnForm.show(
                          context,
                          contactId: contactId,
                          onSuccess: () => ref
                              .invalidate(flContactSummaryProvider(contactId)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricColumn({
    required String label,
    required double amount,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.captionBold.copyWith(
            color:
                isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          CurrencyFormatter.formatIndian(amount),
          style: AppTextStyles.amountSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
