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
import '../providers/contact_providers.dart';
import '../services/contact_ledger_share_helper.dart';
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
    final statementAsync = ref.watch(contactStatementProvider(contactId));

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

        final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
        final dateFormatter = DateFormat('dd MMM yyyy');

        return Scaffold(
          appBar: CustomAppBar(
            title: contact.name,
            leading: isMasterDetail ? const SizedBox.shrink() : null,
            actions: [
              IconButton(
                key: const Key('shareStatementButton'),
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share History',
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

              // Active Open Loans Section (if any open loans exist)
              loansAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (loans) {
                  final openLoans = loans
                      .where((l) => !l.isDeleted && l.status != LoanStatus.closed && l.outstandingBalance > 0)
                      .toList();
                  if (openLoans.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Active / Open Udhar', style: AppTextStyles.h3),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '${openLoans.length} active',
                              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.warningText),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: openLoans.length,
                        separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm.h),
                        itemBuilder: (_, i) {
                          final loan = openLoans[i];
                          final isLent = loan.direction == LoanDirection.lent;
                          final isOpening = loan.memo != null && loan.memo!.contains('[Opening Balance]');
                          final cleanMemo = loan.memo?.replaceAll('[Opening Balance]', '').trim();
                          final hasCustomMemo = cleanMemo != null && cleanMemo.isNotEmpty;
                          final interestInfo = loan.interestType == InterestType.simple
                              ? "Simple (${loan.interestRatePercent}%/mo)"
                              : "Interest-Free";

                          final totalPrincipal = loan.principalAmount;
                          final remainingBalance = loan.outstandingBalance;
                          final totalPaid = (totalPrincipal - remainingBalance).clamp(0.0, double.infinity);

                          final cardTitle = hasCustomMemo
                              ? cleanMemo
                              : (isOpening ? 'Opening Balance' : (isLent ? 'Udhar Given' : 'Udhar Taken'));
                          final cardSubtitle = hasCustomMemo
                              ? '${isOpening ? "Opening Balance" : (isLent ? "Udhar Given" : "Udhar Taken")} • ${dateFormatter.format(loan.createdAt)} • $interestInfo'
                              : '${dateFormatter.format(loan.createdAt)} • $interestInfo';

                          return AppCard(
                            padding: EdgeInsets.all(AppSpacing.md.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18.r,
                                      backgroundColor: isLent ? AppColors.debitLight : AppColors.creditLight,
                                      child: Icon(
                                        isLent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                        color: isLent ? AppColors.debit : AppColors.credit,
                                        size: 20.r,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cardTitle,
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.sp,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            cardSubtitle,
                                            style: AppTextStyles.caption.copyWith(
                                              fontSize: 11.sp,
                                              color: AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          currencyFormatter.format(loan.outstandingBalance),
                                          style: AppTextStyles.amount.copyWith(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.bold,
                                            color: isLent ? AppColors.debit : AppColors.credit,
                                          ),
                                        ),
                                        Container(
                                          margin: EdgeInsets.only(top: 2.h),
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                                          decoration: BoxDecoration(
                                            color: (loan.status == LoanStatus.closed ? AppColors.credit : AppColors.primary).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4.r),
                                          ),
                                          child: Text(
                                            loan.status == LoanStatus.closed ? 'CLOSED' : 'OPEN',
                                            style: TextStyle(
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w800,
                                              color: loan.status == LoanStatus.closed ? AppColors.credit : AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 4.w),
                                    IconButton(
                                      icon: const Icon(Icons.payments_outlined, color: AppColors.primary),
                                      tooltip: 'Record Repayment (Jama)',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
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
                                ),
                                SizedBox(height: 10.h),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.grey.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isLent ? 'Total Lent' : 'Total Borrowed',
                                            style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                          ),
                                          SizedBox(height: 1.h),
                                          Text(
                                            currencyFormatter.format(totalPrincipal),
                                            style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                      Container(width: 1, height: 22.h, color: Colors.grey.withValues(alpha: 0.25)),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Paid',
                                            style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                          ),
                                          SizedBox(height: 1.h),
                                          Text(
                                            currencyFormatter.format(totalPaid),
                                            style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w600, color: AppColors.credit),
                                          ),
                                        ],
                                      ),
                                      Container(width: 1, height: 22.h, color: Colors.grey.withValues(alpha: 0.25)),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Remaining (To Pay)',
                                            style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                          ),
                                          SizedBox(height: 1.h),
                                          Text(
                                            currencyFormatter.format(remainingBalance),
                                            style: TextStyle(
                                              fontSize: 11.5.sp,
                                              fontWeight: FontWeight.bold,
                                              color: isLent ? AppColors.debit : AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(height: AppSpacing.xl.h),
                    ],
                  );
                },
              ),

              // Full Transaction History & Ledger Timeline Section
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 450;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transaction History & Ledger',
                              style: AppTextStyles.h3,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Newest first',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm.w),
                      AppButton(
                        key: const Key('shareStatementFullButton'),
                        label: isCompact ? 'Share' : 'Share History',
                        icon: Icons.share_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _shareStatement(context, ref, contact),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: AppSpacing.sm.h),
              statementAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading history: $e', style: AppTextStyles.caption),
                data: (statement) {
                  final items = statement?.items ?? [];
                  if (items.isEmpty) {
                    return AppCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded, size: 36.w, color: AppColors.textDisabled),
                              SizedBox(height: AppSpacing.xs.h),
                              Text(
                                'No historical transactions recorded yet.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Display chronological entries in newest-first order
                  final historyItems = items.reversed.toList();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: historyItems.length,
                    separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm.h),
                    itemBuilder: (_, i) {
                      final item = historyItems[i];
                      final isRepayment = item.type == 'repayment';
                      final isOpening = item.type == 'opening_balance';

                      final Color iconColor;
                      final IconData iconData;
                      final Color amountColor;
                      final String amountPrefix;

                      if (isOpening) {
                        iconColor = Colors.indigo;
                        iconData = Icons.account_balance_wallet_outlined;
                        amountColor = Colors.indigo;
                        amountPrefix = '';
                      } else if (isRepayment) {
                        iconColor = AppColors.credit;
                        iconData = Icons.payments_rounded;
                        amountColor = AppColors.credit;
                        amountPrefix = '+';
                      } else {
                        iconColor = AppColors.debit;
                        iconData = item.type == 'loan_lent'
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded;
                        amountColor = AppColors.debit;
                        amountPrefix = '-';
                      }

                      final amount = item.debit > 0 ? item.debit : item.credit;
                      final double bal = item.runningBalance;
                      final String balLabel;
                      final Color balColor;

                      if (contact.isBuyer) {
                        if (bal >= 0) {
                          balLabel = 'Bal: ${currencyFormatter.format(bal)} Rec';
                          balColor = AppColors.credit;
                        } else {
                          balLabel = 'Bal: ${currencyFormatter.format(bal.abs())} Adv';
                          balColor = AppColors.warningText;
                        }
                      } else {
                        // Supplier: negative runningBalance indicates Payable (Dene Baaki)
                        if (bal <= 0) {
                          balLabel = 'Bal: ${currencyFormatter.format(bal.abs())} Pay';
                          balColor = AppColors.debit;
                        } else {
                          balLabel = 'Bal: ${currencyFormatter.format(bal)} Adv';
                          balColor = AppColors.credit;
                        }
                      }

                      final iconBgColor = iconColor.withValues(alpha: 0.12);

                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: 4.h),
                          leading: CircleAvatar(
                            backgroundColor: iconBgColor,
                            child: Icon(iconData, color: iconColor, size: 20.r),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.description,
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                '$amountPrefix${currencyFormatter.format(amount)}',
                                style: AppTextStyles.amount.copyWith(
                                  fontSize: 14.sp,
                                  color: amountColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 2.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateFormatter.format(item.date),
                                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    balLabel,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: balColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.interestDetails != null && item.interestDetails!.isNotEmpty) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  item.interestDetails!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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

        if (isWide) {
          return Row(
            children: [
              Expanded(child: btnUdhar),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(child: btnJama),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(child: btnOpening),
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
          ],
        );
      },
    );
  }

  Future<void> _shareStatement(BuildContext context, WidgetRef ref, Contact contact) async {
    await ContactLedgerShareHelper.shareContactHistory(
      context: context,
      ref: ref,
      contactId: contact.id,
    );
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
