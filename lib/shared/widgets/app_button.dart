import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, destructive, ghost }

/// Standardized button component with primary / secondary / destructive / ghost variants.
/// Minimum tap target: 44x44pt (iOS HIG).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.minimumSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Size? minimumSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    final foregroundColor = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.destructive => AppColors.onPrimary,
      AppButtonVariant.secondary || AppButtonVariant.ghost => primaryColor,
    };

    final effectiveSize = minimumSize ??
        Size(isFullWidth ? double.infinity : 0, AppSpacing.minTapTarget.h);

    final child = isLoading
        ? SizedBox(
            width: 20.w,
            height: 20.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSpacing.iconMd.w, color: foregroundColor),
                SizedBox(width: AppSpacing.xs.w),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.button.copyWith(color: foregroundColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    return switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: effectiveSize,
            disabledBackgroundColor: colorScheme.primary.withAlpha(100),
          ),
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor, width: 1.5),
            minimumSize: effectiveSize,
          ),
          child: child,
        ),
      AppButtonVariant.destructive => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.debit,
            foregroundColor: AppColors.onPrimary,
            minimumSize: effectiveSize,
          ),
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            minimumSize: effectiveSize,
          ),
          child: child,
        ),
    };
  }
}
