import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../fund_ledger/presentation/widgets/fl_payment_mode_field.dart';
import '../../domain/entities/family_utilize.dart';
import '../providers/family_utilize_providers.dart';

/// Modal bottom sheet / dialog to record a new Family Utilization.
class AddFamilyUtilizeSheet extends ConsumerStatefulWidget {
  const AddFamilyUtilizeSheet({
    super.key,
    this.initialItem,
    this.onSuccess,
  });

  final FamilyUtilize? initialItem;
  final VoidCallback? onSuccess;

  static Future<void> show(
    BuildContext context, {
    FamilyUtilize? item,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddFamilyUtilizeSheet(
        initialItem: item,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  ConsumerState<AddFamilyUtilizeSheet> createState() =>
      _AddFamilyUtilizeSheetState();
}

class _AddFamilyUtilizeSheetState extends ConsumerState<AddFamilyUtilizeSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _refController;
  late final TextEditingController _paidToController;
  late final TextEditingController _mobileController;
  late final TextEditingController _descController;

  late String _selectedCategory;
  late String _selectedPaymentMode;
  late DateTime _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _amountController = TextEditingController(
      text: item != null ? item.amount.toStringAsFixed(0) : '',
    );
    _titleController = TextEditingController(text: item?.title ?? '');
    _selectedPaymentMode = item?.paymentMode ?? 'Cash';
    _refController = TextEditingController(text: item?.paymentReference ?? '');
    _paidToController = TextEditingController(text: item?.paidTo ?? '');
    _mobileController = TextEditingController(text: item?.mobileNumber ?? '');
    _descController = TextEditingController(text: item?.description ?? '');
    _selectedCategory = item?.category ?? 'Education';
    _selectedDate = item != null
        ? (AppDateUtils.parseIso(item.transactionDate) ?? DateTime.now())
        : DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _refController.dispose();
    _paidToController.dispose();
    _mobileController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onPaymentModeChanged(String newMode) {
    setState(() {
      _selectedPaymentMode = newMode;
      _refController.clear(); // Clear stale reference value on switch
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSubmit(double remainingAvailable) async {
    if (!_formKey.currentState!.validate()) return;

    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0;

    // Check available balance constraint (accounting for initial item when editing)
    final effectiveAvailable = widget.initialItem != null
        ? remainingAvailable + widget.initialItem!.amount
        : remainingAvailable;

    if (enteredAmount > effectiveAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount cannot exceed available balance (${CurrencyFormatter.formatIndian(effectiveAvailable)})',
          ),
          backgroundColor: AppColors.debit,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final refText = _selectedPaymentMode == 'Cash'
          ? null
          : (_refController.text.trim().isEmpty
              ? null
              : _refController.text.trim());

      final item = FamilyUtilize(
        id: widget.initialItem?.id ?? const Uuid().v4(),
        amount: enteredAmount,
        category: _selectedCategory,
        title: _titleController.text.trim(),
        paymentMode: _selectedPaymentMode,
        paymentReference: refText,
        paidTo: _paidToController.text.trim().isEmpty
            ? null
            : _paidToController.text.trim(),
        mobileNumber: _mobileController.text.trim().isEmpty
            ? null
            : _mobileController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        transactionDate: AppDateUtils.toDateOnly(_selectedDate),
        createdAt: widget.initialItem?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.initialItem != null) {
        await ref
            .read(familyUtilizeListNotifierProvider.notifier)
            .updateItem(item);
      } else {
        await ref.read(familyUtilizeListNotifierProvider.notifier).add(item);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialItem != null
                  ? 'Utilization updated successfully'
                  : 'Family Utilization recorded successfully',
            ),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving utilization: $e'),
            backgroundColor: AppColors.debit,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(familyUtilizeSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final remainingAvailable = summaryAsync.maybeWhen(
      data: (s) => s.remainingAvailable,
      orElse: () => 0.0,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl.r),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialItem != null
                            ? 'Edit Family Utilization'
                            : 'Add Family Utilization',
                        style: AppTextStyles.h2,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Available Balance: ${CurrencyFormatter.formatIndian(remainingAvailable)}',
                        style: AppTextStyles.caption.copyWith(
                          color: remainingAvailable > 0
                              ? AppColors.credit
                              : AppColors.debit,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Category Selector
              Text('Category *', style: AppTextStyles.label),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                children: FamilyUtilize.presetCategories.map((preset) {
                  final isSelected = _selectedCategory.toLowerCase() ==
                      preset.name.toLowerCase();
                  return ChoiceChip(
                    avatar: Icon(
                      preset.icon,
                      size: 18.r,
                      color: isSelected ? Colors.white : preset.color,
                    ),
                    label: Text(preset.name),
                    selected: isSelected,
                    selectedColor: preset.color,
                    backgroundColor: isDark
                        ? AppColors.darkCardBackground
                        : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected
                          ? preset.color
                          : (isDark
                              ? AppColors.darkOutline
                              : AppColors.outline.withAlpha(120)),
                      width: isSelected ? 1.5 : 1,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    labelPadding: EdgeInsets.only(left: 4.w, right: 6.w),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13.sp,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd.r),
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = preset.name);
                      }
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 16.h),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount (₹) *',
                  hintText: 'e.g. 5000',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Amount is required';
                  }
                  final n = double.tryParse(val.trim());
                  if (n == null || n <= 0) {
                    return 'Enter a valid amount greater than 0';
                  }
                  final maxAllowed = widget.initialItem != null
                      ? remainingAvailable + widget.initialItem!.amount
                      : remainingAvailable;
                  if (n > maxAllowed) {
                    return 'Amount cannot exceed available balance';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),

              // Title / Paid For Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title / Paid For *',
                  hintText: 'e.g. School Fee, Electricity Bill, Grocery',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),

              // Date Picker Field
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date *',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd.r),
                    ),
                  ),
                  child: Text(
                    AppDateUtils.toDisplay(_selectedDate),
                    style: AppTextStyles.body,
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Payment Mode Selection
              FLPaymentModeField(
                selectedMode: _selectedPaymentMode,
                onChanged: _onPaymentModeChanged,
              ),
              SizedBox(height: 12.h),

              // Conditional Reference Field
              if (_selectedPaymentMode != 'Cash') ...[
                TextFormField(
                  controller: _refController,
                  decoration: InputDecoration(
                    labelText: switch (_selectedPaymentMode) {
                      'UPI' => 'UTR Number (Optional)',
                      'Cheque' => 'Cheque Number (Optional)',
                      'Draft' => 'Draft Number (Optional)',
                      _ => 'Reference Number (Optional)',
                    },
                    hintText: switch (_selectedPaymentMode) {
                      'UPI' => '12-digit UPI reference / UTR',
                      'Cheque' => '6-digit cheque number',
                      'Draft' => 'Demand draft number',
                      _ => 'Payment reference',
                    },
                    prefixIcon: const Icon(Icons.tag_rounded),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],

              // Paid To (Optional)
              TextFormField(
                controller: _paidToController,
                decoration: InputDecoration(
                  labelText: 'Paid To (Optional)',
                  hintText: 'e.g. ABC School, Hospital, Shop Name',
                  prefixIcon: const Icon(Icons.business_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Mobile Number (Optional)
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'Mobile Number (Optional)',
                  hintText: '10-digit mobile number',
                  prefixIcon: const Icon(Icons.phone_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Description / Note (Optional)
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description / Note (Optional)',
                  hintText: 'Additional remarks or breakdown',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Submit Button
              FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _handleSubmit(remainingAvailable),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: Size(double.infinity, 50.h),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20.r,
                        width: 20.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.initialItem != null
                            ? 'Update Utilization'
                            : 'Save Utilization',
                        style: AppTextStyles.button.copyWith(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
