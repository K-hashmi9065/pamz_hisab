import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/family_utilize.dart';
import '../providers/family_utilize_providers.dart';
import 'add_family_utilize_sheet.dart';

/// Card widget to display a single Family Utilization transaction.
class FamilyUtilizeTile extends ConsumerWidget {
  const FamilyUtilizeTile({
    super.key,
    required this.item,
  });

  final FamilyUtilize item;

  String? _formatPaymentInfo(String? mode, String? ref) {
    if (mode == null || mode.trim().isEmpty) return null;
    final cleanMode = mode.trim();
    if (cleanMode.toLowerCase() == 'cash') {
      return 'Cash';
    }
    if (ref != null && ref.trim().isNotEmpty) {
      final cleanRef = ref.trim();
      return switch (cleanMode.toLowerCase()) {
        'upi' => 'UPI • UTR: $cleanRef',
        'cheque' => 'Cheque • No: $cleanRef',
        'draft' => 'Draft • No: $cleanRef',
        _ => '$cleanMode • Ref: $cleanRef',
      };
    }
    return cleanMode;
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Utilization'),
        content: Text(
          'Are you sure you want to delete "${item.title}" for ${CurrencyFormatter.formatIndian(item.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.debit),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(familyUtilizeListNotifierProvider.notifier)
          .delete(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Utilization deleted'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preset = FamilyUtilize.getCategoryPreset(item.category);
    final dateObj =
        AppDateUtils.parseIso(item.transactionDate) ?? item.createdAt;
    final paymentInfo =
        _formatPaymentInfo(item.paymentMode, item.paymentReference);

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
        side: BorderSide(
          color: isDark ? AppColors.darkOutline : AppColors.outline,
          width: 0.8,
        ),
      ),
      color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon Badge
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: preset.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
              ),
              child: Icon(
                preset.icon,
                color: preset.color,
                size: 22.r,
              ),
            ),
            SizedBox(width: 12.w),

            // Content details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        CurrencyFormatter.formatIndian(item.amount),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),

                  // Category & Date row
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: preset.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          item.category,
                          style: AppTextStyles.caption.copyWith(
                            color: preset.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 10.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        AppDateUtils.toDisplay(dateObj),
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Payment Mode if available
                  if (paymentInfo != null) ...[
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          item.paymentMode?.toLowerCase() == 'cash'
                              ? Icons.money_rounded
                              : Icons.payment_rounded,
                          size: 13.r,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            paymentInfo,
                            style: AppTextStyles.caption.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Paid To if available
                  if (item.paidTo != null && item.paidTo!.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: 13.r,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Paid to: ${item.paidTo}',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Description if available
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      item.description!,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // More Options (Edit / Delete)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20.r,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              onSelected: (val) {
                if (val == 'edit') {
                  AddFamilyUtilizeSheet.show(context, item: item);
                } else if (val == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.debit),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.debit)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
