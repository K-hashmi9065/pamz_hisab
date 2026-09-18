import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../domain/entities/direct_udhar_loan.dart';
import '../providers/direct_udhar_providers.dart';

/// Modal bottom sheet to record a partial or full Repayment ("Jama") against a Direct Udhar loan (FR-DU-003).
class RepaymentFormSheet extends ConsumerStatefulWidget {
  const RepaymentFormSheet({
    super.key,
    required this.contact,
    this.initialLoan,
  });

  final Contact contact;
  final DirectUdharLoan? initialLoan;

  @override
  ConsumerState<RepaymentFormSheet> createState() => _RepaymentFormSheetState();
}

class _RepaymentFormSheetState extends ConsumerState<RepaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  DirectUdharLoan? _selectedLoan;
  String _paymentMode = 'cash';
  DateTime _paidAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedLoan = widget.initialLoan;
    _amountCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {}); // update live remaining balance badge
  }

  double get _enteredAmount => double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(directUdharFormNotifierProvider);
    final isLoading = notifierState.isLoading;
    final loansAsync = ref.watch(loansByContactProvider(widget.contact.id));
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
            initialChildSize: 0.85,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Record Repayment (Jama)',
                                style: AppTextStyles.h2,
                              ),
                              Text(
                                'Party: ${widget.contact.name} (${widget.contact.type.name.toUpperCase()})',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
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
                    child: loansAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Failed to load loans: $e')),
                      data: (loans) {
                  final activeLoans = loans.where((l) => !l.isDeleted && l.outstandingBalance > 0).toList();

                  if (activeLoans.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 48.r, color: AppColors.credit),
                            SizedBox(height: AppSpacing.md.h),
                            Text(
                              'No Outstanding Balance',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: AppSpacing.xs.h),
                            Text(
                              '${widget.contact.name} has no open Udhar balance to repay.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Auto-select initial or first active loan if not set
                  if (_selectedLoan == null && activeLoans.isNotEmpty) {
                    _selectedLoan = activeLoans.first;
                  }

                  return Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.all(AppSpacing.lg.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Select Loan if multiple active loans exist
                          if (activeLoans.length > 1) ...[
                            Text(
                              'Select Loan / Voucher',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.sp,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: AppSpacing.xs.h),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedLoan?.id,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.receipt_long_rounded),
                              ),
                              items: activeLoans.map((l) {
                                final dir = l.direction == LoanDirection.lent ? 'Lent' : 'Borrowed';
                                return DropdownMenuItem(
                                  value: l.id,
                                  child: Text(
                                    '${DateFormat('dd MMM yyyy').format(l.createdAt)} — ${CurrencyFormatter.formatIndian(l.outstandingBalance)} ($dir)',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedLoan = activeLoans.firstWhere((l) => l.id == val);
                                  });
                                }
                              },
                            ),
                            SizedBox(height: AppSpacing.md.h),
                          ],

                          // 2. Loan Summary Card
                          if (_selectedLoan != null) _buildLoanSummaryCard(_selectedLoan!),
                          SizedBox(height: AppSpacing.lg.h),

                          // 3. Amount Field + Full Balance Chip
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Repayment Amount *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.sp,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              if (_selectedLoan != null)
                                ActionChip(
                                  label: Text(
                                    'Full Balance (${CurrencyFormatter.formatIndian(_selectedLoan!.outstandingBalance)})',
                                    style: TextStyle(fontSize: 11.sp, color: AppColors.primary),
                                  ),
                                  onPressed: () {
                                    _amountCtrl.text = _selectedLoan!.outstandingBalance.toStringAsFixed(0);
                                  },
                                ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.xs.h),
                          AppTextField.currency(
                            label: 'Amount (₹)',
                            controller: _amountCtrl,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter repayment amount';
                              }
                              final amount = double.tryParse(val.trim());
                              if (amount == null || amount <= 0) {
                                return 'Enter a valid amount greater than 0';
                              }
                              if (_selectedLoan != null && amount > _selectedLoan!.outstandingBalance) {
                                return 'Amount cannot exceed current balance of ${CurrencyFormatter.formatIndian(_selectedLoan!.outstandingBalance)}';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: AppSpacing.md.h),

                          // 4. Live Remaining Balance Preview
                          if (_selectedLoan != null && _enteredAmount > 0)
                            _buildRemainingBalancePreview(_selectedLoan!),
                          SizedBox(height: AppSpacing.md.h),

                          // 5. Payment Mode
                          Text(
                            'Payment Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.sp,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs.h),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'cash',
                                label: Text('Cash'),
                                icon: Icon(Icons.payments_outlined),
                              ),
                              ButtonSegment(
                                value: 'bank',
                                label: Text('Bank Transfer'),
                                icon: Icon(Icons.account_balance_outlined),
                              ),
                              ButtonSegment(
                                value: 'upi',
                                label: Text('UPI / Online'),
                                icon: Icon(Icons.qr_code_rounded),
                              ),
                            ],
                            selected: {_paymentMode},
                            onSelectionChanged: (val) => setState(() => _paymentMode = val.first),
                          ),
                          SizedBox(height: AppSpacing.md.h),

                          // 6. Payment Date
                          ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              side: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                            leading: const Icon(Icons.calendar_today_rounded),
                            title: const Text('Payment Date'),
                            subtitle: Text(
                              DateFormat('dd MMMM yyyy').format(_paidAt),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _paidAt,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _paidAt = picked);
                              }
                            },
                          ),
                          SizedBox(height: AppSpacing.md.h),

                          // 7. Memo / Note (optional)
                          AppTextField(
                            label: 'Memo / Reference (optional)',
                            controller: _memoCtrl,
                            textInputAction: TextInputAction.done,
                          ),
                          SizedBox(height: AppSpacing.xl.h),

                          // 8. Submit Button
                          AppButton(
                            label: 'Record Repayment (Jama)',
                            icon: Icons.check_circle_outline_rounded,
                            isLoading: isLoading,
                            isFullWidth: true,
                            onPressed: isLoading ? null : _submit,
                          ),

                          if (notifierState.hasError)
                            Padding(
                              padding: EdgeInsets.only(top: AppSpacing.sm.h),
                              child: Text(
                                notifierState.error.toString(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13.sp,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
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

  Widget _buildLoanSummaryCard(DirectUdharLoan loan) {
    final isLent = loan.direction == LoanDirection.lent;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: isLent ? AppColors.creditLight : AppColors.debitLight,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isLent ? AppColors.credit.withValues(alpha: 0.3) : AppColors.debit.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isLent ? 'LENT UDHAR (RECEIVABLE)' : 'BORROWED UDHAR (PAYABLE)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.sp,
                  color: isLent ? AppColors.credit : AppColors.debit,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  loan.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: loan.isOpen ? AppColors.primary : AppColors.credit,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Original Principal: ${CurrencyFormatter.formatIndian(loan.principalAmount)}',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[800])),
              Text(
                'Current Outstanding:',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loan.isSimpleInterest ? 'Interest: ${loan.interestRatePercent}%/mo' : 'Interest-Free',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
              Text(
                CurrencyFormatter.formatIndian(loan.outstandingBalance),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: isLent ? AppColors.credit : AppColors.debit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingBalancePreview(DirectUdharLoan loan) {
    final remaining = (loan.outstandingBalance - _enteredAmount).clamp(0.0, double.infinity);
    final isSettled = remaining == 0.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
      decoration: BoxDecoration(
        color: isSettled ? AppColors.credit.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isSettled ? AppColors.credit : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isSettled ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 16.r,
                color: isSettled ? AppColors.credit : AppColors.primary,
              ),
              SizedBox(width: AppSpacing.xs.w),
              Text(
                isSettled ? 'Loan will be FULLY SETTLED' : 'Remaining Balance after payment:',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isSettled ? FontWeight.bold : FontWeight.w500,
                  color: isSettled ? AppColors.credit : Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            CurrencyFormatter.formatIndian(remaining),
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: isSettled ? AppColors.credit : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLoan == null) return;

    final success = await ref.read(directUdharFormNotifierProvider.notifier).recordRepayment(
          loanId: _selectedLoan!.id,
          contactId: widget.contact.id,
          amount: _enteredAmount,
          mode: _paymentMode,
          paidAt: _paidAt,
          memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        );

    if (success && mounted) {
      Navigator.pop(context);
      AppSnackbar.showSuccess(
        context,
        'Repayment of ${CurrencyFormatter.formatIndian(_enteredAmount)} recorded successfully',
      );
    }
  }
}
