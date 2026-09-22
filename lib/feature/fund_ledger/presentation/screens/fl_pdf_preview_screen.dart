import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/fl_pdf_download.dart';
import '../../data/services/fl_pdf_service.dart';
import '../../domain/entities/fl_contact.dart';
import '../../domain/entities/fl_share_statement.dart';
import '../../domain/entities/fl_transaction.dart';
import '../widgets/fl_text_share_preview.dart';
import '../../data/services/fl_share_service.dart';

class FLPdfPreviewScreen extends StatelessWidget {
  const FLPdfPreviewScreen({
    super.key,
    required this.statement,
  });

  final FLShareStatement statement;

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final fileName =
          'fl_statement_${statement.contactName.replaceAll(RegExp(r'[^\w\s-]'), '_')}.pdf';
      final bytes = await const FLPdfService().generate(statement);
      final savedPath = await downloadPdf(bytes, fileName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF downloaded: ${savedPath ?? fileName}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not download PDF: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statement Preview'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.onPrimary,
      ),
      body: PdfPreview(
        useActions: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'fl_statement_${statement.contactName}.pdf',
        build: (format) => const FLPdfService().generate(statement),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => _downloadPdf(context),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share Statement Text'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: () => showFLTextSharePreview(
                context,
                statement: statement,
                shareService: const FLShareService(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showFLPdfPreviewFromFutures(
  BuildContext context, {
  required Future<FLContact?> contactFuture,
  required Future<List<FLTransaction>> txnsFuture,
}) async {
  final contact = await contactFuture;
  if (contact == null || !context.mounted) return;
  final txns = await txnsFuture;
  if (!context.mounted) return;

  final statement = FLShareStatement(
    contactName: contact.name,
    mobileNumber: contact.mobileNumber,
    aadhaarNumber: contact.aadhaarNumber,
    receivedEntries: txns
        .where((t) => t.type == FLTransactionType.received)
        .map((t) => FLShareEntry(
              date: t.txnDate,
              amount: t.amount,
              type: 'Received',
              createdAt: t.createdAt.toIso8601String(),
              paymentMode: t.paymentMode,
              paymentReference: t.paymentReference,
            ))
        .toList(),
    returnedEntries: txns
        .where((t) => t.type == FLTransactionType.returned)
        .map((t) => FLShareEntry(
              date: t.txnDate,
              amount: t.amount,
              type: 'Returned',
              createdAt: t.createdAt.toIso8601String(),
              paymentMode: t.paymentMode,
              paymentReference: t.paymentReference,
            ))
        .toList(),
  );

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FLPdfPreviewScreen(statement: statement),
    ),
  );
}
