import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/analytics_models.dart';

class AnalyticsPdfService {
  const AnalyticsPdfService();

  Future<Uint8List> generateReportPdf(AnalyticsReportData report) async {
    final doc = pw.Document();
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy');

    final periodStr = switch (report.horizon) {
      AnalyticsTimeHorizon.daily => 'Daily: ${dateFmt.format(report.startDate)}',
      AnalyticsTimeHorizon.weekly =>
        'Weekly: ${dateFmt.format(report.startDate)} – ${dateFmt.format(report.endDate)}',
      AnalyticsTimeHorizon.monthly => 'Monthly: ${DateFormat('MMMM yyyy').format(report.startDate)}',
      AnalyticsTimeHorizon.yearly => 'Yearly: ${DateFormat('yyyy').format(report.startDate)}',
      AnalyticsTimeHorizon.quarterly => 'Quarterly Breakdown: ${report.startDate.year}',
      AnalyticsTimeHorizon.tenYear => '10-Year Historical Lookback',
      AnalyticsTimeHorizon.custom =>
        'Custom Period: ${dateFmt.format(report.startDate)} – ${dateFmt.format(report.endDate)}',
    };

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAMZ Hisab',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                  ),
                  pw.Text(
                    'Kishanganj, Bihar • Financial & Ledger Statement',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'CONFIDENTIAL REPORT',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700),
                  ),
                  pw.Text(
                    'Generated: ${dateFmt.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1.5, color: PdfColors.teal900),
          pw.SizedBox(height: 8),

          // Period Banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.teal200),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Reporting Period: $periodStr',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                ),
                pw.Text(
                  'Currency: INR (Rs.)',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Financial Summary Grid
          pw.Text('1. Executive Financial Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _cell('Metric', isHeader: true),
                  _cell('Amount (Rs.)', isHeader: true, align: pw.TextAlign.right),
                  _cell('Cash Flow Status', isHeader: true),
                ],
              ),
              _summaryRow('Total Domestic Income', currencyFmt.format(report.summary.totalIncome), 'Inflow'),
              _summaryRow('Total Domestic Expenses', currencyFmt.format(report.summary.totalExpense), 'Outflow'),
              _summaryRow('Net Household Savings', currencyFmt.format(report.summary.netSavings),
                  report.summary.netSavings >= 0 ? 'Surplus (+)' : 'Deficit (-)'),
              _summaryRow('Direct Udhar Cash Lent', currencyFmt.format(report.summary.totalUdharLent), 'Credit Outflow'),
              _summaryRow('Udhar Principal Collected', currencyFmt.format(report.summary.totalUdharCollected), 'Recovery Inflow'),
              _summaryRow('Net Udhar Receivable Balance', currencyFmt.format(report.summary.netUdharReceivable), 'Asset Balance'),
            ],
          ),
          pw.SizedBox(height: 20),

          // Category Spending Breakdown
          if (report.categoryBreakdown.isNotEmpty) ...[
            pw.Text('2. Category Spending Breakdown', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _cell('Category Name', isHeader: true),
                    _cell('Total Spent (Rs.)', isHeader: true, align: pw.TextAlign.right),
                    _cell('% Share', isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                ...report.categoryBreakdown.map((cat) => pw.TableRow(
                      children: [
                        _cell(cat.categoryName),
                        _cell(currencyFmt.format(cat.amount), align: pw.TextAlign.right),
                        _cell('${cat.percentage.toStringAsFixed(1)}%', align: pw.TextAlign.right),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Quarterly Agricultural Breakdown if quarterly horizon
          if (report.horizon == AnalyticsTimeHorizon.quarterly && report.quarterlyBreakdown.isNotEmpty) ...[
            pw.Text('3. Agricultural Crop-Cycle Quarterly Analysis (Kishanganj)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _cell('Quarter', isHeader: true),
                    _cell('Agricultural Season', isHeader: true),
                    _cell('Income (Rs.)', isHeader: true, align: pw.TextAlign.right),
                    _cell('Expense (Rs.)', isHeader: true, align: pw.TextAlign.right),
                    _cell('Net Balance (Rs.)', isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                ...report.quarterlyBreakdown.map((q) => pw.TableRow(
                      children: [
                        _cell('${q.quarterName} (${q.monthsLabel})'),
                        _cell(q.agriculturalCycle),
                        _cell(currencyFmt.format(q.income), align: pw.TextAlign.right),
                        _cell(currencyFmt.format(q.expense), align: pw.TextAlign.right),
                        _cell(currencyFmt.format(q.netProfit), align: pw.TextAlign.right),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // 10-Year Historical Comparison if 10-year horizon
          if (report.horizon == AnalyticsTimeHorizon.tenYear && report.tenYearComparison.isNotEmpty) ...[
            pw.Text('3. 10-Year Historical Lookback & Annual Trends', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _cell('Year', isHeader: true),
                    _cell('Income (Rs.)', isHeader: true, align: pw.TextAlign.right),
                    _cell('Expense (Rs.)', isHeader: true, align: pw.TextAlign.right),
                    _cell('Net Savings (Rs.)', isHeader: true, align: pw.TextAlign.right),
                    _cell('Udhar Lent (Rs.)', isHeader: true, align: pw.TextAlign.right),
                    _cell('Udhar Recovered (Rs.)', isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                ...report.tenYearComparison.map((y) => pw.TableRow(
                      children: [
                        _cell('${y.year}', isHeader: true),
                        _cell(currencyFmt.format(y.totalIncome), align: pw.TextAlign.right),
                        _cell(currencyFmt.format(y.totalExpense), align: pw.TextAlign.right),
                        _cell(currencyFmt.format(y.netSavings), align: pw.TextAlign.right),
                        _cell(currencyFmt.format(y.udharLent), align: pw.TextAlign.right),
                        _cell(currencyFmt.format(y.udharCollected), align: pw.TextAlign.right),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Sign-off Footer
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('PAMZ Hisab — Offline Financial Management System for iPad',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('CONFIDENTIAL FINANCIAL STATEMENT',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.TableRow _summaryRow(String label, String amount, String status) {
    return pw.TableRow(
      children: [
        _cell(label),
        _cell(amount, align: pw.TextAlign.right),
        _cell(status),
      ],
    );
  }

  pw.Widget _cell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 9.5 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> shareReportPdf(AnalyticsReportData report) async {
    final pdfBytes = await generateReportPdf(report);
    final tempDir = await getTemporaryDirectory();
    final fileName = 'PAMZ_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
      subject: 'PAMZ Hisab Financial Report',
      text: 'PAMZ Hisab Financial Report (${DateFormat('dd MMM yyyy').format(report.startDate)} – ${DateFormat('dd MMM yyyy').format(report.endDate)})',
    );
  }
}
