import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/fl_share_statement.dart';
import '../../domain/entities/fl_transaction.dart';
import '../providers/fl_contact_providers.dart';
import '../providers/fl_transaction_providers.dart';
import '../widgets/fl_contact_detail_header.dart';
import '../widgets/fl_transaction_history.dart';
import 'fl_contact_form_screen.dart';

/// Comprehensive detail screen for a Fund Ledger contact showing balance,
/// action buttons, statement export, and transaction history.
class FLContactDetailScreen extends ConsumerStatefulWidget {
  const FLContactDetailScreen({
    super.key,
    required this.contactId,
  });

  final String contactId;

  @override
  ConsumerState<FLContactDetailScreen> createState() => _FLContactDetailScreenState();
}

class _FLContactDetailScreenState extends ConsumerState<FLContactDetailScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final contactAsync = ref.watch(flContactByIdProvider(widget.contactId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: contactAsync.when(
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Contact Details'),
          data: (contact) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact?.name ?? 'Contact Details',
                style: AppTextStyles.h2.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              if (contact?.mobileNumber.isNotEmpty == true)
                Text(
                  contact!.mobileNumber,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          // Export / Share Statement PDF
          IconButton(
            icon: _isExporting
                ? SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF Statement',
            onPressed: _isExporting ? null : _exportStatement,
          ),
          // Edit Contact
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Contact',
            onPressed: () {
              final contact = contactAsync.asData?.value;
              if (contact != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FLContactFormScreen(contact: contact),
                  ),
                );
              }
            },
          ),
          // Delete Contact
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'delete') _confirmDeleteContact();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Contact', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(flContactByIdProvider(widget.contactId));
            ref.invalidate(flContactSummaryProvider(widget.contactId));
            ref.invalidate(flTransactionHistoryProvider(widget.contactId));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Summary Card
                FLContactDetailHeader(contactId: widget.contactId),
                SizedBox(height: AppSpacing.sm.h),
                // Transaction History
                FLTransactionHistory(contactId: widget.contactId),
                SizedBox(height: AppSpacing.xxl.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportStatement() async {
    setState(() => _isExporting = true);
    try {
      final contact = ref.read(flContactByIdProvider(widget.contactId)).asData?.value;
      final summary = ref.read(flContactSummaryProvider(widget.contactId)).asData?.value;
      final transactions =
          ref.read(flTransactionHistoryProvider(widget.contactId)).asData?.value ?? [];

      if (contact == null || summary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to generate statement: data missing')),
          );
        }
        return;
      }

      final shareStatement = FLShareStatement(
        contactName: contact.name,
        mobileNumber: contact.mobileNumber,
        aadhaarNumber: contact.aadhaarNumber,
        receivedEntries: transactions
            .where((t) => t.type == FLTransactionType.received)
            .map((t) => FLShareEntry(
                  date: t.txnDate,
                  amount: t.amount,
                  paymentMode: t.paymentMode,
                  paymentReference: t.paymentReference,
                ))
            .toList(),
        returnedEntries: transactions
            .where((t) => t.type == FLTransactionType.returned)
            .map((t) => FLShareEntry(
                  date: t.txnDate,
                  amount: t.amount,
                  paymentMode: t.paymentMode,
                  paymentReference: t.paymentReference,
                ))
            .toList(),
      );

      final shareService = ref.read(flShareServiceProvider);
      final success = await shareService.shareStatement(shareStatement);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share statement'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export statement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _confirmDeleteContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: const Text(
          'Are you sure you want to delete this contact? This will remove the contact from your list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(flContactFormNotifierProvider.notifier)
          .deleteContact(widget.contactId);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete contact'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
