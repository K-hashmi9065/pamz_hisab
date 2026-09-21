import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../routes/route_names.dart';
import '../../../fund_ledger/domain/entities/fl_dashboard_summary.dart';
import '../../../fund_ledger/presentation/providers/fl_transaction_providers.dart';
import '../../../fund_ledger/presentation/screens/fl_contact_form_screen.dart';
import '../../../fund_ledger/presentation/widgets/fl_receive_form.dart';
import '../../../fund_ledger/presentation/widgets/fl_return_form.dart';
import '../../../fund_ledger/presentation/widgets/fl_summary_card.dart';
import '../../../fund_ledger/presentation/widgets/fl_transaction_tile.dart';
import '../../../fund_ledger/presentation/widgets/fl_utilize_form.dart';

/// Dashboard screen for PAMZ Fund Responsibility Ledger.
/// Shows global metrics, quick action modals, and recent transaction activity.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(flDashboardSummaryProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(flDashboardSummaryProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context),
            SliverPadding(
              padding: EdgeInsets.all(AppSpacing.md.w),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  summaryAsync.when(
                    loading: () => SizedBox(
                      height: 180.h,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Center(
                      child: Text('Failed to load dashboard: $e'),
                    ),
                    data: (summary) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeadlineCard(context, summary.availableAmount),
                        SizedBox(height: AppSpacing.md.h),
                        _buildMetricCards(context, summary),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                  _buildQuickActions(context, ref),
                  SizedBox(height: AppSpacing.xl.h),
                  _buildRecentActivityHeader(context),
                  SizedBox(height: AppSpacing.sm.h),
                  summaryAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (summary) => _buildRecentActivity(context, summary, ref),
                  ),
                  SizedBox(height: AppSpacing.xxl.h),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return SliverAppBar(
      expandedHeight: 110.h,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          left: AppSpacing.lg.w,
          bottom: AppSpacing.md.h,
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting • ${AppDateUtils.toDisplay(now)}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimary.withAlpha(200),
                fontSize: 11.sp,
              ),
            ),
            Text(
              'PAMZ Fund Responsibility Ledger',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadlineCard(BuildContext context, double availableAmount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPositive = availableAmount >= 0;

    return Card(
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
                  'TOTAL AVAILABLE FUND RESPONSIBILITY',
                  style: AppTextStyles.label.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: isPositive ? AppColors.credit : AppColors.debit,
                  size: 24.r,
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              CurrencyFormatter.formatIndian(availableAmount),
              style: AppTextStyles.display.copyWith(
                color: isPositive ? AppColors.credit : AppColors.debit,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Total Available = Total Received - Total Returned',
              style: AppTextStyles.caption.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCards(BuildContext context, FLDashboardSummary summary) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FLSummaryCard(
              label: 'Received',
              amount: summary.totalReceived,
              icon: Icons.arrow_downward_rounded,
              color: AppColors.credit,
              subtitle: 'All contacts',
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: FLSummaryCard(
              label: 'Utilized',
              amount: summary.totalUtilized,
              icon: Icons.shopping_bag_outlined,
              color: AppColors.info,
              subtitle: 'Allocated',
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: FLSummaryCard(
              label: 'Returned',
              amount: summary.totalReturned,
              icon: Icons.arrow_upward_rounded,
              color: AppColors.debit,
              subtitle: 'Returned',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTextStyles.h3,
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                label: const Text('Receive'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.credit,
                  foregroundColor: AppColors.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () => FLReceiveForm.show(
                  context,
                  onSuccess: () => ref.invalidate(flDashboardSummaryProvider),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Utilize'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: AppColors.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () => FLUtilizeForm.show(
                  context,
                  onSuccess: () => ref.invalidate(flDashboardSummaryProvider),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                label: const Text('Return'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.debit,
                  foregroundColor: AppColors.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () => FLReturnForm.show(
                  context,
                  onSuccess: () => ref.invalidate(flDashboardSummaryProvider),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivityHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Activity',
          style: AppTextStyles.h3.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        TextButton(
          onPressed: () => context.goNamed(RouteNames.reports),
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, FLDashboardSummary summary, WidgetRef ref) {
    final recent = summary.recentTransactions;
    if (recent.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
          side: const BorderSide(color: AppColors.outline, width: 0.8),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl.r),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48.r,
                  color: AppColors.textDisabled,
                ),
                SizedBox(height: 8.h),
                Text(
                  'No transactions recorded yet',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 8.h),
                TextButton.icon(
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add Contact to Get Started'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FLContactFormScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        final item = recent[index];
        return FLTransactionTile(transaction: item.transaction);
      },
    );
  }
}
