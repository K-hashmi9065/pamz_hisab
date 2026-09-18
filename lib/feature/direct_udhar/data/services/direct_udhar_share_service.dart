import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/domain/entities/contact_ledger_statement.dart';
import '../../../notifications/data/repositories/notification_template_repository.dart';
import '../../domain/entities/direct_udhar_loan.dart';
import '../../domain/services/interest_calculator.dart';
import 'direct_udhar_pdf_service.dart';

/// Message templates and dispatch service for WhatsApp and SMS.
enum ShareLanguage { english, hindi, hinglish }

class DirectUdharShareService {
  const DirectUdharShareService({
    this.pdfService = const DirectUdharPdfService(),
    this.templateRepository = const NotificationTemplateRepository(),
  });

  final DirectUdharPdfService pdfService;
  final NotificationTemplateRepository templateRepository;

  /// Builds the formatted summary text for a single loan/voucher in English, Hindi, or Hinglish.
  String buildMessageText({
    required DirectUdharLoan loan,
    required Contact contact,
    LoanFinancialSummary? summary,
    ShareLanguage language = ShareLanguage.english,
    bool isOpeningBalance = true,
  }) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final formattedAmount = currencyFormatter.format(loan.principalAmount);
    final formattedTotal = currencyFormatter.format(summary?.totalOutstanding ?? loan.outstandingBalance);
    final formattedDate = dateFormatter.format(loan.createdAt);
    final isLent = loan.direction == LoanDirection.lent;

    final interestInfo = loan.interestType == InterestType.simple
        ? 'Simple Interest (${loan.interestRatePercent}%/mo)'
        : 'Interest-Free';

