import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/fl_contact.dart';

/// A tappable field that opens a searchable contact picker bottom sheet.
///
/// Replaces the plain [DropdownButtonFormField] for contact selection.
class FLContactSearchField extends StatelessWidget {
  const FLContactSearchField({
    super.key,
    required this.contacts,
    required this.selectedContactId,
    required this.onChanged,
    this.validator,
  });

  final List<FLContact> contacts;
  final String? selectedContactId;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  FLContact? get _selected =>
      selectedContactId == null
          ? null
          : contacts.where((c) => c.id == selectedContactId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = _selected;

    return FormField<String>(
      initialValue: selectedContactId,
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                final result = await _showContactSearchSheet(context);
                if (result != null) {
                  onChanged(result);
                  state.didChange(result);
                }
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 16.h,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: state.hasError
                        ? AppColors.error
                        : isDark
                            ? AppColors.darkOutline
                            : AppColors.outline,
                    width: state.hasError ? 1.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_search_outlined,
                      size: 20.r,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: selected == null
                          ? Text(
                              'Select Contact *',
                              style: AppTextStyles.body.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selected.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  selected.mobileNumber,
                                  style: AppTextStyles.caption.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20.r,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: EdgeInsets.only(top: 4.h, left: 12.w),
                child: Text(
                  state.errorText!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<String?> _showContactSearchSheet(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactSearchSheet(
        contacts: contacts,
        selectedId: selectedContactId,
      ),
    );
  }
}

class _ContactSearchSheet extends StatefulWidget {
  const _ContactSearchSheet({
    required this.contacts,
    this.selectedId,
  });

  final List<FLContact> contacts;
  final String? selectedId;

  @override
  State<_ContactSearchSheet> createState() => _ContactSearchSheetState();
}

class _ContactSearchSheetState extends State<_ContactSearchSheet> {
  final _searchController = TextEditingController();
  List<FLContact> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.contacts;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.contacts
          : widget.contacts
              .where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.mobileNumber.contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.85),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.only(top: AppSpacing.sm.h, bottom: AppSpacing.sm.h),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkOutline : AppColors.outline,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Contact',
                  style: AppTextStyles.h2.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: AppSpacing.sm.h,
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or mobile...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),

          SizedBox(height: AppSpacing.xs.h),

          // Contact list
          Flexible(
            child: _filtered.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(AppSpacing.xl.r),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48.r,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        Text(
                          'No contacts found',
                          style: AppTextStyles.body.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.only(
                      left: AppSpacing.sm.w,
                      right: AppSpacing.sm.w,
                      bottom: AppSpacing.lg.h,
                    ),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? AppColors.darkOutline : AppColors.outline,
                      indent: 56.w,
                    ),
                    itemBuilder: (context, index) {
                      final contact = _filtered[index];
                      final isSelected = contact.id == widget.selectedId;
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(contact.id),
                        leading: CircleAvatar(
                          radius: 20.r,
                          backgroundColor: isSelected
                              ? AppColors.primary.withAlpha(200)
                              : (isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant),
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                            ),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          contact.mobileNumber,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 20.r,
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
