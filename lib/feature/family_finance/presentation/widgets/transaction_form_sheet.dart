import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/family_transaction.dart';
import '../providers/family_finance_providers.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({
    super.key,
    this.initialType = 'expense',
    this.existingTransaction,
  });

  final String initialType; // 'income' or 'expense'
  final FamilyTransaction? existingTransaction;

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();
  String? _receiptPhotoPath;

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final txn = widget.existingTransaction!;
      _type = txn.type;
      _amountCtrl.text = txn.amount.toStringAsFixed(
        txn.amount.truncateToDouble() == txn.amount ? 0 : 2,
      );
      _notesCtrl.text = txn.notes ?? '';
      _selectedCategoryId = txn.categoryId;
      _selectedAccountId = txn.accountId;
      _selectedDate = txn.transactionDate;
      _receiptPhotoPath = txn.receiptPhotoPath;
    } else {
      _type = widget.initialType;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        final storageService = ref.read(receiptStorageServiceProvider);
        try {
          final persistedPath = await storageService.replaceReceiptImage(
            newSourcePath: pickedFile.path,
            oldPersistentPath: _receiptPhotoPath,
          );
          if (mounted) {
            setState(() {
              _receiptPhotoPath = persistedPath;
            });
          }
        } catch (storageError) {
          if (mounted) {
            AppSnackbar.showError(
              context,
              'Failed to save receipt image to secure storage. Please try again.',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Unable to access camera or photo library. Please check permissions.',
        );
      }
    }
  }

  Future<void> _removeReceipt() async {
    final oldPath = _receiptPhotoPath;
    setState(() {
      _receiptPhotoPath = null;
    });
    if (oldPath != null) {
      await ref.read(receiptStorageServiceProvider).deleteReceiptImage(oldPath);
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.md.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Attach Receipt Photo',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: AppSpacing.md.h),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Take Photo (Camera)'),
                subtitle: const Text('Use iPad camera to scan physical receipt'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickReceipt(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Choose from Library'),
                subtitle: const Text('Select an existing photo from Photos'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickReceipt(ImageSource.gallery);
                },
              ),
              if (_receiptPhotoPath != null)
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.debitLight,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.debit),
                  ),
                  title: const Text('Remove Receipt Photo', style: TextStyle(color: AppColors.debit)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeReceipt();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptPreviewDialog() {
    if (_receiptPhotoPath == null) return;
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
                  Text(
                    'Receipt Preview',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
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
                    File(_receiptPhotoPath!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: EdgeInsets.all(AppSpacing.xl.w),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48.r, color: AppColors.debit),
                          SizedBox(height: AppSpacing.sm.h),
                          const Text('Unable to load receipt image preview.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.debit),
                    label: const Text('Remove', style: TextStyle(color: AppColors.debit)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _removeReceipt();
                    },
                  ),
                  SizedBox(width: AppSpacing.sm.w),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Change'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showImageSourcePicker();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(familyFinanceNotifierProvider);
    final isLoading = notifierState.isLoading;
    final categoriesAsync = ref.watch(categoriesProvider(_type));
    final accountsAsync = ref.watch(accountsProvider);
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
                          child: Text(
                            _isEditing
                                ? (_type == 'income' ? 'Edit Income' : 'Edit Expense')
                                : (_type == 'income' ? 'Add Income' : 'Add Expense'),
                            style: AppTextStyles.h2,
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
                    child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(AppSpacing.lg.w),
                  children: [
                    // Type selector
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('Expense'),
                          icon: Icon(Icons.trending_down_rounded),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('Income'),
                          icon: Icon(Icons.trending_up_rounded),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (v) {
                        setState(() {
                          _type = v.first;
                          _selectedCategoryId = null; // reset category on type switch
                        });
                      },
                    ),
                    SizedBox(height: AppSpacing.lg.h),

                    // Amount input
                    AppTextField.currency(
                      label: 'Amount (₹)',
                      controller: _amountCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        final num = double.tryParse(v.trim());
                        if (num == null || num <= 0) {
                          return 'Enter a valid amount greater than 0';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Category dropdown
                    categoriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error loading categories: $err'),
                      data: (categories) {
                        final validCategory = categories.any((c) => c.id == _selectedCategoryId);
                        if (!validCategory && categories.isNotEmpty) {
                          _selectedCategoryId = categories.first.id;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat.id,
                              child: Row(
                                children: [
                                  if (cat.iconKey != null) ...[
                                    Text(cat.iconKey!,
                                        style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(cat.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedCategoryId = val);
                          },
                          validator: (val) => val == null || val.isEmpty
                              ? 'Please select a category'
                              : null,
                        );
                      },
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Account selector (Cash / Bank)
                    accountsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (accounts) {
                        final validAccount = accounts.any((a) => a.id == _selectedAccountId);
                        if (!validAccount && accounts.isNotEmpty && _selectedAccountId == null) {
                          _selectedAccountId = accounts.first.id;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedAccountId,
                          decoration: const InputDecoration(
                            labelText: 'Payment Account',
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                          ),
                          items: accounts.map((acc) {
                            return DropdownMenuItem<String>(
                              value: acc.id,
                              child: Row(
                                children: [
                                  Icon(
                                    acc.type == 'bank'
                                        ? Icons.account_balance_rounded
                                        : Icons.payments_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(acc.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedAccountId = val);
                          },
                        );
                      },
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Date Picker Tile
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      leading: const Icon(Icons.calendar_today_rounded),
                      title: const Text('Transaction Date'),
                      subtitle: Text(
                        DateFormat('dd MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Notes
                    AppTextField(
                      label: 'Notes (optional)',
                      controller: _notesCtrl,
                      textInputAction: TextInputAction.done,
                    ),

                    // Receipt Photo Section (FR-FE-002)
                    if (_type == 'expense') ...[
                      SizedBox(height: AppSpacing.md.h),
                      Text(
                        'Receipt Photo (Optional)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      SizedBox(height: AppSpacing.xs.h),
                      if (_receiptPhotoPath != null && _receiptPhotoPath!.isNotEmpty)
                        Container(
                          padding: EdgeInsets.all(AppSpacing.sm.w),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            color: Theme.of(context).cardColor,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _showReceiptPreviewDialog,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: Image.file(
                                    File(_receiptPhotoPath!),
                                    width: 60.w,
                                    height: 60.h,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 60.w,
                                      height: 60.h,
                                      color: AppColors.cardBackground,
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: AppSpacing.md.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Receipt attached',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      _receiptPhotoPath!.split(Platform.pathSeparator).last,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                tooltip: 'Preview Receipt',
                                onPressed: _showReceiptPreviewDialog,
                              ),
                              IconButton(
                                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                                tooltip: 'Replace Receipt',
                                onPressed: _showImageSourcePicker,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.debit),
                                tooltip: 'Remove Receipt',
                                onPressed: _removeReceipt,
                              ),
                            ],
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md.w,
                              vertical: AppSpacing.md.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            side: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Attach Receipt Photo'),
                          onPressed: _showImageSourcePicker,
                        ),
                    ],

                    SizedBox(height: AppSpacing.xxl.h),

                    // Save Button
                    AppButton(
                      label: _isEditing
                          ? (_type == 'income' ? 'Update Income' : 'Update Expense')
                          : (_type == 'income' ? 'Save Income' : 'Save Expense'),
                      isLoading: isLoading,
                      isFullWidth: true,
                      icon: Icons.check_rounded,
                      onPressed: isLoading ? null : _submit,
                    ),

                    if (notifierState.hasError)
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm.h),
                        child: Text(
                          notifierState.error.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final now = DateTime.now();

    final notifier = ref.read(familyFinanceNotifierProvider.notifier);
    final bool success;

    if (_isEditing) {
      final txn = widget.existingTransaction!.copyWith(
        type: _type,
        amount: amount,
        categoryId: _selectedCategoryId!,
        accountId: _selectedAccountId,
        receiptPhotoPath: _type == 'expense' ? _receiptPhotoPath : null,
        transactionDate: _selectedDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        updatedAt: now,
      );
      success = await notifier.updateTransaction(txn);
    } else {
      final txn = FamilyTransaction(
        id: '',
        type: _type,
        amount: amount,
        categoryId: _selectedCategoryId!,
        accountId: _selectedAccountId,
        receiptPhotoPath: _type == 'expense' ? _receiptPhotoPath : null,
        transactionDate: _selectedDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
      success = await notifier.addTransaction(txn);
    }

    if (success && mounted) {
      Navigator.pop(context);
      AppSnackbar.showSuccess(
        context,
        _isEditing
            ? (_type == 'income'
                ? 'Income updated successfully'
                : 'Expense updated successfully')
            : (_type == 'income'
                ? 'Income recorded successfully'
                : 'Expense recorded successfully'),
      );
    }
  }
}
