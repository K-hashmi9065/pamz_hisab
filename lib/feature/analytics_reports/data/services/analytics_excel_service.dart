import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/analytics_models.dart';

class AnalyticsExcelService {
  const AnalyticsExcelService();

  Future<Uint8List> generateReportExcel(AnalyticsReportData report) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    // ── Sheet 1: Executive Summary ──────────────────────────────────────────
    const summarySheetName = 'Financial Summary';
    final summarySheet = excel[summarySheetName];
    if (defaultSheet != null && defaultSheet != summarySheetName) {
      excel.delete(defaultSheet);
    }

    final dateFmt = DateFormat('dd-MM-yyyy');

    summarySheet.appendRow([
      TextCellValue('PAMZ Hisab — Financial Report'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Reporting Period: ${dateFmt.format(report.startDate)} to ${dateFmt.format(report.endDate)}'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Generated At: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}'),
    ]);
    summarySheet.appendRow([TextCellValue('')]); // empty line

    summarySheet.appendRow([
      TextCellValue('Metric'),
      TextCellValue('Amount (INR)'),
      TextCellValue('Classification'),
    ]);

    summarySheet.appendRow([
      TextCellValue('Total Domestic Income'),
      DoubleCellValue(report.summary.totalIncome),
      TextCellValue('Inflow'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total Domestic Expenses'),
      DoubleCellValue(report.summary.totalExpense),
      TextCellValue('Outflow'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Net Household Savings'),
      DoubleCellValue(report.summary.netSavings),
      TextCellValue(report.summary.netSavings >= 0 ? 'Surplus (+)' : 'Deficit (-)'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Direct Udhar Cash Lent'),
      DoubleCellValue(report.summary.totalUdharLent),
      TextCellValue('Credit Outflow'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Udhar Principal Collected'),
      DoubleCellValue(report.summary.totalUdharCollected),
      TextCellValue('Recovery Inflow'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Net Udhar Receivable Balance'),
      DoubleCellValue(report.summary.netUdharReceivable),
      TextCellValue('Asset Balance'),
    ]);

    // ── Sheet 2: Category Breakdown ─────────────────────────────────────────
    if (report.categoryBreakdown.isNotEmpty) {
      final catSheet = excel['Category Spending'];
      catSheet.appendRow([
        TextCellValue('Category Name'),
        TextCellValue('Domain'),
        TextCellValue('Amount (INR)'),
        TextCellValue('Percentage (%)'),
      ]);

      for (final cat in report.categoryBreakdown) {
        catSheet.appendRow([
          TextCellValue(cat.categoryName),
          TextCellValue(cat.domain),
          DoubleCellValue(cat.amount),
          DoubleCellValue(double.parse(cat.percentage.toStringAsFixed(2))),
        ]);
      }
    }

    // ── Sheet 3: Quarterly Breakdown ────────────────────────────────────────
    if (report.quarterlyBreakdown.isNotEmpty) {
      final qSheet = excel['Quarterly Analysis'];
      qSheet.appendRow([
        TextCellValue('Quarter'),
        TextCellValue('Months'),
        TextCellValue('Agricultural Crop Season'),
        TextCellValue('Income (INR)'),
        TextCellValue('Expense (INR)'),
        TextCellValue('Net Balance (INR)'),
      ]);

      for (final q in report.quarterlyBreakdown) {
        qSheet.appendRow([
          TextCellValue(q.quarterName),
          TextCellValue(q.monthsLabel),
          TextCellValue(q.agriculturalCycle),
          DoubleCellValue(q.income),
          DoubleCellValue(q.expense),
          DoubleCellValue(q.netProfit),
        ]);
      }
    }

    // ── Sheet 4: 10-Year Historical ─────────────────────────────────────────
    if (report.tenYearComparison.isNotEmpty) {
      final yrSheet = excel['10-Year Trends'];
      yrSheet.appendRow([
        TextCellValue('Year'),
        TextCellValue('Total Income (INR)'),
        TextCellValue('Total Expense (INR)'),
        TextCellValue('Net Savings (INR)'),
        TextCellValue('Udhar Lent (INR)'),
        TextCellValue('Udhar Recovered (INR)'),
      ]);

      for (final y in report.tenYearComparison) {
        yrSheet.appendRow([
          IntCellValue(y.year),
          DoubleCellValue(y.totalIncome),
          DoubleCellValue(y.totalExpense),
          DoubleCellValue(y.netSavings),
          DoubleCellValue(y.udharLent),
          DoubleCellValue(y.udharCollected),
        ]);
      }
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }

  Future<void> shareReportExcel(AnalyticsReportData report) async {
    final excelBytes = await generateReportExcel(report);
    final tempDir = await getTemporaryDirectory();
    final fileName = 'PAMZ_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(excelBytes);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: fileName,
        )
      ],
      subject: 'PAMZ Hisab Financial Report (.xlsx)',
      text: 'PAMZ Hisab Excel Report (${DateFormat('dd MMM yyyy').format(report.startDate)} – ${DateFormat('dd MMM yyyy').format(report.endDate)})',
    );
  }
}
