import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/category_budget.dart';
import '../providers/budget_providers.dart';
import '../providers/family_finance_providers.dart';

class BudgetFormSheet extends ConsumerStatefulWidget {
  const BudgetFormSheet({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.existingBudget,
  });

  final int? initialYear;
  final int? initialMonth;
  final CategoryBudget? existingBudget;

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _limitCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();

  String? _selectedCategoryId;
  late int _selectedYear;
  late int _selectedMonth;

  bool get _isEditing => widget.existingBudget != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = widget.initialYear ?? now.year;
    _selectedMonth = widget.initialMonth ?? now.month;

    if (_isEditing) {
      final b = widget.existingBudget!;
      _selectedCategoryId = b.categoryId;
      _selectedYear = b.year;
      _selectedMonth = b.month;
      _limitCtrl.text = b.monthlyLimit.toStringAsFixed(
        b.monthlyLimit.truncateToDouble() == b.monthlyLimit ? 0 : 2,
      );
      _thresholdCtrl.text = b.thresholdPercentage.toStringAsFixed(0);
    } else {
      _thresholdCtrl.text = '80';
    }
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(budgetNotifierProvider);
    final isLoading = notifierState.isLoading;
    final expenseCategoriesAsync = ref.watch(categoriesProvider('expense'));

    final monthDate = DateTime(_selectedYear, _selectedMonth);
    final monthLabel = DateFormat('MMMM yyyy').format(monthDate);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= AppConstants.tabletBreakpoint;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWide ? 600 : double.infinity,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) => Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusXl.r),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isEditing ? 'Edit Category Budget' : 'Set Category Budget',
                            style: AppTextStyles.h2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(AppSpacing.lg.w),
                  children: [
                    // Month Banner
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.sm.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 20.r,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Budget for: $monthLabel',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg.h),

                    // Category Dropdown (Expenses Only)
                    expenseCategoriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error loading categories: $err'),
                      data: (categories) {
                        final validCategory = categories.any(
                          (c) => c.id == _selectedCategoryId,
                        );
                        if (!validCategory && categories.isNotEmpty && _selectedCategoryId == null) {
                          _selectedCategoryId = categories.first.id;
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Expense Category',
                            prefixIcon: Icon(Icons.shopping_bag_outlined),
                          ),
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat.id,
                              child: Row(
                                children: [
                                  if (cat.iconKey != null) ...[
                                    Text(cat.iconKey!,
                                        style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(cat.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _isEditing
                              ? null // Category is locked during edit to maintain uniqueness
                              : (val) => setState(() => _selectedCategoryId = val),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Please select an expense category'
                              : null,
                        );
                      },
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Monthly Limit
                    AppTextField.currency(
                      label: 'Monthly Limit (₹)',
                      hint: 'e.g. 5000',
                      controller: _limitCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter monthly limit';
                        }
                        final num = double.tryParse(v.trim());
                        if (num == null || num <= 0) {
                          return 'Enter a valid amount greater than 0';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Alert Threshold Percentage
                    AppTextField(
                      label: 'Alert Threshold (%)',
                      hint: 'e.g. 80',
                      controller: _thresholdCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefix: const Icon(Icons.notifications_active_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter threshold percentage';
                        }
                        final num = double.tryParse(v.trim());
                        if (num == null || num <= 0 || num > 100) {
                          return 'Enter a percentage between 1 and 100';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                    ),
                    SizedBox(height: AppSpacing.sm.h),

                    // Quick Threshold Chips
                    Wrap(
                      spacing: 8.w,
                      children: [50, 75, 80, 90, 100].map((percent) {
                        return ActionChip(
                          label: Text('$percent%'),
                          onPressed: () {
                            setState(() => _thresholdCtrl.text = '$percent');
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: AppSpacing.xxl.h),

                    // Save / Update Button
                    AppButton(
                      label: _isEditing ? 'Update Budget' : 'Save Budget',
                      isLoading: isLoading,
                      isFullWidth: true,
                      icon: Icons.check_rounded,
                      onPressed: isLoading ? null : _submit,
                    ),

                    if (notifierState.hasError)
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm.h),
                        child: Text(
                          notifierState.error.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    final limit = double.tryParse(_limitCtrl.text.trim()) ?? 0.0;
    final threshold = double.tryParse(_thresholdCtrl.text.trim()) ?? 80.0;
    final now = DateTime.now();

    final notifier = ref.read(budgetNotifierProvider.notifier);
    final bool success;

    if (_isEditing) {
      final updated = widget.existingBudget!.copyWith(
        monthlyLimit: limit,
        thresholdPercentage: threshold,
        updatedAt: now,
      );
      success = await notifier.updateBudget(updated);
    } else {
      final budget = CategoryBudget(
        id: '',
        categoryId: _selectedCategoryId!,
        monthlyLimit: limit,
        thresholdPercentage: threshold,
        year: _selectedYear,
        month: _selectedMonth,
        createdAt: now,
        updatedAt: now,
      );
      success = await notifier.createBudget(budget);
    }

    if (success && mounted) {
      Navigator.pop(context);
      AppSnackbar.showSuccess(
        context,
        _isEditing
            ? 'Budget updated successfully'
            : 'Budget configured successfully',
      );
    }
  }
}
