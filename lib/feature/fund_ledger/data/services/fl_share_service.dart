import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/fl_share_statement.dart';
import 'fl_pdf_service.dart';

/// Orchestrates PDF generation and system share sheet for Fund Ledger.
///
/// Reuses the same file-write + share_plus pattern as the existing
/// DirectUdharShareService to maintain consistency.
class FLShareService {
  const FLShareService({
    this.pdfService = const FLPdfService(),
  });

  final FLPdfService pdfService;

  String statementText(FLShareStatement statement) {
    final buffer = StringBuffer()
      ..writeln('PAMZ Hisab - Fund Ledger Statement')
      ..writeln('Contact: ${statement.contactName}')
      ..writeln('Mobile: ${statement.mobileNumber}');

    if (statement.aadhaarNumber != null) {
      buffer.writeln('Aadhaar: ${statement.aadhaarNumber}');
    }

    buffer
      ..writeln(
          'Total Received: Rs. ${statement.totalReceived.toStringAsFixed(2)}')
      ..writeln(
          'Total Returned: Rs. ${statement.totalReturned.toStringAsFixed(2)}')
      ..writeln(
          'Available Balance: Rs. ${statement.availableBalance.toStringAsFixed(2)}');

    final latest = statement.latestTodayTransaction;
    if (latest != null) {
      buffer.writeln(
          'Last Transaction Today: ${latest.type} - Rs. ${latest.amount.toStringAsFixed(2)} on ${latest.date}');
    }

    buffer.writeln();
    buffer.writeln('Received:');
    for (final entry in statement.receivedEntries) {
      buffer.writeln(
        '- ${entry.date}: Rs. ${entry.amount.toStringAsFixed(2)} (${entry.paymentMode ?? 'Cash'})',
      );
    }

    buffer.writeln();
    buffer.writeln('Returned:');
    for (final entry in statement.returnedEntries) {
      buffer.writeln(
        '- ${entry.date}: Rs. ${entry.amount.toStringAsFixed(2)} (${entry.paymentMode ?? 'Cash'})',
      );
    }

    return buffer.toString().trim();
  }

  Future<bool> shareStatementText(FLShareStatement statement) async {
    try {
      // Keep the whole statement in the text payload. Some targets treat the
      // optional subject as the message and omit the actual body.
      final result = await Share.share(statementText(statement));
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('[FLShareService] text share error: $e');
      return false;
    }
  }

  Future<bool> shareToWhatsApp(FLShareStatement statement) async {
    final uri = Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(statementText(statement))}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> shareToSms(FLShareStatement statement) async {
    final uri =
        Uri.parse('sms:?body=${Uri.encodeComponent(statementText(statement))}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Generates a PDF and launches the system share sheet.
  /// Returns true on success, false on failure.
  Future<bool> shareStatement(FLShareStatement statement) async {
    try {
      final bytes = await pdfService.generate(statement);

      if (kIsWeb) {
        // Web: use Printing or direct download
        return await _shareWeb(bytes, statement.contactName);
      } else {
        return await _shareNative(bytes, statement.contactName);
      }
    } catch (e) {
      debugPrint('[FLShareService] share error: $e');
      return false;
    }
  }

  Future<bool> _shareNative(Uint8List bytes, String contactName) async {
    try {
      final dir = await getTemporaryDirectory();
      final safeContact = contactName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = 'fl_statement_$safeContact.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Fund Ledger Statement — $contactName',
        text: 'Attached is the Fund Ledger statement for $contactName.',
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('[FLShareService] native share error: $e');
      return false;
    }
  }

  Future<bool> _shareWeb(Uint8List bytes, String contactName) async {
    try {
      final safeContact = contactName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = 'fl_statement_$safeContact.pdf';
      // On web, XFile from bytes works with share_plus
      final xFile = XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/pdf',
      );
      final result = await Share.shareXFiles([xFile]);
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('[FLShareService] web share error: $e');
      return false;
    }
  }
}
