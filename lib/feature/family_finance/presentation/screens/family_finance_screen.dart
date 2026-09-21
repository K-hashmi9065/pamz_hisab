import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../domain/entities/family_transaction.dart';
import 'budget_screen.dart';
import '../providers/family_finance_providers.dart';
import '../widgets/family_finance_summary_cards.dart';
import '../widgets/transaction_form_sheet.dart';

/// Family Finance screen — tabbed Income / Expense view (FR-FE-001/002).
class FamilyFinanceScreen extends ConsumerStatefulWidget {
  const FamilyFinanceScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<FamilyFinanceScreen> createState() =>
      _FamilyFinanceScreenState();
}

class _FamilyFinanceScreenState extends ConsumerState<FamilyFinanceScreen>
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

  void _openAddTransactionSheet([String? forcedType]) {
    final type = forcedType ?? (_tabController.index == 0 ? 'income' : 'expense');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionFormSheet(initialType: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    final body = Column(
      children: [
        // 1. Summary Cards (Total Income | Total Expense | Net Balance)
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          child: const FamilyFinanceSummaryCards(),
        ),

        // 2. Tab Switch (Income | Expense)
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.xs.h,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCardBackground
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
              border: Border.all(
                color: isDark ? AppColors.darkOutline : AppColors.outline,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r - 2),
                color: _tabController.index == 0
                    ? AppColors.creditLight.withValues(alpha: 0.4)
                    : AppColors.debitLight.withValues(alpha: 0.4),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: _tabController.index == 0 ? AppColors.credit : AppColors.debit,
              unselectedLabelColor: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              labelStyle: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  icon: Icon(Icons.trending_up_rounded),
                  text: 'Income',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.trending_down_rounded),
                  text: 'Expense',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
        ),

        // 3. TabBarView (Transactions list)
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TransactionListView(
                type: 'income',
                onAddPressed: () => _openAddTransactionSheet('income'),
              ),
              _TransactionListView(
                type: 'expense',
                onAddPressed: () => _openAddTransactionSheet('expense'),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Family Finance',
        actions: [
          IconButton(
            icon: const Icon(Icons.track_changes_rounded, size: 28),
            tooltip: 'Budget Tracking',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BudgetScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: body,
              ),
            )
          : body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTransactionSheet(),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0
              ? 'Add Income'
              : 'Add Expense',
        ),
      ),
    );
  }
}

class _TransactionListView extends ConsumerWidget {
  const _TransactionListView({
    required this.type,
    required this.onAddPressed,
  });

  final String type;
  final VoidCallback onAddPressed;

  void _openEditTransactionSheet(BuildContext context, dynamic txn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionFormSheet(
        existingTransaction: txn,
        initialType: txn.type,
      ),
    );
  }

  void _showReceiptDialog(BuildContext context, FamilyTransaction txn) {
    if (txn.receiptPhotoPath == null || txn.receiptPhotoPath!.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Receipt: ${txn.categoryName ?? (txn.isIncome ? 'Income' : 'Expense')}',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 400.h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.file(
                    File(txn.receiptPhotoPath!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: EdgeInsets.all(AppSpacing.xl.w),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48.r, color: AppColors.debit),
                          SizedBox(height: AppSpacing.sm.h),
                          const Text(
                            'Receipt photo file is unavailable or was removed from this device.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              Text(
                '${DateFormat('dd MMM yyyy').format(txn.transactionDate)} • ${NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(txn.amount)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = type == 'income' ? incomeListProvider : expenseListProvider;
    final summaryProvider =
        type == 'income' ? currentMonthIncomeProvider : currentMonthExpenseProvider;
    final asyncTxns = ref.watch(provider);
    final monthTotalAsync = ref.watch(summaryProvider);

    final isIncome = type == 'income';
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final isWide = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    return asyncTxns.when(
      loading: () => const AppLoader(message: 'Loading records...'),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return AppEmptyState(
            title: isIncome
                ? 'No income entries yet'
                : 'No expense entries yet',
            subtitle: isIncome
                ? 'Tap + to log your first income entry'
                : 'Tap + to log your first expense with category',
            icon: isIncome
                ? Icons.trending_up_outlined
                : Icons.receipt_long_outlined,
            actionLabel: isIncome ? 'Add Income' : 'Add Expense',
            onAction: onAddPressed,
          );
        }

        final monthTotal = monthTotalAsync.value ?? 0.0;

        final content = Column(
          children: [
            // Monthly Summary Card
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.sm.h,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.md.h,
              ),
              decoration: BoxDecoration(
                color: isIncome
                    ? AppColors.creditLight.withValues(alpha: 0.3)
                    : AppColors.debitLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isIncome
                      ? AppColors.credit.withValues(alpha: 0.3)
                      : AppColors.debit.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIncome ? 'This Month Income' : 'This Month Expense',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            currencyFormat.format(monthTotal),
                            style: AppTextStyles.h1.copyWith(
                              color: isIncome ? AppColors.credit : AppColors.debit,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: isIncome
                        ? AppColors.credit.withValues(alpha: 0.15)
                        : AppColors.debit.withValues(alpha: 0.15),
                    child: Icon(
                      isIncome
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 24.r,
                      color: isIncome ? AppColors.credit : AppColors.debit,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w,
                  vertical: AppSpacing.xs.h,
                ),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => Divider(height: 1, indent: 64.w),
                itemBuilder: (context, index) {
                  final txn = transactions[index];
                  final hasReceipt =
                      txn.receiptPhotoPath != null && txn.receiptPhotoPath!.isNotEmpty;
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm.w,
                      vertical: 4.h,
                    ),
                    onTap: () => _openEditTransactionSheet(context, txn),
                    leading: CircleAvatar(
                      backgroundColor: isIncome
                          ? AppColors.creditLight
                          : AppColors.debitLight,
                      child: Text(
                        txn.categoryIcon ?? (isIncome ? '💰' : '🛒'),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            txn.categoryName ?? (isIncome ? 'Income' : 'Expense'),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm.w),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${isIncome ? '+' : '-'}${currencyFormat.format(txn.amount)}',
                            style: AppTextStyles.amountSmall.copyWith(
                              color: isIncome ? AppColors.credit : AppColors.debit,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              DateFormat('dd MMM yyyy').format(txn.transactionDate),
                              if (txn.accountName != null) txn.accountName,
                              if (txn.notes != null && txn.notes!.isNotEmpty) txn.notes,
                              if (hasReceipt) '📎 Receipt attached',
                            ].whereType<String>().join(' • '),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasReceipt)
                          IconButton(
                            icon: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.primary),
                            tooltip: 'View Receipt',
                            onPressed: () => _showReceiptDialog(context, txn),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit',
                          onPressed: () => _openEditTransactionSheet(context, txn),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          tooltip: 'Delete',
                          onPressed: () async {
                            final confirmed = await ConfirmationDialog.show(
                              context: context,
                              title: 'Delete Transaction',
                              message:
                                  'Are you sure you want to delete this transaction of ${currencyFormat.format(txn.amount)}?',
                              confirmLabel: 'Delete',
                              isDestructive: true,
                            );
                            if (confirmed == true) {
                              await ref
                                  .read(familyFinanceNotifierProvider.notifier)
                                  .deleteTransaction(txn.id);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );

        if (isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }
}
