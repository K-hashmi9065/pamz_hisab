import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/fl_transaction.dart';
import '../providers/fl_contact_providers.dart';
import '../providers/fl_transaction_providers.dart';
import '../widgets/fl_transaction_tile.dart';

/// Reports screen for Fund Ledger supporting rich filtering by type, contact, date range,
/// aggregate summary metrics, and transaction drill-down.
class FLReportsScreen extends ConsumerStatefulWidget {
  const FLReportsScreen({super.key});

  @override
  ConsumerState<FLReportsScreen> createState() => _FLReportsScreenState();
}

class _FLReportsScreenState extends ConsumerState<FLReportsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(flReportsFilterProvider);
    final reportsAsync = ref.watch(flReportsListProvider);
    final contactsAsync = ref.watch(flContactListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports & Analytics',
          style: AppTextStyles.h2.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Controls Section
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.sm.h,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkOutline : AppColors.outline,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Type Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _typeChip(label: 'All Types', type: null, currentType: filter.type, isDark: isDark),
                        SizedBox(width: 8.w),
                        _typeChip(label: 'Received', type: FLTransactionType.received, currentType: filter.type, isDark: isDark),
                        SizedBox(width: 8.w),
                        _typeChip(label: 'Utilized', type: FLTransactionType.utilized, currentType: filter.type, isDark: isDark),
                        SizedBox(width: 8.w),
                        _typeChip(label: 'Returned', type: FLTransactionType.returned, currentType: filter.type, isDark: isDark),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // Contact Filter & Date Filter row
                  Row(
                    children: [
                      // Contact Dropdown
                      Expanded(
                        child: contactsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (contacts) => DropdownButtonFormField<String?>(
                            initialValue: filter.contactId,
                            isDense: true,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 8.h,
                              ),
                              hintText: 'All Contacts',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Contacts'),
                              ),
                              ...contacts.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              ref.read(flReportsFilterProvider.notifier).state =
                                  filter.copyWith(contactId: val);
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Date Range Picker Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          filter.from == null && filter.to == null
                              ? 'All Time'
                              : '${DateFormat('dd/MM').format(filter.from ?? DateTime(2000))} - ${DateFormat('dd/MM').format(filter.to ?? DateTime.now())}',
                          style: AppTextStyles.captionBold,
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDateRange: filter.from != null && filter.to != null
                                ? DateTimeRange(start: filter.from!, end: filter.to!)
                                : null,
                          );
                          if (picked != null) {
                            ref.read(flReportsFilterProvider.notifier).state = filter.copyWith(
                              from: picked.start,
                              to: picked.end,
                            );
                          } else {
                            ref.read(flReportsFilterProvider.notifier).state = filter.copyWith(
                              from: null,
                              to: null,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main List & Aggregate Metrics
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(flReportsListProvider);
                },
                child: reportsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text('Error loading reports: $err'),
                  ),
                  data: (txns) {
                    final totalReceived = txns
                        .where((t) => t.type == FLTransactionType.received)
                        .fold<double>(0, (sum, t) => sum + t.amount);
                    final totalUtilized = txns
                        .where((t) => t.type == FLTransactionType.utilized)
                        .fold<double>(0, (sum, t) => sum + t.amount);
                    final totalReturned = txns
                        .where((t) => t.type == FLTransactionType.returned)
                        .fold<double>(0, (sum, t) => sum + t.amount);
                    final netAvailable = totalReceived - totalReturned;

                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Summary Metrics Grid
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md.r),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _metricTile(
                                        title: 'Total Received',
                                        amount: totalReceived,
                                        color: AppColors.credit,
                                        isDark: isDark,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _metricTile(
                                        title: 'Total Utilized',
                                        amount: totalUtilized,
                                        color: AppColors.info,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _metricTile(
                                        title: 'Total Returned',
                                        amount: totalReturned,
                                        color: AppColors.debit,
                                        isDark: isDark,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _metricTile(
                                        title: 'Net Available',
                                        amount: netAvailable,
                                        color: netAvailable >= 0 ? AppColors.credit : AppColors.debit,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Section Title
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md.w,
                              vertical: AppSpacing.xs.h,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Transactions (${txns.length})',
                                  style: AppTextStyles.h3.copyWith(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Transactions List
                        if (txns.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.xl.r),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.filter_alt_off_outlined,
                                      size: 56.r,
                                      color: AppColors.textDisabled,
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'No transactions match this filter',
                                      style: AppTextStyles.body.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.only(
                              left: AppSpacing.xs.w,
                              right: AppSpacing.xs.w,
                              bottom: AppSpacing.xxl.h,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final txn = txns[index];
                                  return FLTransactionTile(transaction: txn);
                                },
                                childCount: txns.length,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required FLTransactionType? type,
    required FLTransactionType? currentType,
    required bool isDark,
  }) {
    final isSelected = type == currentType;
    return ChoiceChip(
      label: Text(
        label,
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
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
      side: BorderSide(
        color: isSelected ? AppColors.primary : (isDark ? AppColors.darkOutline : AppColors.outline),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      onSelected: (_) {
        ref.read(flReportsFilterProvider.notifier).state =
            ref.read(flReportsFilterProvider).copyWith(type: type);
      },
    );
  }

  Widget _metricTile({
    required String title,
    required double amount,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.r),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
        border: Border.all(
          color: isDark ? AppColors.darkOutline : AppColors.outline,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            CurrencyFormatter.formatIndian(amount),
            style: AppTextStyles.amountSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
