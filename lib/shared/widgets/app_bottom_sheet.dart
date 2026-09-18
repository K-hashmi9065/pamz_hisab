import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_colors.dart';

/// Shared utility for showing themed bottom sheets.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: EdgeInsets.only(top: AppSpacing.sm.h, bottom: AppSpacing.md.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill.r),
              ),
            ),
          ),
          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
            child: Text(title, style: AppTextStyles.h2),
          ),
          SizedBox(height: AppSpacing.lg.h),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: child,
            ),
          ),
          // Actions
          if (actions != null) ...[
            SizedBox(height: AppSpacing.lg.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ),
          ],
          SizedBox(height: AppSpacing.xl.h),
        ],
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      builder: (_) => AppBottomSheet(
        title: title,
        actions: actions,
        child: child,
      ),
    );
  }
}
