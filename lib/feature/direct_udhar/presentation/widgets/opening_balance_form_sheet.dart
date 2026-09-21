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
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contact_providers.dart';
import '../../../contacts/presentation/screens/contact_form_screen.dart';
import '../../../contacts/presentation/services/contact_ledger_share_helper.dart';
import '../../data/services/direct_udhar_share_service.dart';
import '../../domain/entities/direct_udhar_loan.dart';
import '../../domain/services/interest_calculator.dart';
import '../providers/direct_udhar_providers.dart';

/// Form sheet for creating an Opening Balance with industry-standard financial UX,
/// PDF receipt generation, and WhatsApp/SMS share options.
class OpeningBalanceFormSheet extends ConsumerStatefulWidget {
  const OpeningBalanceFormSheet({
    super.key,
    this.targetContactId,
    this.initialDirection = LoanDirection.lent,
  });

  final String? targetContactId;
  final LoanDirection initialDirection;

  @override
  ConsumerState<OpeningBalanceFormSheet> createState() =>
      _OpeningBalanceFormSheetState();
}

class _OpeningBalanceFormSheetState
    extends ConsumerState<OpeningBalanceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late LoanDirection _direction;
  String? _selectedContactId;
  final _amountCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  InterestType _interestType = InterestType.interestFree;
  DateTime _openingDate = DateTime.now();

  // Post-save state for displaying receipt / share actions
  bool _isSaved = false;
  DirectUdharLoan? _savedLoan;
  Contact? _savedContact;
  LoanFinancialSummary? _savedSummary;
  bool _isPdfGenerating = false;
  ShareLanguage _selectedLanguage = ShareLanguage.english;

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
            initialChildSize: 0.9,
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
                                _isSaved ? 'Opening Balance Saved' : 'Set Opening Balance',
                                style: AppTextStyles.h2,
                              ),
                              if (!_isSaved)
                                Text(
                                  'Prior balance before PAMZ Hisab tracking',
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
                    child: _isSaved ? _buildSuccessAndShareView() : _buildFormView(scrollController, contactsAsync, isLoading, notifierState),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(
    ScrollController scrollController,
    AsyncValue<List<Contact>> contactsAsync,
    bool isLoading,
    AsyncValue<void> notifierState,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section A: Contact
            Text(
              'Party / Contact',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),
            contactsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load contacts: $e'),
              data: (contacts) {
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedContactId,
                        hint: const Text('Select Contact *'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        items: contacts
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.name} (${c.type.name})'),
                                ))
                            .toList(),
                        onChanged: (id) =>
                            setState(() => _selectedContactId = id),
                        validator: (v) =>
                            v == null ? 'Contact is required' : null,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm.w),
                    IconButton.filledTonal(
                      tooltip: 'Add New Contact',
                      icon: const Icon(Icons.person_add_rounded),
                      onPressed: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const ContactFormScreen(),
                        );
                        ref.invalidate(allContactListProvider);
                      },
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: AppSpacing.lg.h),

            // Section B: Direction (Lent / Borrowed)
            Text(
              'Balance Direction',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),
            SegmentedButton<LoanDirection>(
              segments: [
                ButtonSegment(
                  value: LoanDirection.lent,
                  label: const Text('Lent (Receivable)'),
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                    color: _direction == LoanDirection.lent ? AppColors.credit : null,
                  ),
                ),
                ButtonSegment(
                  value: LoanDirection.borrowed,
                  label: const Text('Borrowed (Payable)'),
                  icon: Icon(
                    Icons.arrow_downward_rounded,
                    color: _direction == LoanDirection.borrowed ? AppColors.debit : null,
                  ),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (v) => setState(() => _direction = v.first),
            ),
            SizedBox(height: AppSpacing.lg.h),

            // Section C: Opening Amount
            Text(
              'Opening Amount Details',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),
            AppTextField.currency(
              label: 'Opening Amount (₹) *',
              hint: '0.00',
              controller: _amountCtrl,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter opening amount';
                }
                final num = double.tryParse(v.trim());
                if (num == null || num <= 0) {
                  return 'Enter a valid amount greater than 0';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: AppSpacing.lg.h),

            // Section D: Interest Configuration
            Text(
              'Interest Terms',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),
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
            SizedBox(height: AppSpacing.sm.h),

            if (_interestType == InterestType.simple) ...[
              AppTextField(
                label: 'Monthly Interest Rate (% per 30 days) *',
                hint: 'e.g. 2.0 for 2% per month',
                controller: _interestRateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Monthly interest rate is required';
                  }
                  final rate = double.tryParse(v.trim());
                  if (rate == null || rate <= 0) {
                    return 'Enter a valid interest rate greater than 0';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              Padding(
                padding: EdgeInsets.only(top: 4.h, left: 4.w),
                child: Text(
                  'Calculates simple interest on reducing principal (30 days = 1 month).',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
            ],

            // Section E: Opening Date
            Text(
              'Opening Date',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
                side: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('Opening Date *'),
              subtitle: Text(
                DateFormat('dd MMMM yyyy').format(_openingDate),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _openingDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _openingDate = picked);
                }
              },
            ),
            Padding(
              padding: EdgeInsets.only(top: 4.h, left: 4.w),
              child: Text(
                'Interest calculation starts from this date.',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),

            // Section F: Title / Purpose / Note
            AppTextField(
              label: 'Title / Purpose / Note (optional)',
              hint: 'e.g. Kamran ko shopping ke liye, Previous ledger carry forward, etc.',
              controller: _memoCtrl,
              prefixIcon: const Icon(Icons.title_rounded),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
            SizedBox(height: AppSpacing.lg.h),

            // Section G: Review / Summary Box
            _buildLiveFinancialSummary(),
            SizedBox(height: AppSpacing.xl.h),

            // Save Action Button
            AppButton(
              label: 'Save Opening Balance',
              isLoading: isLoading,
              isFullWidth: true,
              icon: Icons.check_circle_outline_rounded,
              onPressed: isLoading ? null : () => _submit(contactsAsync),
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
  }

  Widget _buildLiveFinancialSummary() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final rate = _interestType == InterestType.simple
        ? double.tryParse(_interestRateCtrl.text.trim())
        : null;

    final tempLoan = DirectUdharLoan(
      id: 'temp',
      contactId: _selectedContactId ?? '',
      direction: _direction,
      principalAmount: amount,
      interestType: _interestType,
      interestRatePercent: rate,
      status: LoanStatus.open,
      outstandingBalance: amount,
      createdAt: _openingDate,
      updatedAt: _openingDate,
    );

    final summary = InterestCalculator.calculateSummary(
      loan: tempLoan,
      repayments: [],
      asOfDate: DateTime.now(),
    );

    final isLent = _direction == LoanDirection.lent;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isLent ? AppColors.credit.withValues(alpha: 0.08) : AppColors.debit.withValues(alpha: 0.08),
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
                'Financial Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
              ),
              Text(
                isLent ? 'RECEIVABLE (LENT)' : 'PAYABLE (BORROWED)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10.sp,
                  color: isLent ? AppColors.credit : AppColors.debit,
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Opening Principal:', style: TextStyle(fontSize: 12.sp)),
              Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_interestType == InterestType.simple && summary.accruedInterest > 0) ...[
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Accrued Interest to Date:', style: TextStyle(fontSize: 12.sp)),
                Text('₹${summary.accruedInterest.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.orange[800])),
              ],
            ),
          ],
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Initial Total Outstanding:', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
              Text(
                '₹${summary.totalOutstanding.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isLent ? AppColors.credit : AppColors.debit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessAndShareView() {
    final loan = _savedLoan!;
    final contact = _savedContact!;
    final summary = _savedSummary ??
        InterestCalculator.calculateSummary(loan: loan, repayments: [], asOfDate: DateTime.now());
    final isLent = loan.direction == LoanDirection.lent;
    final pdfService = ref.read(directUdharPdfServiceProvider);
    final shareService = ref.read(directUdharShareServiceProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(
              Icons.check_circle_rounded,
              color: AppColors.credit,
              size: 56.w,
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            'Opening Balance Recorded Successfully',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            '${contact.name} • ${isLent ? "Receivable" : "Payable"} ₹${loan.principalAmount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.lg.h),

          // Action Card for Receipt & Sharing
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Share & Acknowledgment',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Generate a PDF receipt or send instant alerts via WhatsApp/SMS.',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: AppSpacing.md.h),

                // Language Selector (FR-NT-003)
                Text(
                  'Message Language',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
                SegmentedButton<ShareLanguage>(
                  segments: const [
                    ButtonSegment(
                      value: ShareLanguage.english,
                      label: Text('English'),
                    ),
                    ButtonSegment(
                      value: ShareLanguage.hindi,
                      label: Text('हिंदी (Hindi)'),
                    ),
                    ButtonSegment(
                      value: ShareLanguage.hinglish,
                      label: Text('Hinglish'),
                    ),
                  ],
                  selected: {_selectedLanguage},
                  onSelectionChanged: (v) {
                    setState(() => _selectedLanguage = v.first);
                  },
                ),
                SizedBox(height: AppSpacing.md.h),

                // View / Share PDF Button
                AppButton(
                  label: _isPdfGenerating ? 'Generating PDF...' : 'View / Print PDF Receipt',
                  icon: Icons.picture_as_pdf_rounded,
                  isLoading: _isPdfGenerating,
                  isFullWidth: true,
                  onPressed: _isPdfGenerating
                      ? null
                      : () async {
                          setState(() => _isPdfGenerating = true);
                          try {
                            final pdfBytes = await pdfService.generateReceiptPdf(
                              loan: loan,
                              contact: contact,
                              summary: summary,
                            );
                            await pdfService.printOrSharePdf(
                              pdfBytes: pdfBytes,
                              filename: 'Opening_Balance_${contact.name.replaceAll(' ', '_')}.pdf',
                            );
                          } catch (e) {
                            if (mounted) {
                              AppSnackbar.showError(context, 'PDF Generation failed: $e');
                            }
                          } finally {
                            if (mounted) setState(() => _isPdfGenerating = false);
                          }
                        },
                ),
                SizedBox(height: AppSpacing.sm.h),

                // Share Complete Ledger Statement
                AppButton(
                  label: 'Share Complete Ledger Statement (PDF)',
                  icon: Icons.share_rounded,
                  variant: AppButtonVariant.secondary,
                  isFullWidth: true,
                  onPressed: () async {
                    final contactRepo = ref.read(contactRepositoryProvider);
                    final directUdharRepo = ref.read(directUdharRepositoryProvider);
                    final shareSvc = ref.read(directUdharShareServiceProvider);
                    await ContactLedgerShareHelper.shareContactHistory(
                      context: context,
                      contactId: contact.id,
                      contactRepository: contactRepo,
                      directUdharRepository: directUdharRepo,
                      shareService: shareSvc,
                    );
                  },
                ),
                SizedBox(height: AppSpacing.sm.h),

                // WhatsApp Sharing Button
                AppButton(
                  label: 'Share via WhatsApp',
                  icon: Icons.chat_rounded,
                  variant: AppButtonVariant.secondary,
                  isFullWidth: true,
                  onPressed: () async {
                    if (contact.mobileNumber.trim().isEmpty) {
                      AppSnackbar.showError(context, 'Contact mobile number is missing');
                      return;
                    }
                    final sent = await shareService.shareViaWhatsApp(
                      loan: loan,
                      contact: contact,
                      summary: summary,
                      language: _selectedLanguage,
                      isOpeningBalance: true,
                    );
                    if (!sent && mounted) {
                      AppSnackbar.showError(context, 'Could not open WhatsApp. Ensure WhatsApp is installed.');
                    }
                  },
                ),
                SizedBox(height: AppSpacing.sm.h),

                // Direct SMS Button
                AppButton(
                  label: 'Send SMS Alert',
                  icon: Icons.sms_rounded,
                  variant: AppButtonVariant.ghost,
                  isFullWidth: true,
                  onPressed: () async {
                    if (contact.mobileNumber.trim().isEmpty) {
                      AppSnackbar.showError(context, 'Contact mobile number is missing');
                      return;
                    }
                    final sent = await shareService.sendSms(
                      loan: loan,
                      contact: contact,
                      summary: summary,
                      language: _selectedLanguage,
                      isOpeningBalance: true,
                    );
                    if (!sent && mounted) {
                      AppSnackbar.showError(context, 'Could not launch SMS application.');
                    }
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),

          // Done Button
          AppButton(
            label: 'Done',
            variant: AppButtonVariant.primary,
            isFullWidth: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(AsyncValue<List<Contact>> contactsAsync) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContactId == null) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final interestRate = _interestType == InterestType.simple
        ? double.tryParse(_interestRateCtrl.text.trim())
        : null;

    final customMemo = _memoCtrl.text.trim();
    final fullMemo = customMemo.isEmpty
        ? '[Opening Balance]'
        : '[Opening Balance] $customMemo';

    final loan = DirectUdharLoan(
      id: '',
      contactId: _selectedContactId!,
      direction: _direction,
      principalAmount: amount,
      interestType: _interestType,
      interestRatePercent: interestRate,
      dueDate: null,
      memo: fullMemo,
      status: LoanStatus.open,
      outstandingBalance: amount,
      createdAt: _openingDate,
      updatedAt: DateTime.now(),
    );

    final notifier = ref.read(directUdharFormNotifierProvider.notifier);
    final success = await notifier.createLoan(loan);

    if (success && mounted) {
      final contacts = contactsAsync.valueOrNull ?? [];
      final contact = contacts.firstWhere(
        (c) => c.id == _selectedContactId,
        orElse: () => Contact(
          id: _selectedContactId!,
          type: ContactType.buyer,
          name: 'Contact',
          mobileNumber: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final summary = InterestCalculator.calculateSummary(
        loan: loan,
        repayments: [],
        asOfDate: DateTime.now(),
      );

      setState(() {
        _isSaved = true;
        _savedLoan = loan;
        _savedContact = contact;
        _savedSummary = summary;
      });
    }
  }
}
