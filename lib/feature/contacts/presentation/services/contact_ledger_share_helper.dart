import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../direct_udhar/data/services/direct_udhar_share_service.dart';
import '../../../direct_udhar/domain/entities/direct_udhar_loan.dart';
import '../../../direct_udhar/domain/repositories/direct_udhar_repository.dart';
import '../../../direct_udhar/presentation/providers/direct_udhar_providers.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/services/contact_statement_builder.dart';
import '../providers/contact_providers.dart';

/// Helper to generate and share the complete updated contact ledger history
/// and to prompt users with the post-transaction share popup.
abstract final class ContactLedgerShareHelper {
  ContactLedgerShareHelper._();

  /// Shares the freshly updated itemized statement for [contactId].
  /// Accepts either pre-resolved repository dependencies (lifecycle-safe across widget disposal)
  /// or a live [WidgetRef].
  static Future<void> shareContactHistory({
    required BuildContext context,
    required String contactId,
    WidgetRef? ref,
    ContactRepository? contactRepository,
    DirectUdharRepository? directUdharRepository,
    DirectUdharShareService? shareService,
  }) async {
    try {
      final contactRepo = contactRepository ?? ref?.read(contactRepositoryProvider);
      final directUdharRepo = directUdharRepository ?? ref?.read(directUdharRepositoryProvider);
      final shareSvc = shareService ?? ref?.read(directUdharShareServiceProvider) ?? const DirectUdharShareService();

      if (contactRepo == null || directUdharRepo == null) {
        if (context.mounted) {
          AppSnackbar.showError(context, 'Statement dependencies are not available.');
        }
        return;
      }

      // 1. Fetch contact directly from repository to avoid stale state
      final contactRes = await contactRepo.findById(contactId);
      final contact = contactRes.getOrElse((_) => null);
      if (contact == null) {
        if (context.mounted) {
          AppSnackbar.showError(context, 'Contact not found.');
        }
        return;
      }

      // 2. Fetch fresh loans from repository
      final loansRes = await directUdharRepo.getByContact(contactId);
      final loans = loansRes.getOrElse((_) => []);

      // 3. Fetch fresh repayments for each loan
      final repaymentsMap = <String, List<Repayment>>{};
      for (final loan in loans) {
        final repRes = await directUdharRepo.getRepayments(loan.id);
        repaymentsMap[loan.id] = repRes.getOrElse((_) => []);
      }

      // 4. Build complete itemized ledger statement
      final statement = ContactStatementBuilder.build(
        contact: contact,
        loans: loans,
        loanRepayments: repaymentsMap,
      );

      // 5. Empty history check
      if (statement.items.isEmpty) {
        if (context.mounted) {
          AppSnackbar.showInfo(
            context,
            'No transaction history available to share.',
          );
        }
        return;
      }

      // 6. Share statement PDF with summary
      final success = await shareSvc.shareStatementPdfWithSummary(
        statement: statement,
      );

      if (!success && context.mounted) {
        AppSnackbar.showError(
          context,
          'Could not launch share sheet. Please try again.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'Failed to generate statement: $e');
      }
    }
  }

  /// Shows the post-transaction share popup after successful persistence.
  static Future<void> showPostTransactionShareDialog({
    required BuildContext context,
    required String contactId,
    WidgetRef? ref,
    ContactRepository? contactRepository,
    DirectUdharRepository? directUdharRepository,
    DirectUdharShareService? shareService,
  }) async {
    final shouldShare = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AppDialog(
        title: 'Transaction Saved',
        content:
            'The transaction has been saved. Would you like to share the updated ledger statement?',
        actions: [
          AppButton(
            label: 'Not Now',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(dialogCtx).pop(false),
          ),
          SizedBox(width: AppSpacing.sm.w),
          AppButton(
            label: 'Share History',
            icon: Icons.share_rounded,
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(dialogCtx).pop(true),
          ),
        ],
      ),
    );

    if (shouldShare == true && context.mounted) {
      await shareContactHistory(
        context: context,
        contactId: contactId,
        ref: ref,
        contactRepository: contactRepository,
        directUdharRepository: directUdharRepository,
        shareService: shareService,
      );
    }
  }
}
