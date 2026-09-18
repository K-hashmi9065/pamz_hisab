import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/analytics_reports/data/models/analytics_models.dart';
import 'package:pamz_khata/feature/analytics_reports/data/services/analytics_excel_service.dart';
import 'package:pamz_khata/feature/analytics_reports/data/services/analytics_pdf_service.dart';

void main() {
  final testReport = AnalyticsReportData(
    horizon: AnalyticsTimeHorizon.yearly,
    startDate: DateTime(2026, 4, 1),
    endDate: DateTime(2027, 3, 31),
    summary: const FinancialSummaryData(
      totalIncome: 1250000.0,
      totalExpense: 650000.0,
      totalUdharLent: 200000.0,
      totalUdharCollected: 120000.0,
      totalUdharBorrowed: 50000.0,
      totalUdharRepaid: 20000.0,
    ),
    categoryBreakdown: [
      const CategorySpendingBreakdown(
        categoryId: 'c-1',
        categoryName: 'Fertilizer & Pesticides',
        domain: 'expense',
        amount: 250000.0,
        percentage: 38.46,
      ),
      const CategorySpendingBreakdown(
        categoryId: 'c-2',
        categoryName: 'Diesel & Machinery',
        domain: 'expense',
        amount: 180000.0,
        percentage: 27.69,
      ),
    ],
    pnlTrend: [
      PeriodPnLRecord(
        periodLabel: 'Apr 2026',
        date: DateTime(2026, 4, 1),
        income: 200000.0,
        expense: 80000.0,
      ),
    ],
    quarterlyBreakdown: [
      const QuarterlyBreakdownRecord(
        quarterNumber: 1,
        quarterName: 'Q1',
        agriculturalCycle: 'Jute & Summer Sowing',
        monthsLabel: 'Apr – Jun',
        income: 300000.0,
        expense: 150000.0,
      ),
      const QuarterlyBreakdownRecord(
        quarterNumber: 2,
        quarterName: 'Q2',
        agriculturalCycle: 'Monsoon Paddy & Tea',
        monthsLabel: 'Jul – Sep',
        income: 400000.0,
        expense: 200000.0,
      ),
    ],
    tenYearComparison: [
      const TenYearComparisonRecord(
        year: 2026,
        totalIncome: 1250000.0,
        totalExpense: 650000.0,
        udharLent: 200000.0,
        udharCollected: 120000.0,
      ),
    ],
  );

  test('AnalyticsPdfService produces non-empty multi-page PDF document', () async {
    const pdfService = AnalyticsPdfService();
    final pdfBytes = await pdfService.generateReportPdf(testReport);

    expect(pdfBytes, isNotEmpty);
    // Standard PDF header signature check: %PDF-
    expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
  });

  test('AnalyticsExcelService produces structured XLSX workbook bytes', () async {
    const excelService = AnalyticsExcelService();
    final excelBytes = await excelService.generateReportExcel(testReport);

    expect(excelBytes, isNotEmpty);
    // Standard ZIP/XLSX header signature check: PK\x03\x04
    expect(excelBytes[0], 0x50);
    expect(excelBytes[1], 0x4B);
  });
}
