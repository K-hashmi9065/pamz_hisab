import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';

/// Category Configuration Screen — previously used by Family Finance feature.
///
/// NOTE: The Family Finance category system has been retired. This screen now
/// shows an informational placeholder. Transaction categories are no longer
/// configurable in this version of the app.
class CategoryConfigScreen extends ConsumerStatefulWidget {
  const CategoryConfigScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<CategoryConfigScreen> createState() =>
      _CategoryConfigScreenState();
}

class _CategoryConfigScreenState extends ConsumerState<CategoryConfigScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Categories'),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category_outlined,
                size: 64.w,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              SizedBox(height: 16.h),
              Text(
                'Category Management',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'The category management system has been retired.\n'
                'Financial records are now managed through the Fund Ledger feature.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
