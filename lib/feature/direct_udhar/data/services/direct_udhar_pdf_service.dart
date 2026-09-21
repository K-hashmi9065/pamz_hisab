import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/domain/entities/contact_ledger_statement.dart';
import '../../domain/entities/direct_udhar_loan.dart';
import '../../domain/services/interest_calculator.dart';

/// Service for generating PDF receipts and invoices for Direct Udhar and Opening Balances.
class DirectUdharPdfService {
  const DirectUdharPdfService();

  /// Generates a PDF document receipt for a Direct Udhar loan / Opening Balance.
  Future<Uint8List> generateReceiptPdf({
    required DirectUdharLoan loan,
    required Contact contact,
    LoanFinancialSummary? summary,
    String? customTitle,
  }) async {
    final pdf = pw.Document();
    final isOpeningBalance = loan.memo != null && loan.memo!.contains('[Opening Balance]') || customTitle != null;
    final title = customTitle ?? (isOpeningBalance ? 'Opening Balance Acknowledgment' : 'Direct Udhar Receipt');
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM yyyy');
    final isLent = loan.direction == LoanDirection.lent;

    final (font, fontBold) = await _loadFonts();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PAMZ Hisab',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Kishanganj, Bihar - Offline Udhar Khata',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: isLent ? PdfColors.green50 : PdfColors.orange50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(
                        color: isLent ? PdfColors.green700 : PdfColors.orange700,
                        width: 1,
                      ),
                    ),
                    child: pw.Text(
                      isLent ? 'UDHAR GIVEN (LENT)' : 'UDHAR TAKEN (BORROWED)',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: isLent ? PdfColors.green900 : PdfColors.orange900,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 12),

