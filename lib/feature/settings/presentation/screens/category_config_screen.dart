import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../family_finance/domain/entities/family_transaction.dart';
import '../../../family_finance/presentation/providers/family_finance_providers.dart';

/// Category Configuration Screen — Manage custom and system preset categories.
class CategoryConfigScreen extends ConsumerStatefulWidget {
  const CategoryConfigScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<CategoryConfigScreen> createState() =>
      _CategoryConfigScreenState();
}

class _CategoryConfigScreenState extends ConsumerState<CategoryConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddCategorySheet([String? forcedDomain]) {
    final domain = forcedDomain ?? (_tabController.index == 0 ? 'income' : 'expense');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryFormSheet(initialDomain: domain),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Manage Categories',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Category',
            onPressed: () => _openAddCategorySheet(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up_rounded), text: 'Income Categories'),
            Tab(icon: Icon(Icons.trending_down_rounded), text: 'Expense Categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CategoryListView(
            domain: 'income',
            onAddPressed: () => _openAddCategorySheet('income'),
          ),
          _CategoryListView(
            domain: 'expense',
            onAddPressed: () => _openAddCategorySheet('expense'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddCategorySheet(),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? 'Add Income Category' : 'Add Expense Category',
        ),
      ),
    );
  }
}

class _CategoryListView extends ConsumerWidget {
  const _CategoryListView({
    required this.domain,
    required this.onAddPressed,
  });

  final String domain;
  final VoidCallback onAddPressed;

  void _openEditCategorySheet(BuildContext context, TransactionCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryFormSheet(
        existingCategory: category,
        initialDomain: category.domain,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider(domain));
    final isIncome = domain == 'income';
    final isWide = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    return categoriesAsync.when(
      loading: () => const AppLoader(message: 'Loading categories...'),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(categoriesProvider(domain)),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return AppEmptyState(
            title: isIncome ? 'No income categories' : 'No expense categories',
            subtitle: 'Tap below to configure a new category',
            icon: isIncome ? Icons.category_rounded : Icons.shopping_bag_outlined,
            actionLabel: 'Add Category',
            onAction: onAddPressed,
          );
        }

        final list = ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          itemCount: categories.length,
          separatorBuilder: (_, __) => Divider(height: 1, indent: 64.w),
          itemBuilder: (context, index) {
            final cat = categories[index];
            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w,
                vertical: 4.h,
              ),
              leading: CircleAvatar(
                backgroundColor: isIncome ? AppColors.creditLight : AppColors.debitLight,
                child: Text(cat.iconKey ?? '🏷️', style: const TextStyle(fontSize: 20)),
              ),
              title: Text(
                cat.name,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                cat.isSystemPreset ? 'Default system category' : 'Custom user category',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              trailing: cat.isSystemPreset
                  ? Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'SYSTEM',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit Category',
                          onPressed: () => _openEditCategorySheet(context, cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          tooltip: 'Delete Category',
                          onPressed: () async {
                            final confirmed = await ConfirmationDialog.show(
                              context: context,
                              title: 'Delete Category',
                              message:
                                  'Are you sure you want to delete category "${cat.name}"?\n\nPast transactions will retain this category name.',
                              confirmLabel: 'Delete',
                              isDestructive: true,
                            );
                            if (confirmed == true) {
                              final success = await ref
                                  .read(categoryNotifierProvider.notifier)
                                  .deleteCategory(cat.id);
                              if (success && context.mounted) {
                                AppSnackbar.showSuccess(
                                  context,
                                  'Category deleted successfully',
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
            );
          },
        );

        if (isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: list,
            ),
          );
        }

        return list;
      },
    );
  }
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  const _CategoryFormSheet({
    this.initialDomain = 'income',
    this.existingCategory,
  });

  final String initialDomain;
  final TransactionCategory? existingCategory;

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _domain;
  final _nameCtrl = TextEditingController();
  String _selectedIcon = '🏷️';

  bool get _isEditing => widget.existingCategory != null;

  static const _availableIcons = [
    '💼', '🌾', '🏪', '🏠', '💸', '📈', '💰', '💳', '🚚', '🛠️',
    '🛒', '🌱', '📚', '🏥', '⚡', '🚗', '🍽️', '✈️', '🎁', '🏷️',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final cat = widget.existingCategory!;
      _domain = cat.domain;
      _nameCtrl.text = cat.name;
      _selectedIcon = cat.iconKey ?? '🏷️';
    } else {
      _domain = widget.initialDomain;
      _selectedIcon = _domain == 'income' ? '💼' : '🛒';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(categoryNotifierProvider);
    final isLoading = notifierState.isLoading;
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
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
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
                            _isEditing ? 'Edit Category' : 'Add Category',
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
                          if (!_isEditing) ...[
                            // Domain selector
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'income',
                                  label: Text('Income'),
                                  icon: Icon(Icons.trending_up_rounded),
                                ),
                                ButtonSegment(
                                  value: 'expense',
                                  label: Text('Expense'),
                                  icon: Icon(Icons.trending_down_rounded),
                                ),
                              ],
                              selected: {_domain},
                              onSelectionChanged: (v) {
                                setState(() {
                                  _domain = v.first;
                                  if (_domain == 'income' && _selectedIcon == '🛒') {
                                    _selectedIcon = '💼';
                                  } else if (_domain == 'expense' && _selectedIcon == '💼') {
                                    _selectedIcon = '🛒';
                                  }
                                });
                              },
                            ),
                            SizedBox(height: AppSpacing.lg.h),
                          ],

                          // Category Name input
                          AppTextField(
                            label: 'Category Name',
                            hint: 'e.g. Consultancy, Farming, Logistics',
                            controller: _nameCtrl,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter category name';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.done,
                          ),
                          SizedBox(height: AppSpacing.lg.h),

                          // Icon / Emoji selector
                          Text(
                            'Select Icon',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: AppSpacing.sm.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: _availableIcons.map((emoji) {
                              final isSelected = _selectedIcon == emoji;
                              return InkWell(
                                onTap: () => setState(() => _selectedIcon = emoji),
                                borderRadius: BorderRadius.circular(8.r),
                                child: Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.2)
                                        : Theme.of(context).cardColor,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Theme.of(context).dividerColor,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: AppSpacing.xxl.h),

                          // Submit Button
                          AppButton(
                            label: _isEditing ? 'Update Category' : 'Save Category',
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

    final name = _nameCtrl.text.trim();
    final notifier = ref.read(categoryNotifierProvider.notifier);
    final bool success;

    if (_isEditing) {
      final updated = widget.existingCategory!.copyWith(
        name: name,
        iconKey: _selectedIcon,
      );
      success = await notifier.updateCategory(updated);
    } else {
      final category = TransactionCategory(
        id: '',
        domain: _domain,
        name: name,
        iconKey: _selectedIcon,
        colorHex: _domain == 'income' ? '#4CAF50' : '#F44336',
        isSystemPreset: false,
        sortOrder: 0,
        isDeleted: false,
      );
      success = await notifier.createCategory(category);
    }

    if (success && mounted) {
      Navigator.pop(context);
      AppSnackbar.showSuccess(
        context,
        _isEditing
            ? 'Category updated successfully'
            : 'Category created successfully',
      );
    }
  }
}
