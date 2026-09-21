import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Reusable payment mode selector widget with predefined choices: Cash, UPI, Cheque, Draft.
class FLPaymentModeField extends StatelessWidget {
  const FLPaymentModeField({
    super.key,
    required this.selectedMode,
    required this.onChanged,
    this.modes = const ['Cash', 'UPI', 'Cheque', 'Draft'],
  });

  final String? selectedMode;
  final ValueChanged<String> onChanged;
  final List<String> modes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Mode',
          style: AppTextStyles.label.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 6.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: modes.map((mode) {
            final isSelected = selectedMode?.toLowerCase() == mode.toLowerCase();
            return ChoiceChip(
              label: Text(
                mode,
                style: AppTextStyles.captionBold.copyWith(
                  color: isSelected
                      ? Colors.white
                      : isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.surfaceVariant,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : isDark
                        ? AppColors.darkOutline
                        : AppColors.outline,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w,
                vertical: 4.h,
              ),
              onSelected: (_) => onChanged(mode),
            );
          }).toList(),
        ),
      ],
    );
  }
}
