import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Custom app bar with optional actions and back button.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBack = false,
    this.subtitle,
    this.bottom,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final String? subtitle;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final baseHeight = subtitle != null ? 64.h : kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(baseHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h2),
                Text(subtitle!, style: AppTextStyles.caption),
              ],
            )
          : Text(title, style: AppTextStyles.h2),
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : leading,
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Section header with title and optional trailing widget.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding,
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.sm.h,
          ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.label,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Themed snackbar factory.
abstract final class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: isError ? AppColors.debit : AppColors.credit,
                size: AppSpacing.iconMd.w,
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(child: Text(message)),
            ],
          ),
          duration: duration,
          action: action,
        ),
      );
  }

  static void showError(BuildContext context, String message) =>
      show(context, message: message, isError: true);

  static void showSuccess(BuildContext context, String message) =>
      show(context, message: message);

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: AppSpacing.iconMd.w,
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(child: Text(message)),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
