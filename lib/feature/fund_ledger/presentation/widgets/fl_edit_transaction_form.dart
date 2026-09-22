import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/fl_transaction.dart';
import '../providers/fl_transaction_providers.dart';
import 'fl_payment_mode_field.dart';

class FLEditTransactionForm extends ConsumerStatefulWidget {
  const FLEditTransactionForm({super.key, required this.transaction});

  final FLTransaction transaction;

  static Future<void> show(BuildContext context, FLTransaction transaction) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FLEditTransactionForm(transaction: transaction),
    );
  }

  @override
  ConsumerState<FLEditTransactionForm> createState() =>
      _FLEditTransactionFormState();
}

class _FLEditTransactionFormState extends ConsumerState<FLEditTransactionForm> {
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _referenceController;
  late final TextEditingController _noteController;
  late String _paymentMode;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _amountController =
        TextEditingController(text: transaction.amount.toStringAsFixed(2));
    _titleController = TextEditingController(text: transaction.title ?? '');
    _referenceController =
        TextEditingController(text: transaction.paymentReference ?? '');
    _noteController = TextEditingController(text: transaction.note ?? '');
    _paymentMode = transaction.paymentMode ?? 'Cash';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUtilized = widget.transaction.type == FLTransactionType.utilized;
    final isLoading = ref.watch(flTransactionFormNotifierProvider).isLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.r,
        0,
        AppSpacing.lg.r,
        AppSpacing.lg.r + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Transaction',
              style: AppTextStyles.h2,
            ),
            SizedBox(height: AppSpacing.md.h),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title (Optional)',
                prefixIcon: Icon(Icons.title_outlined),
              ),
            ),
            if (!isUtilized) ...[
              SizedBox(height: AppSpacing.sm.h),
              FLPaymentModeField(
                selectedMode: _paymentMode,
                onChanged: (mode) => setState(() {
                  _paymentMode = mode;
                  _referenceController.clear();
                }),
              ),
              if (_paymentMode != 'Cash') ...[
                SizedBox(height: AppSpacing.sm.h),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Number (Optional)',
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
              ],
            ],
            SizedBox(height: AppSpacing.sm.h),
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            SizedBox(height: AppSpacing.md.h),
            FilledButton(
              onPressed: isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(isLoading ? 'Saving...' : 'Update Transaction'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final transaction = widget.transaction.copyWith(
      amount: amount,
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      paymentMode: widget.transaction.type == FLTransactionType.utilized
          ? widget.transaction.paymentMode
          : _paymentMode,
      paymentReference: _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      updatedAt: DateTime.now(),
    );

    final success = await ref
        .read(flTransactionFormNotifierProvider.notifier)
        .update(transaction);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update transaction'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
