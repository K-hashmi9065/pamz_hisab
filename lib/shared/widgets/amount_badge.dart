import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';

/// Colored credit/debit pill badge with +/- prefix and icon.
/// Never encodes meaning by color alone (accessibility: always includes +/- prefix).
class AmountBadge extends StatelessWidget {
  const AmountBadge({
    super.key,
    required this.amount,
    required this.isCredit,
    this.compact = false,
  });

  final double amount;
  final bool isCredit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = isDark
        ? (isCredit ? const Color(0xFF81C784) : const Color(0xFFE57373))
        : (isCredit ? AppColors.credit : AppColors.debit);
    final badgeBg = isDark
        ? (isCredit ? const Color(0xFF1B3A1E) : const Color(0xFF3A1818))
        : (isCredit ? AppColors.creditLight : AppColors.debitLight);

    final formatted = CurrencyFormatter.formatIndian(amount);
    final formattedAmount = isCredit ? '+$formatted' : '-$formatted';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: AppSpacing.xs.h,
      ),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill.r),
        border: Border.all(color: badgeColor.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: AppSpacing.iconSm.w,
            color: badgeColor,
            semanticLabel: isCredit ? 'Receivable' : 'Payable',
          ),
          SizedBox(width: 2.w),
          Text(
            formattedAmount,
            style: AppTextStyles.amountSmall.copyWith(color: badgeColor),
          ),
        ],
      ),
    );
  }
}
