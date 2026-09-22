import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/fl_transaction.dart';
import '../providers/fl_contact_providers.dart';
import '../providers/fl_transaction_providers.dart';
import '../screens/fl_pdf_preview_screen.dart';
import 'fl_contact_search_field.dart';
import 'fl_payment_mode_field.dart';

/// Form/Modal sheet to record received funds from a contact.
class FLReceiveForm extends ConsumerStatefulWidget {
  const FLReceiveForm({
    super.key,
    this.initialContactId,
    this.onSuccess,
  });

  final String? initialContactId;
  final VoidCallback? onSuccess;

  static Future<void> show(
    BuildContext context, {
    String? contactId,
    VoidCallback? onSuccess,
  }) {
    final container = ProviderScope.containerOf(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: FLReceiveForm(
          initialContactId: contactId,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  ConsumerState<FLReceiveForm> createState() => _FLReceiveFormState();
}

class _FLReceiveFormState extends ConsumerState<FLReceiveForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedContactId;
  String _paymentMode = 'Cash';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _selectedContactId = widget.initialContactId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onPaymentModeChanged(String newMode) {
    setState(() {
      _paymentMode = newMode;
      _refController.clear(); // Clear stale reference on mode switch
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final contactsAsync = ref.watch(flContactListProvider);
    final formState = ref.watch(flTransactionFormNotifierProvider);
    final isLoading = formState.isLoading;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.95),
      padding: EdgeInsets.only(
        left: AppSpacing.md.w,
        right: AppSpacing.md.w,
        top: AppSpacing.sm.h,
        bottom: bottomInset + AppSpacing.lg.h,
      ),
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
            margin: EdgeInsets.only(bottom: AppSpacing.md.h),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkOutline : AppColors.outline,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: AppColors.creditLight
                                    .withAlpha(isDark ? 30 : 255),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                color: AppColors.credit,
                                size: 20.r,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              'Receive Fund',
                              style: AppTextStyles.h2.copyWith(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Contact Selector (if not preselected)
                    if (widget.initialContactId == null) ...[
                      contactsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error loading contacts: $e'),
                        data: (contacts) => FLContactSearchField(
                          contacts: contacts,
                          selectedContactId: _selectedContactId,
                          onChanged: (val) =>
                              setState(() => _selectedContactId = val),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Please select a contact'
                              : null,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                    ],

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: widget.initialContactId != null,
                      style: AppTextStyles.amountLarge
                          .copyWith(color: AppColors.credit),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹) *',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        hintText: '0.00',
                        labelStyle: AppTextStyles.label,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) {
                          return 'Enter a valid amount greater than 0';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppSpacing.sm.h),

                    // Date & Time pickers
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(DateFormat('dd MMM yyyy')
                                .format(_selectedDate)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _selectedDate = picked);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(_selectedTime.format(context)),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime,
                              );
                              if (picked != null) {
                                setState(() => _selectedTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.sm.h),

                    // Payment Mode Selection
                    FLPaymentModeField(
                      selectedMode: _paymentMode,
                      onChanged: _onPaymentModeChanged,
                    ),
                    SizedBox(height: AppSpacing.sm.h),

                    // Conditional Reference Field
                    if (_paymentMode != 'Cash') ...[
                      TextFormField(
                        controller: _refController,
                        decoration: InputDecoration(
                          labelText: switch (_paymentMode) {
                            'UPI' => 'UTR Number (Optional)',
                            'Cheque' => 'Cheque Number (Optional)',
                            'Draft' => 'Draft Number (Optional)',
                            _ => 'Reference Number (Optional)',
                          },
                          prefixIcon: const Icon(Icons.tag),
                          hintText: switch (_paymentMode) {
                            'UPI' => '12-digit UPI reference / UTR',
                            'Cheque' => '6-digit cheque number',
                            'Draft' => 'Demand draft number',
                            _ => 'Payment reference',
                          },
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                    ],

                    // Optional title
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title (Optional)',
                        prefixIcon: Icon(Icons.title_outlined),
                        hintText: 'e.g. Monthly contribution',
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),

                    // Note
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (Optional)',
                        prefixIcon: Icon(Icons.notes),
                        hintText: 'Add remarks...',
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Submit Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.credit,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: isLoading ? null : _submit,
                      icon: isLoading
                          ? SizedBox(
                              height: 20.h,
                              width: 20.h,
                              child: const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(Icons.arrow_downward_rounded, size: 20.r),
                      label: Text(
                        isLoading ? 'Saving...' : 'Record Received Fund',
                        style:
                            AppTextStyles.button.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContactId == null || _selectedContactId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a contact'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final refText = _paymentMode == 'Cash'
        ? null
        : (_refController.text.trim().isEmpty
            ? null
            : _refController.text.trim());

    final success =
        await ref.read(flTransactionFormNotifierProvider.notifier).add(
              contactId: _selectedContactId!,
              type: FLTransactionType.received,
              amount: amount,
              txnDate: dateStr,
              txnTime: timeStr,
              paymentMode: _paymentMode,
              paymentReference: refText,
              title: _titleController.text.trim().isEmpty
                  ? null
                  : _titleController.text.trim(),
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            );

    if (!mounted) return;

    if (success) {
      final contactId = _selectedContactId!;
      final nav = Navigator.of(context);
      final parentContext = nav.context;
      final contactFuture = ref.read(flContactByIdProvider(contactId).future);
      final txnsFuture =
          ref.read(flTransactionHistoryProvider(contactId).future);

      nav.pop();
      widget.onSuccess?.call();

      if (nav.context.mounted) {
        await showFLPdfPreviewFromFutures(
          parentContext,
          contactFuture: contactFuture,
          txnsFuture: txnsFuture,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to record fund receive'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
