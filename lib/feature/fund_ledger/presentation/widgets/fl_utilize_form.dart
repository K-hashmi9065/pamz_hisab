import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/fl_transaction.dart';
import '../providers/fl_contact_providers.dart';
import '../providers/fl_transaction_providers.dart';
import 'fl_contact_search_field.dart';

/// Form/Modal sheet to record utilized funds (spending / internal allocation).
class FLUtilizeForm extends ConsumerStatefulWidget {
  const FLUtilizeForm({
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
        child: FLUtilizeForm(
          initialContactId: contactId,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  ConsumerState<FLUtilizeForm> createState() => _FLUtilizeFormState();
}

class _FLUtilizeFormState extends ConsumerState<FLUtilizeForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _mobileController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedContactId;
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
    _titleController.dispose();
    _mobileController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
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
      constraints: BoxConstraints(maxHeight: screenH * 0.92),
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
                          color: AppColors.info.withAlpha(isDark ? 30 : 25),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.info,
                          size: 20.r,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'Utilize Fund',
                        style: AppTextStyles.h2.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
                          onChanged: (val) => setState(() => _selectedContactId = val),
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Please select a contact' : null,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                    ],

              // Purpose / Title (Required)
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Purpose / Title *',
                  prefixIcon: Icon(Icons.label_outline),
                  hintText: 'e.g. Medical, Rent, Grocery, Supplies',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter purpose/title';
                  return null;
                },
              ),
              SizedBox(height: AppSpacing.sm.h),

              // Amount (Required)
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTextStyles.amountLarge.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (₹) *',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  hintText: '0.00',
                  labelStyle: AppTextStyles.label,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter amount';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Enter a valid amount greater than 0';
                  return null;
                },
              ),
              SizedBox(height: AppSpacing.sm.h),

              // Recipient Mobile Number (Optional)
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Recipient / Vendor Mobile (Optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '10-digit mobile number',
                  prefixText: '+91 ',
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),

              // Date & Time pickers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
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
                        if (picked != null) setState(() => _selectedTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),

              // Description (Optional)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description_outlined),
                  hintText: 'Details of expenditure...',
                ),
                maxLines: 2,
              ),
              SizedBox(height: AppSpacing.sm.h),

              // Note (Optional)
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  prefixIcon: Icon(Icons.notes),
                  hintText: 'Any extra notes...',
                ),
              ),
              SizedBox(height: AppSpacing.md.h),

              // Submit Button
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.info,
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
                      : Icon(Icons.shopping_bag_outlined, size: 20.r),
                  label: Text(
                    isLoading ? 'Saving...' : 'Record Fund Utilization',
                    style: AppTextStyles.button.copyWith(color: Colors.white),
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

    final success = await ref.read(flTransactionFormNotifierProvider.notifier).add(
          contactId: _selectedContactId!,
          type: FLTransactionType.utilized,
          amount: amount,
          txnDate: dateStr,
          txnTime: timeStr,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        widget.onSuccess?.call();
        // Utilization is internal, only shows toast/snackbar, NO invoice share dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fund utilization recorded internally'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record fund utilization'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