              // Document Title & Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                  ),
                  pw.Text(
                    'Date: ${dateFormatter.format(loan.createdAt)}',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
                  ),
                ],
              ),
              if (loan.id.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Voucher / Ref ID: ${loan.id}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
              pw.SizedBox(height: 20),

              // Contact Information Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PARTY / CONTACT DETAILS',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Name: ',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          contact.name,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.SizedBox(width: 24),
                        if (contact.mobileNumber.isNotEmpty) ...[
                          pw.Text(
                            'Mobile: ',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            contact.mobileNumber,
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    if (contact.address != null && contact.address!.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Address: ${contact.address!}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Transaction Financial Breakdown Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Details / Terms', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount (INR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          isOpeningBalance ? 'Opening Principal Amount' : 'Principal Amount',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          loan.interestType == InterestType.simple
                              ? 'Simple Interest (${loan.interestRatePercent}% / 30 days)'
                              : 'Interest-Free',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          currencyFormatter.format(loan.principalAmount),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  if (summary != null && summary.accruedInterest > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Accrued Unpaid Interest', style: const pw.TextStyle(fontSize: 11)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Calculated to current date', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            currencyFormatter.format(summary.accruedInterest),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  if (summary != null && summary.totalInterestPaid > 0 || (summary != null && summary.totalPrincipalPaid > 0))
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total Repaid so far', style: const pw.TextStyle(fontSize: 11)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Principal + Interest', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '- ${currencyFormatter.format(summary.totalPrincipalPaid + summary.totalInterestPaid)}',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.green900),
                          ),
                        ),
                      ],
                    ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total Outstanding',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          isLent ? 'Receivable' : 'Payable',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          currencyFormatter.format(summary?.totalOutstanding ?? loan.outstandingBalance),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                            color: isLent ? PdfColors.green900 : PdfColors.orange900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Memo / Notes
              if (loan.memo != null && loan.memo!.isNotEmpty) ...[
                pw.Text(
                  'Memo / Note: ${loan.memo!}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 16),
              ],

              pw.Spacer(),

              // Signatures / Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Authorized Signature: __________________', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('PAMZ Hisab Record Keeper', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Party Signature: __________________', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(contact.name, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Generated via PAMZ Hisab - Offline Khata & Udhar Manager',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a comprehensive itemized PDF ledger statement for a contact.
  Future<Uint8List> generateStatementPdf({
    required ContactLedgerStatement statement,
  }) async {
    final pdf = pw.Document();
    final contact = statement.contact;
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM yyyy');
    final isReceivable = statement.isReceivable;

    final (font, fontBold) = await _loadFonts();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PAMZ Hisab',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Kishanganj, Bihar - Offline Udhar Khata',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: isReceivable ? PdfColors.green50 : PdfColors.orange50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(
                        color: isReceivable ? PdfColors.green700 : PdfColors.orange700,
                        width: 1,
                      ),
                    ),
                    child: pw.Text(
                      'PARTY LEDGER STATEMENT',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: isReceivable ? PdfColors.green900 : PdfColors.orange900,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated on: ${dateFormatter.format(statement.statementDate)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text('PAMZ Hisab Khata Manager', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Party Info Box
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Party Name: ${contact.name}',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Type: ${contact.type.name.toUpperCase()} • Mobile: ${contact.mobileNumber}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                      if (contact.address != null && contact.address!.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Address: ${contact.address!}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'As of Date: ${dateFormatter.format(statement.statementDate)}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Total Entries: ${statement.items.length}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Itemized Transaction Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.0), // Date
                1: const pw.FlexColumnWidth(4.5), // Particulars
                2: const pw.FlexColumnWidth(2.2), // Debit
                3: const pw.FlexColumnWidth(2.2), // Credit
                4: const pw.FlexColumnWidth(2.5), // Balance
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Particulars / Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Debit (${contact.isBuyer ? "Lent" : "Paid"})', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Credit (${contact.isBuyer ? "Jama" : "Payable"})', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Balance', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  ],
                ),
                // Data Rows
                if (statement.items.isEmpty)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Center(child: pw.Text('No historical transactions recorded for this contact.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(0), child: pw.SizedBox()),
                      pw.Padding(padding: const pw.EdgeInsets.all(0), child: pw.SizedBox()),
                      pw.Padding(padding: const pw.EdgeInsets.all(0), child: pw.SizedBox()),
                      pw.Padding(padding: const pw.EdgeInsets.all(0), child: pw.SizedBox()),
                    ],
                  )
                else
                  ...statement.items.map((item) {
                    final isDebit = item.debit > 0;
                    final isCredit = item.credit > 0;
                    final double bal = item.runningBalance;
                    final String balanceStr;
                    if (contact.isBuyer) {
                      balanceStr = '${currencyFormatter.format(bal.abs())} ${bal >= 0 ? "Dr (Rec)" : "Cr (Adv)"}';
                    } else {
                      balanceStr = '${currencyFormatter.format(bal.abs())} ${bal <= 0 ? "Cr (Pay)" : "Dr (Adv)"}';
                    }

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(DateFormat('dd-MM-yyyy').format(item.date), style: const pw.TextStyle(fontSize: 8.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(item.description, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                              if (item.interestDetails != null && item.interestDetails!.isNotEmpty)
                                pw.Text(item.interestDetails!, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(isDebit ? currencyFormatter.format(item.debit) : '-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(isCredit ? currencyFormatter.format(item.credit) : '-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.green900)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(balanceStr, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    );
                  }),
              ],
            ),
            pw.SizedBox(height: 14),

            // Financial Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Debited (${contact.isBuyer ? "Lent" : "Paid"}): ${currencyFormatter.format(statement.totalDebit)}', style: const pw.TextStyle(fontSize: 9.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('Total Credited (${contact.isBuyer ? "Jama" : "Payables"}): ${currencyFormatter.format(statement.totalCredit)}', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.green900)),
                      if (statement.totalAccruedInterest > 0) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('Accrued Interest: ${currencyFormatter.format(statement.totalAccruedInterest)}', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                      ],
                    ],
                  ),
                  () {
                    final double netBal = statement.netOutstandingBalance;
                    final String netTitle;
                    final PdfColor netTextColor;
                    final PdfColor netBgColor;
                    final PdfColor netBorderColor;

                    if (contact.isBuyer) {
                      if (netBal >= 0) {
                        netTitle = 'NET RECEIVABLE';
                        netTextColor = PdfColors.green900;
                        netBgColor = PdfColors.green100;
                        netBorderColor = PdfColors.green800;
                      } else {
                        netTitle = 'ADVANCE RECEIVED';
                        netTextColor = PdfColors.orange900;
                        netBgColor = PdfColors.orange100;
                        netBorderColor = PdfColors.orange800;
                      }
                    } else {
                      if (netBal <= 0) {
                        netTitle = 'NET PAYABLE';
                        netTextColor = PdfColors.red900;
                        netBgColor = PdfColors.red100;
                        netBorderColor = PdfColors.red800;
                      } else {
                        netTitle = 'ADVANCE PAID';
                        netTextColor = PdfColors.green900;
                        netBgColor = PdfColors.green100;
                        netBorderColor = PdfColors.green800;
                      }
                    }

                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: netBgColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: netBorderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            netTitle,
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: netTextColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            currencyFormatter.format(netBal.abs()),
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: netTextColor),
                          ),
                        ],
                      ),
                    );
                  }(),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Signatures Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Authorized Signature: __________________', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 3),
                    pw.Text('PAMZ Hisab Record Keeper', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Party Signature: __________________', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 3),
                    pw.Text(contact.name, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<(pw.Font, pw.Font)> _loadFonts() async {
    try {
      final font = await PdfGoogleFonts.interRegular();
      final fontBold = await PdfGoogleFonts.interBold();
      return (font, fontBold);
    } catch (_) {
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  /// Prints or opens the system print/share sheet for the PDF.
  Future<void> printOrSharePdf({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }
}

