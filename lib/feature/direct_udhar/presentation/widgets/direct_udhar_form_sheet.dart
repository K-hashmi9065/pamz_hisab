import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../contacts/presentation/providers/contact_providers.dart';
import '../../../contacts/presentation/screens/contact_form_screen.dart';
import '../../domain/entities/direct_udhar_loan.dart';
import '../providers/direct_udhar_providers.dart';

class DirectUdharFormSheet extends ConsumerStatefulWidget {
  const DirectUdharFormSheet({
    super.key,
    this.targetContactId,
    this.initialDirection = LoanDirection.lent,
  });

  final String? targetContactId;
  final LoanDirection initialDirection;

  @override
  ConsumerState<DirectUdharFormSheet> createState() =>
      _DirectUdharFormSheetState();
}

class _DirectUdharFormSheetState extends ConsumerState<DirectUdharFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late LoanDirection _direction;
  String? _selectedContactId;
  final _amountCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  InterestType _interestType = InterestType.interestFree;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
    _selectedContactId = widget.targetContactId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    _interestRateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(directUdharFormNotifierProvider);
    final isLoading = notifierState.isLoading;
    final contactsAsync = ref.watch(allContactListProvider);
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
                            _direction == LoanDirection.lent
                                ? 'New Udhar Given (Lent)'
                                : 'New Udhar Taken (Borrowed)',
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
                    // Direction selector
                    SegmentedButton<LoanDirection>(
                      segments: const [
                        ButtonSegment(
                          value: LoanDirection.lent,
                          label: Text('Given (Lent)'),
                          icon: Icon(Icons.arrow_upward_rounded),
                        ),
                        ButtonSegment(
                          value: LoanDirection.borrowed,
                          label: Text('Taken (Borrowed)'),
                          icon: Icon(Icons.arrow_downward_rounded),
                        ),
                      ],
                      selected: {_direction},
                      onSelectionChanged: (v) =>
                          setState(() => _direction = v.first),
                    ),
                    SizedBox(height: AppSpacing.lg.h),

                    // Contact selector
                    contactsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error loading contacts: $err'),
                      data: (contacts) {
                        if (contacts.isEmpty) {
                          return Container(
                            padding: EdgeInsets.all(AppSpacing.md.w),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryLight),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: AppColors.primary),
                                SizedBox(width: 8.w),
                                const Expanded(
                                  child: Text('No contacts found. Please add a contact first.'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => const ContactFormScreen(),
                                    );
                                  },
                                  child: const Text('+ Add Contact'),
                                ),
                              ],
                            ),
                          );
                        }

                        if (_selectedContactId == null && contacts.isNotEmpty) {
                          _selectedContactId = contacts.first.id;
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedContactId,
                          decoration: InputDecoration(
                            labelText: 'Select Contact',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.person_add_outlined),
                              tooltip: 'Add New Contact',
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => const ContactFormScreen(),
                                );
                              },
                            ),
                          ),
                          items: contacts.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text('${c.name} (${c.mobileNumber})'),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedContactId = val),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Please select a contact'
                              : null,
                        );
                      },
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Amount
                    AppTextField.currency(
                      label: 'Principal Amount (₹)',
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

                    // Interest Type
                    SegmentedButton<InterestType>(
                      segments: const [
                        ButtonSegment(
                          value: InterestType.interestFree,
                          label: Text('Interest Free'),
                        ),
                        ButtonSegment(
                          value: InterestType.simple,
                          label: Text('Simple Interest'),
                        ),
                      ],
                      selected: {_interestType},
                      onSelectionChanged: (v) =>
                          setState(() => _interestType = v.first),
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    if (_interestType == InterestType.simple) ...[
                      AppTextField(
                        label: 'Monthly Interest Rate (% per month)',
                        hint: 'e.g. 2 for 2% per 30 days',
                        controller: _interestRateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter monthly interest rate';
                          }
                          final rate = double.tryParse(v.trim());
                          if (rate == null || rate <= 0) {
                            return 'Enter a valid rate greater than 0';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppSpacing.md.h),
                    ],

                    // Due Date
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      leading: const Icon(Icons.event_available_rounded),
                      title: const Text('Due Date (optional)'),
                      subtitle: Text(
                        _dueDate != null
                            ? DateFormat('dd MMMM yyyy').format(_dueDate!)
                            : 'No due date set',
                        style: TextStyle(
                          fontWeight: _dueDate != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: _dueDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => setState(() => _dueDate = null),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          setState(() => _dueDate = picked);
                        }
                      },
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // Memo
                    AppTextField(
                      label: 'Memo (optional)',
                      controller: _memoCtrl,
                      textInputAction: TextInputAction.done,
                    ),
                    SizedBox(height: AppSpacing.xxl.h),

                    // Save Button
                    AppButton(
                      label: 'Record Udhar',
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
    if (_selectedContactId == null) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final interestRate = _interestType == InterestType.simple
        ? double.tryParse(_interestRateCtrl.text.trim())
        : null;
    final now = DateTime.now();

    final loan = DirectUdharLoan(
      id: '',
      contactId: _selectedContactId!,
      direction: _direction,
      principalAmount: amount,
      interestType: _interestType,
      interestRatePercent: interestRate,
      dueDate: _dueDate,
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      status: LoanStatus.open,
      outstandingBalance: amount,
      createdAt: now,
      updatedAt: now,
    );

    final notifier = ref.read(directUdharFormNotifierProvider.notifier);
    final success = await notifier.createLoan(loan);

    if (success && mounted) {
      Navigator.pop(context);
      AppSnackbar.showSuccess(
        context,
        _direction == LoanDirection.lent
            ? 'Udhar loan recorded successfully'
            : 'Borrowed amount recorded successfully',
      );
    }
  }
}
