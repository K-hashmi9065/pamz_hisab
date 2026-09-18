import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/phone_validator.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/contact.dart';
import '../providers/contact_providers.dart';

/// Form screen for creating or editing a contact (buyer or supplier).
class ContactFormScreen extends ConsumerStatefulWidget {
  const ContactFormScreen({
    super.key,
    this.existingContact,
    this.type,
  });

  final Contact? existingContact;
  final ContactType? type;

  bool get isEditing => existingContact != null;

  @override
  ConsumerState<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends ConsumerState<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _villageCtrl;
  late final TextEditingController _shopLocationCtrl;
  late final TextEditingController _creditLimitCtrl;
  late ContactType _type;
  late bool _dueDateAlertEnabled;

  @override
  void initState() {
    super.initState();
    final c = widget.existingContact;
    _type = c?.type ?? widget.type ?? ContactType.buyer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _mobileCtrl = TextEditingController(text: c?.mobileNumber ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _villageCtrl = TextEditingController(text: c?.villageTola ?? '');
    _shopLocationCtrl = TextEditingController(text: c?.shopLocation ?? '');
    _creditLimitCtrl = TextEditingController(
      text: c?.creditLimit != null && c!.creditLimit > 0
          ? c.creditLimit.toString()
          : '',
    );
    _dueDateAlertEnabled = c?.dueDateAlertEnabled ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _villageCtrl.dispose();
    _shopLocationCtrl.dispose();
    _creditLimitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(contactFormNotifierProvider);
    final isLoading = notifier.isLoading;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle
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
                      widget.isEditing ? 'Edit Contact' : 'New Contact',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(AppSpacing.lg.w),
                  children: [
                    // Type toggle
                    SegmentedButton<ContactType>(
                      segments: const [
                        ButtonSegment(
                          value: ContactType.buyer,
                          label: Text('Buyer'),
                          icon: Icon(Icons.person_rounded),
                        ),
                        ButtonSegment(
                          value: ContactType.supplier,
                          label: Text('Supplier'),
                          icon: Icon(Icons.store_rounded),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (v) =>
                          setState(() => _type = v.first),
                    ),
                    SizedBox(height: AppSpacing.lg.h),

                    AppTextField(
                      key: const Key('nameField'),
                      label: 'Full Name',
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    AppTextField.phone(
                      key: const Key('mobileField'),
                      controller: _mobileCtrl,
                      validator: PhoneValidator.validate,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    AppTextField(
                      label: 'Address (optional)',
                      controller: _addressCtrl,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    if (_type == ContactType.buyer) ...[
                      AppTextField(
                        label: 'Village / Tola (optional)',
                        controller: _villageCtrl,
                        textInputAction: TextInputAction.next,
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      AppTextField.currency(
                        label: 'Credit Limit (optional)',
                        controller: _creditLimitCtrl,
                        textInputAction: TextInputAction.done,
                      ),
                    ],

                    if (_type == ContactType.supplier) ...[
                      AppTextField(
                        label: 'Shop Location (optional)',
                        controller: _shopLocationCtrl,
                        textInputAction: TextInputAction.done,
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      SwitchListTile.adaptive(
                        key: const Key('dueDateAlertSwitch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Due Date Alerts'),
                        subtitle: const Text('Notify when supplier balance is due for payment'),
                        value: _dueDateAlertEnabled,
                        onChanged: (val) => setState(() => _dueDateAlertEnabled = val),
                      ),
                    ],

                    SizedBox(height: AppSpacing.xxl.h),

                    AppButton(
                      key: const Key('saveContactButton'),
                      label: widget.isEditing ? 'Update Contact' : 'Save Contact',
                      isLoading: isLoading,
                      isFullWidth: true,
                      icon: Icons.check_rounded,
                      onPressed: isLoading ? null : _submit,
                    ),

                    // Show error if any
                    if (notifier.hasError)
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm.h),
                        child: Text(
                          notifier.error.toString(),
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
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final contact = Contact(
      id: widget.existingContact?.id ?? '',
      type: _type,
      name: _nameCtrl.text.trim(),
      mobileNumber: PhoneValidator.normalize(_mobileCtrl.text.trim()),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      villageTola: _villageCtrl.text.trim().isEmpty ? null : _villageCtrl.text.trim(),
      shopLocation: _shopLocationCtrl.text.trim().isEmpty ? null : _shopLocationCtrl.text.trim(),
      creditLimit: double.tryParse(_creditLimitCtrl.text) ?? 0,
      dueDateAlertEnabled: _dueDateAlertEnabled,
      createdAt: widget.existingContact?.createdAt ?? now,
      updatedAt: now,
    );

    final notifier = ref.read(contactFormNotifierProvider.notifier);
    final success = widget.isEditing
        ? await notifier.updateContact(contact)
        : await notifier.createContact(contact);

    if (success && mounted) {
      Navigator.pop(context);
      AppSnackbar.showSuccess(
        context,
        widget.isEditing ? 'Contact updated' : 'Contact saved',
      );
    }
  }
}
