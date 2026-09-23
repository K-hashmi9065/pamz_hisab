import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/family_utilize_summary.dart';
import '../providers/family_utilize_providers.dart';
import '../widgets/add_family_utilize_sheet.dart';
import '../widgets/family_utilize_filter_sheet.dart';
import '../widgets/family_utilize_tile.dart';

/// Screen for tracking Family / Personal utilization of available funds.
class FamilyUtilizeScreen extends ConsumerStatefulWidget {
  const FamilyUtilizeScreen({super.key});

  @override
  ConsumerState<FamilyUtilizeScreen> createState() =>
      _FamilyUtilizeScreenState();
}

class _FamilyUtilizeScreenState extends ConsumerState<FamilyUtilizeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text =
        ref.read(familyUtilizeFilterProvider).searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(familyUtilizeFilterProvider.notifier).update(
          (state) => state.copyWith(searchQuery: query),
        );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(familyUtilizeSummaryProvider);
    final listAsync = ref.watch(familyUtilizeListNotifierProvider);
    final filter = ref.watch(familyUtilizeFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Utilize'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter',
            onPressed: () => FamilyUtilizeFilterSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(familyUtilizeSummaryProvider);
              ref.invalidate(familyUtilizeListNotifierProvider);
            },
          ),
          SizedBox(width: 8.w),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddFamilyUtilizeSheet.show(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Utilization'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyUtilizeSummaryProvider);
          ref.invalidate(familyUtilizeListNotifierProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(AppSpacing.md.r),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Top Section: 3-Metric Summary
                  summaryAsync.when(
                    loading: () => SizedBox(
                      height: 140.h,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Center(
                      child: Text('Error loading summary: $e'),
                    ),
                    data: (summary) => _buildSummaryCards(context, summary),
                  ),
                  SizedBox(height: AppSpacing.md.h),

                  // Search Bar + Filter Trigger
                  _buildSearchBar(context, isDark),
                  SizedBox(height: AppSpacing.sm.h),

                  // Active Filter Indicator Chips (if any)
                  if (filter.category != null ||
                      filter.from != null ||
                      filter.datePreset != FamilyUtilizeDatePreset.all) ...[
                    _buildActiveFilterChips(context, filter),
                    SizedBox(height: AppSpacing.sm.h),
                  ],

                  // Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Utilization History', style: AppTextStyles.h3),
                      FilledButton.tonalIcon(
                        onPressed: () => AddFamilyUtilizeSheet.show(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                ]),
              ),
            ),

            // History Items List / Empty State
            listAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.r),
                    child: Text('Error loading history: $e'),
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _buildEmptyState(context),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.r),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return FamilyUtilizeTile(item: items[index]);
                      },
                      childCount: items.length,
                    ),
                  ),
                );
              },
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: 80.h),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, FamilyUtilizeSummary summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remaining = summary.remainingAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Headline Card: Remaining Available Balance
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
            side: BorderSide(
              color: isDark ? AppColors.darkOutline : AppColors.outline,
              width: 1,
            ),
          ),
          color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REMAINING AVAILABLE BALANCE',
                      style: AppTextStyles.label.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: remaining >= 0 ? AppColors.credit : AppColors.debit,
                      size: 22.r,
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  CurrencyFormatter.formatIndian(remaining),
                  style: AppTextStyles.display.copyWith(
                    color: remaining >= 0 ? AppColors.credit : AppColors.debit,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Available = Received - Returned - Total Utilized',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10.h),

        // 2-Column Metrics (Available Fund Before Utilize & Total Family Utilized)
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                    side: BorderSide(
                      color: isDark ? AppColors.darkOutline : AppColors.outline,
                      width: 0.8,
                    ),
                  ),
                  color: isDark
                      ? AppColors.darkCardBackground
                      : AppColors.cardBackground,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Balance',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          CurrencyFormatter.formatIndian(
                            summary.availableBeforeFamilyUtilize,
                          ),
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.credit,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Received - Returned - Contact Utilized',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10.sp,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                    side: BorderSide(
                      color: isDark ? AppColors.darkOutline : AppColors.outline,
                      width: 0.8,
                    ),
                  ),
                  color: isDark
                      ? AppColors.darkCardBackground
                      : AppColors.cardBackground,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Family Utilized',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          CurrencyFormatter.formatIndian(
                            summary.totalFamilyUtilized,
                          ),
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Spent by Family',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10.sp,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by title, category, paid to, amount...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? AppColors.darkCardBackground
                  : AppColors.cardBackground,
              contentPadding: EdgeInsets.symmetric(
                vertical: 12.h,
                horizontal: 16.w,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkOutline : AppColors.outline,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkOutline : AppColors.outline,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        IconButton.filledTonal(
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Filters',
          onPressed: () => FamilyUtilizeFilterSheet.show(context),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChips(
    BuildContext context,
    FamilyUtilizeFilter filter,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (filter.category != null)
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: Chip(
                label: Text('Category: ${filter.category}'),
                onDeleted: () {
                  ref.read(familyUtilizeFilterProvider.notifier).update(
                        (s) => s.copyWith(clearCategory: true),
                      );
                },
              ),
            ),
          if (filter.datePreset != FamilyUtilizeDatePreset.all)
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: Chip(
                label: Text(
                  filter.datePreset == FamilyUtilizeDatePreset.custom
                      ? 'Custom Range'
                      : filter.datePreset.name.toUpperCase(),
                ),
                onDeleted: () {
                  ref.read(familyUtilizeFilterProvider.notifier).update(
                        (s) => s.copyWith(
                          clearFrom: true,
                          clearTo: true,
                          datePreset: FamilyUtilizeDatePreset.all,
                        ),
                      );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.all(AppSpacing.md.r),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        side: const BorderSide(color: AppColors.outline, width: 0.8),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl.r),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 56.r,
                color: AppColors.textDisabled,
              ),
              SizedBox(height: 12.h),
              Text(
                'No Family Utilizations Recorded',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                'Track family spending like school fees, bills, groceries, and medical expenses.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Utilization'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => AddFamilyUtilizeSheet.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
