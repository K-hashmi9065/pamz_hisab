import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../direct_udhar/domain/entities/direct_udhar_loan.dart';
import '../../../direct_udhar/presentation/providers/direct_udhar_providers.dart';
import '../../../direct_udhar/presentation/widgets/direct_udhar_form_sheet.dart';
import '../../../direct_udhar/presentation/widgets/opening_balance_form_sheet.dart';
import '../../../direct_udhar/presentation/widgets/repayment_form_sheet.dart';
import '../../domain/entities/contact.dart';
import '../../domain/services/contact_statement_builder.dart';
import '../providers/contact_providers.dart';
import 'contact_form_screen.dart';

/// Detail screen for a Contact (Buyer or Supplier).
/// Displays profile attributes, current balance, active Direct Udhar entries,
/// and Edit/Delete CRUD actions.
class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({
    super.key,
    required this.contactId,
    this.isMasterDetail = false,
    this.onDeleted,
  });

  final String contactId;
  final bool isMasterDetail;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactAsync = ref.watch(contactByIdProvider(contactId));
    final balanceAsync = ref.watch(contactTotalBalanceProvider(contactId));
    final loansAsync = ref.watch(loansByContactProvider(contactId));

    return contactAsync.when(
      loading: () => const Scaffold(body: AppLoader(message: 'Loading contact details...')),
      error: (e, _) => Scaffold(
        appBar: CustomAppBar(
          title: 'Contact Details',
          leading: isMasterDetail ? const SizedBox.shrink() : null,
        ),
        body: AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(contactByIdProvider(contactId)),
        ),
      ),
      data: (contact) {
        if (contact == null || contact.isDeleted) {
          return Scaffold(
            appBar: CustomAppBar(
              title: 'Contact Details',
              leading: isMasterDetail ? const SizedBox.shrink() : null,
            ),
            body: AppEmptyState(
              title: 'Contact Not Found',
              subtitle: 'This contact may have been deleted.',
              actionLabel: isMasterDetail ? null : 'Go Back',
              onAction: isMasterDetail ? null : () => context.pop(),
            ),
          );
        }

        return Scaffold(
          appBar: CustomAppBar(
            title: contact.name,
            leading: isMasterDetail ? const SizedBox.shrink() : null,
            actions: [
              IconButton(
                key: const Key('shareStatementButton'),
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share Ledger Statement (WhatsApp/PDF)',
                onPressed: () => _shareStatement(context, ref, contact),
              ),
              IconButton(
                key: const Key('editContactButton'),
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit Profile',
                onPressed: () => _openEditForm(context, contact),
              ),
              IconButton(
                key: const Key('deleteContactButton'),
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.debit),
                tooltip: 'Delete Contact',
                onPressed: () => _confirmDelete(context, ref, contact),
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            children: [
              // Header Card with Profile Info & Balance
              _buildProfileCard(context, contact, balanceAsync),
              SizedBox(height: AppSpacing.lg.h),

              // Actions Row: Record Udhar / Set Opening Balance / Share Statement
              _buildActionButtons(context, ref, contact),
              SizedBox(height: AppSpacing.xl.h),

              // Direct Udhar Transactions Section
              Text(
                'Direct Udhar & Opening Balances',
                style: AppTextStyles.h3,
              ),
              SizedBox(height: AppSpacing.sm.h),
              loansAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading transactions: $e', style: AppTextStyles.caption),
                data: (loans) {
                  final activeLoans = loans.where((l) => !l.isDeleted).toList();
                  if (activeLoans.isEmpty) {
                    return AppCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 36.w, color: AppColors.textDisabled),
                              SizedBox(height: AppSpacing.xs.h),
                              Text(
                                'No loan or opening balance records found.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
                  final dateFormatter = DateFormat('dd MMM yyyy');

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeLoans.length,
                    separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm.h),
                    itemBuilder: (_, i) {
                      final loan = activeLoans[i];
                      final isLent = loan.direction == LoanDirection.lent;
                      final isOpening = loan.memo != null && loan.memo!.contains('[Opening Balance]');

                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isLent ? AppColors.creditLight : AppColors.debitLight,
                            child: Icon(
                              isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              color: isLent ? AppColors.credit : AppColors.debit,
                            ),
                          ),
                          title: Text(
                            isOpening ? 'Opening Balance' : (isLent ? 'Udhar Given' : 'Udhar Taken'),
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${dateFormatter.format(loan.createdAt)} • ${loan.interestType == InterestType.simple ? "Simple Interest (${loan.interestRatePercent}%/mo)" : "Interest-Free"}',
                            style: AppTextStyles.caption,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormatter.format(loan.outstandingBalance),
                                    style: AppTextStyles.amount.copyWith(
                                      fontSize: 14.sp,
                                      color: isLent ? AppColors.credit : AppColors.debit,
                                    ),
                                  ),
                                  Text(
                                    loan.status == LoanStatus.closed
                                        ? 'CLOSED'
                                        : (loan.status == LoanStatus.partiallyPaid
                                            ? 'PARTIALLY PAID'
                                            : 'OPEN'),
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                      color: loan.status == LoanStatus.closed
                                          ? AppColors.credit
                                          : (loan.status == LoanStatus.partiallyPaid
                                              ? AppColors.warningText
                                              : AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                              if (loan.outstandingBalance > 0) ...[
                                SizedBox(width: AppSpacing.xs.w),
                                IconButton(
                                  icon: const Icon(Icons.payments_outlined, color: AppColors.primary),
                                  tooltip: 'Record Repayment (Jama)',
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => RepaymentFormSheet(
                                        contact: contact,
                                        initialLoan: loan,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, Contact contact, AsyncValue<double> balanceAsync) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28.r,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: AppTextStyles.h1.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: AppTextStyles.h2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: contact.isBuyer ? Colors.blue.withValues(alpha: 0.12) : Colors.purple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            contact.type.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: contact.isBuyer ? Colors.blue[800] : Colors.purple[800],
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          contact.mobileNumber,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Balance Display
          balanceAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error computing balance'),
            data: (balance) {
              final isPositive = balance >= 0;
              return Container(
                padding: EdgeInsets.all(AppSpacing.md.w),
                decoration: BoxDecoration(
                  color: isPositive ? AppColors.creditLight : AppColors.debitLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                  border: Border.all(
                    color: (isPositive ? AppColors.credit : AppColors.debit).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPositive ? 'Net Balance (Receivable)' : 'Net Balance (Payable)',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                          SizedBox(height: 2.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              currencyFormatter.format(balance.abs()),
                              style: AppTextStyles.amountLarge.copyWith(
                                color: isPositive ? AppColors.credit : AppColors.debit,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: isPositive ? AppColors.credit : AppColors.debit,
                      size: 28.w,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: AppSpacing.md.h),

          // Buyer/Supplier specific profile metadata
          if (contact.isBuyer) ...[
            if (contact.address != null && contact.address!.isNotEmpty)
              _buildInfoRow(Icons.location_on_outlined, 'Address', contact.address!),
            if (contact.villageTola != null && contact.villageTola!.isNotEmpty)
              _buildInfoRow(Icons.holiday_village_outlined, 'Village / Tola', contact.villageTola!),
            if (contact.creditLimit > 0)
              _buildInfoRow(Icons.credit_card_rounded, 'Credit Limit', currencyFormatter.format(contact.creditLimit)),
          ],
          if (contact.isSupplier) ...[
            if (contact.shopLocation != null && contact.shopLocation!.isNotEmpty)
              _buildInfoRow(Icons.store_outlined, 'Shop Location', contact.shopLocation!),
            _buildInfoRow(
              Icons.notifications_active_outlined,
              'Due Date Alerts',
              contact.dueDateAlertEnabled ? 'Enabled' : 'Disabled',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.w, color: AppColors.textSecondary),
          SizedBox(width: 8.w),
          Text('$label: ', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Contact contact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;

        final btnUdhar = AppButton(
          label: 'Give / Take Udhar',
          icon: Icons.add_circle_outline_rounded,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => DirectUdharFormSheet(targetContactId: contact.id),
            );
          },
        );

        final btnJama = AppButton(
          key: const Key('recordRepaymentButton'),
          label: 'Record Jama',
          icon: Icons.payments_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => RepaymentFormSheet(contact: contact),
            );
          },
        );

        final btnOpening = AppButton(
          label: 'Opening Bal',
          icon: Icons.account_balance_wallet_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => OpeningBalanceFormSheet(targetContactId: contact.id),
            );
          },
        );

        final btnShare = AppButton(
          key: const Key('shareStatementFullButton'),
          label: 'Share Ledger Statement (WhatsApp / PDF)',
          icon: Icons.picture_as_pdf_rounded,
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: () => _shareStatement(context, ref, contact),
        );

        if (isWide) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: btnUdhar),
                  SizedBox(width: AppSpacing.sm.w),
                  Expanded(child: btnJama),
                  SizedBox(width: AppSpacing.sm.w),
                  Expanded(child: btnOpening),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),
              btnShare,
            ],
          );
        }

        // Responsive arrangement on narrower widths
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: btnUdhar),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(child: btnJama),
              ],
            ),
            SizedBox(height: AppSpacing.sm.h),
            Row(
              children: [
                Expanded(child: btnOpening),
              ],
            ),
            SizedBox(height: AppSpacing.sm.h),
            btnShare,
          ],
        );
      },
    );
  }

  Future<void> _shareStatement(BuildContext context, WidgetRef ref, Contact contact) async {
    try {
      final loansRes = await ref.read(directUdharRepositoryProvider).getByContact(contact.id);
      final loans = loansRes.getOrElse((_) => []);

      final repaymentsMap = <String, List<Repayment>>{};
      for (final loan in loans) {
        final repRes = await ref.read(directUdharRepositoryProvider).getRepayments(loan.id);
        repaymentsMap[loan.id] = repRes.getOrElse((_) => []);
      }

      final statement = ContactStatementBuilder.build(
        contact: contact,
        loans: loans,
        loanRepayments: repaymentsMap,
      );

      final shareService = ref.read(directUdharShareServiceProvider);
      final success = await shareService.shareStatementPdfWithSummary(
        statement: statement,
      );

      if (!success && context.mounted) {
        AppSnackbar.showError(context, 'Could not launch share sheet. Please try again.');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'Failed to generate statement: $e');
      }
    }
  }

  void _openEditForm(BuildContext context, Contact contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ContactFormScreen(existingContact: contact),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Contact contact) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete ${contact.name}? Previous financial records will be preserved in audit logs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirmDeleteButton'),
            style: TextButton.styleFrom(foregroundColor: AppColors.debit),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final notifier = ref.read(contactFormNotifierProvider.notifier);
              final success = await notifier.deleteContact(contact.id);
              if (success && context.mounted) {
                if (isMasterDetail) {
                  onDeleted?.call();
                } else {
                  context.pop();
                }
                AppSnackbar.showSuccess(context, 'Contact deleted');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
