import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/fl_contact.dart';
import '../providers/fl_contact_providers.dart';

Future<void> showFLContactFormBottomSheet(
  BuildContext context, {
  FLContact? contact,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    constraints: BoxConstraints(
      maxWidth: 720,
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    showDragHandle: true,
    builder: (_) => FLContactFormScreen(contact: contact),
  );
}

/// Screen to create a new Fund Ledger contact or edit an existing one.
class FLContactFormScreen extends ConsumerStatefulWidget {
  const FLContactFormScreen({
    super.key,
    this.contact,
  });

  final FLContact? contact;

  @override
  ConsumerState<FLContactFormScreen> createState() =>
      _FLContactFormScreenState();
}

class _FLContactFormScreenState extends ConsumerState<FLContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _aadhaarController;
  late final TextEditingController _projectController;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _mobileController =
        TextEditingController(text: widget.contact?.mobileNumber ?? '');
    _aadhaarController =
        TextEditingController(text: widget.contact?.aadhaarNumber ?? '');
    _projectController =
        TextEditingController(text: widget.contact?.project ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _aadhaarController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(flContactFormNotifierProvider);
    final isLoading = formState.isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.onPrimary,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
          ),
        ),
        title: Text(
          _isEditing ? 'Edit Contact' : 'New Contact',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm.w),
            child: TextButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg.r,
            AppSpacing.lg.r,
            AppSpacing.lg.r,
            AppSpacing.lg.r + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name Field
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Mohd Rashid',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppSpacing.md.h),

                // Mobile Number Field
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    hintText: '10-digit mobile number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '+91 ',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a mobile number';
                    }
                    if (value.trim().length != 10) {
                      return 'Mobile number must be exactly 10 digits';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppSpacing.md.h),

                // Aadhaar Number (Optional)
                TextFormField(
                  controller: _aadhaarController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar / ID Number (Optional)',
                    hintText: '12-digit Aadhaar number',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),

                // Project / Purpose
                TextFormField(
                  controller: _projectController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Project / Group (Optional)',
                    hintText: 'e.g. Wedding Fund, Community Aid, Construction',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                SizedBox(height: AppSpacing.xl.h),

                // Primary Submit Button
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 56),
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                  ),
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? SizedBox(
                          height: 20.h,
                          width: 20.h,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Contact' : 'Create Contact',
                          style: AppTextStyles.button
                              .copyWith(color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final aadhaar = _aadhaarController.text.trim().isEmpty
        ? null
        : _aadhaarController.text.trim();
    final project = _projectController.text.trim().isEmpty
        ? null
        : _projectController.text.trim();

    final notifier = ref.read(flContactFormNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    bool success;
    if (_isEditing) {
      final updated = widget.contact!.copyWith(
        name: name,
        mobileNumber: mobile,
        aadhaarNumber: aadhaar,
        project: project,
        updatedAt: DateTime.now(),
      );
      success = await notifier.updateContact(updated);
    } else {
      final newContact = FLContact(
        id: const Uuid().v4(),
        name: name,
        mobileNumber: mobile,
        aadhaarNumber: aadhaar,
        project: project,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      success = await notifier.createContact(newContact);
    }

    if (success) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Contact updated' : 'Contact created'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Operation failed. Please check your inputs.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
