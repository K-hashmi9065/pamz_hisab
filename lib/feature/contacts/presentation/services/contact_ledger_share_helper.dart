import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../domain/repositories/contact_repository.dart';

/// Helper to generate and share the complete updated contact ledger history
/// and to prompt users with the post-transaction share popup.
///
/// NOTE: The Direct Udhar PDF share workflow has been retired. Sharing now
/// shows a placeholder message. Full ledger statements are available through
/// the Fund Ledger feature.
abstract final class ContactLedgerShareHelper {
  ContactLedgerShareHelper._();

  /// Shares the freshly updated itemized statement for [contactId].
  static Future<void> shareContactHistory({
    required BuildContext context,
    required String contactId,
    WidgetRef? ref,
    ContactRepository? contactRepository,
  }) async {
    if (context.mounted) {
      AppSnackbar.showInfo(
        context,
        'Statement sharing is now available through the Fund Ledger feature.',
      );
    }
  }

  /// Shows the post-transaction share popup after successful persistence.
  static Future<void> showPostTransactionShareDialog({
    required BuildContext context,
    required String contactId,
    WidgetRef? ref,
    ContactRepository? contactRepository,
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
      );
    }
  }
}