    switch (language) {
      case ShareLanguage.hindi:
        final directionText = isLent ? 'दिया गया (Lent)' : 'लिया गया (Borrowed)';
        final title = isOpeningBalance ? 'शुरुआती शेष (Opening Balance)' : 'उधार पर्ची (Udhar)';
        return '''*PAMZ Hisab - $title*
नमस्ते ${contact.name} जी,
खाता विवरण:
• राशि: $formattedAmount ($directionText)
• ब्याज दर: $interestInfo
• दिनांक: $formattedDate
• कुल बकाया: $formattedTotal
${loan.memo != null ? '• नोट: ${loan.memo}\n' : ''}
धन्यवाद,
PAMZ Hisab''';

      case ShareLanguage.hinglish:
        final directionText = isLent ? 'Diya gaya (Lent)' : 'Liya gaya (Borrowed)';
        final title = isOpeningBalance ? 'Opening Balance Update' : 'Udhar Entry';
        return '''*PAMZ Hisab - $title*
Namaste ${contact.name} ji,
Aapke khata ki details:
• Amount: $formattedAmount ($directionText)
• Byaj (Interest): $interestInfo
• Date: $formattedDate
• Total Outstanding: $formattedTotal
${loan.memo != null ? '• Memo: ${loan.memo}\n' : ''}
Shukriya,
PAMZ Hisab''';

      case ShareLanguage.english:
        final directionText = isLent ? 'Lent (Receivable)' : 'Borrowed (Payable)';
        final title = isOpeningBalance ? 'Opening Balance Acknowledgment' : 'Direct Udhar Voucher';
        return '''*PAMZ Hisab - $title*
Dear ${contact.name},
Your account entry details:
• Amount: $formattedAmount ($directionText)
• Interest: $interestInfo
• Date: $formattedDate
• Total Outstanding: $formattedTotal
${loan.memo != null ? '• Note: ${loan.memo}\n' : ''}
Thank you,
PAMZ Hisab''';
    }
  }

  /// Builds personalized statement summary text for WhatsApp/SMS in English, Hindi, or Hinglish.
  String buildStatementMessageText({
    required ContactLedgerStatement statement,
    ShareLanguage language = ShareLanguage.english,
  }) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final formattedDate = dateFormatter.format(statement.statementDate);
    final contact = statement.contact;
    final isReceivable = statement.isReceivable;
    final formattedNet = currencyFormatter.format(statement.netOutstandingBalance.abs());
    final formattedDebit = currencyFormatter.format(statement.totalDebit);
    final formattedCredit = currencyFormatter.format(statement.totalCredit);

    switch (language) {
      case ShareLanguage.hindi:
        final statusText = isReceivable ? 'लेना बाकी (Receivable)' : 'देना बाकी (Payable)';
        return '''*PAMZ Hisab - खाता विवरण (Ledger Statement)*
नमस्ते ${contact.name} जी,
दिनांक: $formattedDate तक का खाता सारांश:
• कुल दिया गया (Debit): $formattedDebit
• कुल जमा/प्राप्त (Credit): $formattedCredit
• शुद्ध बकाया शेष (Net Balance): $formattedNet ($statusText)
• कुल प्रविष्टियां: ${statement.items.length}

विस्तृत खाता पर्ची (PDF) संलग्न है।
धन्यवाद,
PAMZ Hisab''';

      case ShareLanguage.hinglish:
        final statusText = isReceivable ? 'Lena baaki (Receivable)' : 'Dena baaki (Payable)';
        return '''*PAMZ Hisab - Khata Statement*
Namaste ${contact.name} ji,
Date: $formattedDate tak aapke khate ka summary:
• Total Diya gaya (Debit): $formattedDebit
• Total Jama (Credit): $formattedCredit
• Net Outstanding: $formattedNet ($statusText)
• Total Entries: ${statement.items.length}

Itemized PDF Statement attached hai.
Shukriya,
PAMZ Hisab''';

      case ShareLanguage.english:
        final statusText = isReceivable ? 'Receivable' : 'Payable';
        return '''*PAMZ Hisab - Party Ledger Statement*
Dear ${contact.name},
Here is your account statement summary as of $formattedDate:
• Total Debited (Lent): $formattedDebit
• Total Credited (Repaid): $formattedCredit
• Net Outstanding: $formattedNet ($statusText)
• Total Entries: ${statement.items.length}

Attached: Detailed Itemized PDF Ledger Statement.
Thank you,
PAMZ Hisab''';
    }
  }

  /// Dispatches the PDF file and textual summary together via the native share sheet.
  /// On native iPadOS/iOS/Android, this presents the share sheet with the PDF attachment and message,
  /// allowing the user to select WhatsApp (FR-NT-001).
  Future<bool> sharePdfWithSummary({
    required Uint8List pdfBytes,
    required String filename,
    required String message,
    String? subject,
  }) async {
    try {
      XFile xFile;
      if (!kIsWeb) {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(pdfBytes, flush: true);
        xFile = XFile(file.path, mimeType: 'application/pdf', name: filename);
      } else {
        xFile = XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: filename);
      }

      final result = await Share.shareXFiles(
        [xFile],
        text: message,
        subject: subject ?? 'Ledger Statement - PAMZ Hisab',
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }

  /// Generates the statement PDF and dispatches it with the personalized message via share sheet.
  Future<bool> shareStatementPdfWithSummary({
    required ContactLedgerStatement statement,
    ShareLanguage language = ShareLanguage.english,
  }) async {
    final pdfBytes = await pdfService.generateStatementPdf(statement: statement);
    final filename = 'Statement_${statement.contact.name.replaceAll(RegExp(r'\s+'), '_')}_${DateFormat("yyyyMMdd").format(statement.statementDate)}.pdf';
    final message = buildStatementMessageText(
      statement: statement,
      language: language,
    );

    return sharePdfWithSummary(
      pdfBytes: pdfBytes,
      filename: filename,
      message: message,
      subject: 'Ledger Statement - ${statement.contact.name}',
    );
  }

  /// Dispatches text-only message via WhatsApp deep link (wa.me).
  Future<bool> shareViaWhatsApp({
    required DirectUdharLoan loan,
    required Contact contact,
    LoanFinancialSummary? summary,
    ShareLanguage language = ShareLanguage.english,
    bool isOpeningBalance = true,
  }) async {
    if (contact.mobileNumber.trim().isEmpty) {
      return false;
    }

    String cleanNumber = contact.mobileNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    final message = buildMessageText(
      loan: loan,
      contact: contact,
      summary: summary,
      language: language,
      isOpeningBalance: isOpeningBalance,
    );

    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$cleanNumber?text=$encodedMessage');

    if (await canLaunchUrl(url)) {
      return launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Dispatches text-only message via direct SMS scheme.
  Future<bool> sendSms({
    required DirectUdharLoan loan,
    required Contact contact,
    LoanFinancialSummary? summary,
    ShareLanguage language = ShareLanguage.english,
    bool isOpeningBalance = true,
  }) async {
    if (contact.mobileNumber.trim().isEmpty) {
      return false;
    }

    final message = buildMessageText(
      loan: loan,
      contact: contact,
      summary: summary,
      language: language,
      isOpeningBalance: isOpeningBalance,
    );

    final cleanNumber = contact.mobileNumber.replaceAll(RegExp(r'\D'), '');
    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('sms:$cleanNumber?body=$encodedMessage');

    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }
}

