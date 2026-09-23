import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/family_utilize.dart';
import '../providers/family_utilize_providers.dart';

/// Bottom sheet for setting advanced filters on Family Utilizations.
class FamilyUtilizeFilterSheet extends ConsumerStatefulWidget {
  const FamilyUtilizeFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FamilyUtilizeFilterSheet(),
    );
  }

  @override
  ConsumerState<FamilyUtilizeFilterSheet> createState() =>
      _FamilyUtilizeFilterSheetState();
}

class _FamilyUtilizeFilterSheetState
    extends ConsumerState<FamilyUtilizeFilterSheet> {
  String? _selectedCategory;
  FamilyUtilizeDatePreset _preset = FamilyUtilizeDatePreset.all;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    final current = ref.read(familyUtilizeFilterProvider);
    _selectedCategory = current.category;
    _preset = current.datePreset;
    _fromDate = current.from;
    _toDate = current.to;
  }

  void _applyPreset(FamilyUtilizeDatePreset preset) {
    final now = DateTime.now();
    setState(() {
      _preset = preset;
      switch (preset) {
        case FamilyUtilizeDatePreset.all:
          _fromDate = null;
          _toDate = null;
        case FamilyUtilizeDatePreset.today:
          _fromDate = DateTime(now.year, now.month, now.day);
          _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        case FamilyUtilizeDatePreset.thisWeek:
          final monday = now.subtract(Duration(days: now.weekday - 1));
          _fromDate = DateTime(monday.year, monday.month, monday.day);
          _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        case FamilyUtilizeDatePreset.thisMonth:
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        case FamilyUtilizeDatePreset.thisYear:
          _fromDate = DateTime(now.year, 1, 1);
          _toDate = DateTime(now.year, 12, 31, 23, 59, 59);
        case FamilyUtilizeDatePreset.custom:
          break;
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _preset = FamilyUtilizeDatePreset.custom;
        _fromDate = picked.start;
        _toDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  void _applyFilters() {
    ref.read(familyUtilizeFilterProvider.notifier).update((state) {
      return state.copyWith(
        category: _selectedCategory,
        clearCategory: _selectedCategory == null,
        from: _fromDate,
        clearFrom: _fromDate == null,
        to: _toDate,
        clearTo: _toDate == null,
        datePreset: _preset,
      );
    });
    Navigator.of(context).pop();
  }

  void _clearFilters() {
    ref.read(familyUtilizeFilterProvider.notifier).update(
          (state) => state.copyWith(
            clearCategory: true,
            clearFrom: true,
            clearTo: true,
            datePreset: FamilyUtilizeDatePreset.all,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl.r),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter Utilizations', style: AppTextStyles.h2),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Reset All'),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Date presets
            Text('Date Range', style: AppTextStyles.label),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 10.w,
              runSpacing: 10.h,
              children: [
                _buildPresetChip('All Time', FamilyUtilizeDatePreset.all, isDark),
                _buildPresetChip('Today', FamilyUtilizeDatePreset.today, isDark),
                _buildPresetChip(
                    'This Week', FamilyUtilizeDatePreset.thisWeek, isDark),
                _buildPresetChip(
                    'This Month', FamilyUtilizeDatePreset.thisMonth, isDark),
                _buildPresetChip(
                    'This Year', FamilyUtilizeDatePreset.thisYear, isDark),
                ActionChip(
                  avatar: Icon(
                    Icons.date_range_rounded,
                    size: 18.r,
                    color: _preset == FamilyUtilizeDatePreset.custom
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                  ),
                  label: Text(
                    _preset == FamilyUtilizeDatePreset.custom && _fromDate != null
                        ? '${AppDateUtils.toDisplay(_fromDate!)} - ${AppDateUtils.toDisplay(_toDate!)}'
                        : 'Custom Range',
                  ),
                  backgroundColor: _preset == FamilyUtilizeDatePreset.custom
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkCardBackground
                          : const Color(0xFFF1F5F9)),
                  side: BorderSide(
                    color: _preset == FamilyUtilizeDatePreset.custom
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.darkOutline
                            : AppColors.outline.withAlpha(120)),
                    width: _preset == FamilyUtilizeDatePreset.custom ? 1.5 : 1,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  labelStyle: TextStyle(
                    color: _preset == FamilyUtilizeDatePreset.custom
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                    fontWeight: _preset == FamilyUtilizeDatePreset.custom
                        ? FontWeight.w600
                        : FontWeight.w500,
                    fontSize: 13.sp,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd.r),
                  ),
                  onPressed: _pickDateRange,
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Category filter
            Text('Category', style: AppTextStyles.label),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 10.w,
              runSpacing: 10.h,
              children: [
                ChoiceChip(
                  label: const Text('All Categories'),
                  selected: _selectedCategory == null,
                  selectedColor: AppColors.primary,
                  backgroundColor: isDark
                      ? AppColors.darkCardBackground
                      : const Color(0xFFF1F5F9),
                  side: BorderSide(
                    color: _selectedCategory == null
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.darkOutline
                            : AppColors.outline.withAlpha(120)),
                    width: _selectedCategory == null ? 1.5 : 1,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  labelStyle: TextStyle(
                    color: _selectedCategory == null
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                    fontWeight: _selectedCategory == null
                        ? FontWeight.w600
                        : FontWeight.w500,
                    fontSize: 13.sp,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd.r),
                  ),
                  showCheckmark: false,
                  onSelected: (s) {
                    if (s) setState(() => _selectedCategory = null);
                  },
                ),
                ...FamilyUtilize.presetCategories.map((preset) {
                  final isSelected = _selectedCategory?.toLowerCase() ==
                      preset.name.toLowerCase();
                  return ChoiceChip(
                    avatar: Icon(
                      preset.icon,
                      size: 18.r,
                      color: isSelected ? Colors.white : preset.color,
                    ),
                    label: Text(preset.name),
                    selected: isSelected,
                    selectedColor: preset.color,
                    backgroundColor: isDark
                        ? AppColors.darkCardBackground
                        : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected
                          ? preset.color
                          : (isDark
                              ? AppColors.darkOutline
                              : AppColors.outline.withAlpha(120)),
                      width: isSelected ? 1.5 : 1,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    labelPadding: EdgeInsets.only(left: 4.w, right: 6.w),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13.sp,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd.r),
                    ),
                    showCheckmark: false,
                    onSelected: (s) {
                      setState(() {
                        _selectedCategory = s ? preset.name : null;
                      });
                    },
                  );
                }),
              ],
            ),
            SizedBox(height: 24.h),

            FilledButton(
              onPressed: _applyFilters,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: Size(double.infinity, 50.h),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                ),
              ),
              child: Text(
                'Apply Filters',
                style: AppTextStyles.button.copyWith(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    FamilyUtilizeDatePreset preset,
    bool isDark,
  ) {
    final isSelected = _preset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor:
          isDark ? AppColors.darkCardBackground : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark
                ? AppColors.darkOutline
                : AppColors.outline.withAlpha(120)),
        width: isSelected ? 1.5 : 1,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 10.h,
      ),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13.sp,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
      ),
      showCheckmark: false,
      onSelected: (selected) {
        if (selected) _applyPreset(preset);
      },
    );
  }
}
