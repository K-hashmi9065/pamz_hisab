import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/fl_transaction.dart';

/// Clean transaction list tile displaying a single Fund Ledger transaction.
class FLTransactionTile extends StatelessWidget {
  const FLTransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  final FLTransaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (icon, iconColor, bgColor, prefix, amountColor) =
        switch (transaction.type) {
      FLTransactionType.received => (
          Icons.arrow_downward_rounded,
          AppColors.credit,
          AppColors.creditLight.withAlpha(isDark ? 30 : 255),
          '+',
          AppColors.credit,
        ),
      FLTransactionType.utilized => (
          Icons.shopping_bag_outlined,
          AppColors.info,
          isDark ? AppColors.darkSurfaceVariant : const Color(0xFFE3F2FD),
          '-',
          AppColors.info,
        ),
      FLTransactionType.returned => (
          Icons.arrow_upward_rounded,
          AppColors.debit,
          AppColors.debitLight.withAlpha(isDark ? 30 : 255),
          '-',
          AppColors.debit,
        ),
    };

    final titleText = switch (transaction.type) {
      FLTransactionType.received => 'Fund Received',
      FLTransactionType.utilized => transaction.title?.isNotEmpty == true
          ? transaction.title!
          : 'Fund Utilized',
      FLTransactionType.returned => 'Fund Returned',
    };

    final subtitleParts = <String>[];
    subtitleParts.add(transaction.txnDate);
    if (transaction.txnTime != null && transaction.txnTime!.isNotEmpty) {
      subtitleParts.add(transaction.txnTime!);
    }
    if (transaction.paymentMode != null &&
        transaction.paymentMode!.isNotEmpty) {
      subtitleParts.add(transaction.paymentMode!);
    }
    if (transaction.paymentReference != null &&
        transaction.paymentReference!.isNotEmpty) {
      subtitleParts.add('Ref: ${transaction.paymentReference}');
    }

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: 4.h,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        side: BorderSide(
          color: isDark ? AppColors.darkOutline : AppColors.outline,
          width: 0.8,
        ),
      ),
      color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.sm.r),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 42.r,
                height: 42.r,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22.r,
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleText,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Amount
                        Text(
                          '$prefix${CurrencyFormatter.formatIndian(transaction.amount)}',
                          style: AppTextStyles.amountSmall.copyWith(
                            color: amountColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitleParts.join(' • '),
                            style: AppTextStyles.caption.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onDelete != null)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18.r,
                              color: AppColors.textDisabled,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onDelete,
                          ),
                      ],
                    ),
                    if (transaction.note?.isNotEmpty == true) ...[
                      SizedBox(height: 2.h),
                      Text(
                        transaction.note!,
                        style: AppTextStyles.caption.copyWith(
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
