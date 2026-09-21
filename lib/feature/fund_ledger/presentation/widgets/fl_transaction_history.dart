import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/fl_transaction.dart';
import '../providers/fl_transaction_providers.dart';
import 'fl_transaction_tile.dart';

/// Transaction history component for a contact with filtering, loading, and deletion support.
class FLTransactionHistory extends ConsumerStatefulWidget {
  const FLTransactionHistory({
    super.key,
    required this.contactId,
    this.showHeader = true,
  });

  final String contactId;
  final bool showHeader;

  @override
  ConsumerState<FLTransactionHistory> createState() =>
      _FLTransactionHistoryState();
}

class _FLTransactionHistoryState extends ConsumerState<FLTransactionHistory> {
  FLTransactionType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final historyAsync =
        ref.watch(flTransactionHistoryProvider(widget.contactId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction History',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
            child: Row(
              children: [
                _filterChip(label: 'All', type: null, isDark: isDark),
                SizedBox(width: 8.w),
                _filterChip(
                    label: 'Received',
                    type: FLTransactionType.received,
                    isDark: isDark),
                SizedBox(width: 8.w),
                _filterChip(
                    label: 'Utilized',
                    type: FLTransactionType.utilized,
                    isDark: isDark),
                SizedBox(width: 8.w),
                _filterChip(
                    label: 'Returned',
                    type: FLTransactionType.returned,
                    isDark: isDark),
              ],
            ),
          ),
          SizedBox(height: 12.h),
        ],
        historyAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Failed to load transactions: $error',
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ),
          ),
          data: (transactions) {
            final filtered = _selectedType == null
                ? transactions
                : transactions.where((t) => t.type == _selectedType).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48.r,
                        color: AppColors.textDisabled,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'No transactions recorded',
                        style: AppTextStyles.body.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final txn = filtered[index];
                return FLTransactionTile(
                  transaction: txn,
                  onDelete: () => _confirmDelete(context, txn),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required FLTransactionType? type,
    required bool isDark,
  }) {
    final isSelected = _selectedType == type;
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
      backgroundColor:
          isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark ? AppColors.darkOutline : AppColors.outline),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      onSelected: (_) {
        setState(() {
          _selectedType = type;
        });
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, FLTransaction txn) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to delete this transaction? This action will update ledger balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(flTransactionFormNotifierProvider.notifier)
          .delete(txn.id, txn.contactId);

      if (!success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to delete transaction'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
