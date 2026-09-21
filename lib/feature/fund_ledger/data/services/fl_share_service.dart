import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
