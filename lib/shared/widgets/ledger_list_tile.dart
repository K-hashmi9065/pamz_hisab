import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_date_utils.dart';
import 'amount_badge.dart';

/// Ledger list tile for buyer/supplier contact rows.
/// Shows: avatar-initials, name, mobile, AmountBadge, overdue chip.
class LedgerListTile extends StatelessWidget {
  const LedgerListTile({
    super.key,
    required this.name,
    required this.amount,
    required this.isCredit,
    this.mobile,
    this.dueDate,
    this.subtitle,
    this.onTap,
    this.onLongPress,
  });

  final String name;
  final double amount;
  final bool isCredit;
  final String? mobile;
  final DateTime? dueDate;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  bool get isOverdue =>
      dueDate != null && AppDateUtils.isOverdue(dueDate!) && !isCredit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: _buildAvatar(context),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          AmountBadge(amount: amount, isCredit: isCredit, compact: true),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mobile != null || subtitle != null)
            Text(
              mobile ?? subtitle ?? '',
              style: AppTextStyles.caption,
            ),
          if (isOverdue) _buildOverdueChip(),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    final bg = isDark
        ? (isCredit ? const Color(0xFF1B3A1E) : const Color(0xFF3A1818))
        : (isCredit ? AppColors.creditLight : AppColors.debitLight);
    final textColor = isDark
        ? (isCredit ? const Color(0xFF81C784) : const Color(0xFFE57373))
        : (isCredit ? AppColors.creditText : AppColors.debitText);

    return CircleAvatar(
      radius: 22.r,
      backgroundColor: bg,
      child: Text(
        initials,
        style: AppTextStyles.h3.copyWith(
          color: textColor,
          fontSize: 13.sp,
        ),
      ),
    );
  }

  Widget _buildOverdueChip() {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: AppSpacing.iconSm.w,
            color: AppColors.warning,
            semanticLabel: 'Overdue',
          ),
          SizedBox(width: 3.w),
          Text(
            'Overdue ${dueDate != null ? AppDateUtils.toRelativeDisplay(dueDate!) : ''}',
            style: AppTextStyles.caption.copyWith(color: AppColors.warningText),
          ),
        ],
      ),
    );
  }
}
