import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/analytics_reports/data/models/analytics_models.dart';
import 'package:pamz_khata/feature/analytics_reports/data/services/analytics_excel_service.dart';
import 'package:pamz_khata/feature/analytics_reports/data/services/analytics_pdf_service.dart';
import 'package:pamz_khata/feature/analytics_reports/presentation/providers/analytics_providers.dart';
import 'package:pamz_khata/feature/analytics_reports/presentation/screens/analytics_screen.dart';

import '../../test_helpers/pump_app.dart';

class MockPdfService extends Mock implements AnalyticsPdfService {}
class MockExcelService extends Mock implements AnalyticsExcelService {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      AnalyticsReportData(
        horizon: AnalyticsTimeHorizon.monthly,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        summary: FinancialSummaryData.zero,
        categoryBreakdown: [],
        pnlTrend: [],
        quarterlyBreakdown: [],
        tenYearComparison: [],
      ),
    );
  });

  final testReport = AnalyticsReportData(
    horizon: AnalyticsTimeHorizon.monthly,
    startDate: DateTime(2026, 4, 1),
    endDate: DateTime(2026, 4, 30),
    summary: const FinancialSummaryData(
      totalIncome: 150000.0,
      totalExpense: 60000.0,
      totalUdharLent: 50000.0,
      totalUdharCollected: 15000.0,
      totalUdharBorrowed: 25000.0,
      totalUdharRepaid: 5000.0,
    ),
    categoryBreakdown: [
      const CategorySpendingBreakdown(
        categoryId: 'c-1',
        categoryName: 'Seeds & Fertilizer',
        domain: 'expense',
        amount: 40000.0,
        percentage: 66.7,
      ),
    ],
    pnlTrend: [
      PeriodPnLRecord(
        periodLabel: 'Apr 2026',
        date: DateTime(2026, 4, 1),
        income: 150000.0,
        expense: 60000.0,
      ),
    ],
    quarterlyBreakdown: [
      const QuarterlyBreakdownRecord(
        quarterNumber: 1,
        quarterName: 'Q1',
        agriculturalCycle: 'Jute & Early Sowing',
        monthsLabel: 'Apr - Jun',
        income: 150000.0,
        expense: 60000.0,
      ),
    ],
    tenYearComparison: [
      const TenYearComparisonRecord(
        year: 2026,
        totalIncome: 150000.0,
        totalExpense: 60000.0,
        udharLent: 50000.0,
        udharCollected: 15000.0,
      ),
    ],
  );

  testWidgets('AnalyticsScreen displays horizon chips and metrics cards', (tester) async {
    tester.view.physicalSize = const Size(1180, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockPdf = MockPdfService();
    final mockExcel = MockExcelService();
    when(() => mockPdf.shareReportPdf(any())).thenAnswer((_) async {});
    when(() => mockExcel.shareReportExcel(any())).thenAnswer((_) async {});

    await pumpApp(
      tester,
      const AnalyticsScreen(),
      overrides: [
        analyticsReportProvider.overrideWith((ref) async => testReport),
        analyticsPdfServiceProvider.overrideWithValue(mockPdf),
        analyticsExcelServiceProvider.overrideWithValue(mockExcel),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Financial Reports & Analytics'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Quarterly (Crop Cycles)'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('10-Year Trends'), findsOneWidget);

    // Financial summaries
    expect(find.text('Total Income'), findsOneWidget);
    expect(find.text('Total Expenses'), findsOneWidget);
    expect(find.text('Net Savings'), findsOneWidget);
    expect(find.text('Udhar Lent / Recovered'), findsOneWidget);

    // Category progress
    expect(find.text('Seeds & Fertilizer'), findsOneWidget);

    // Period PnL Breakdown
    expect(find.text('Period Statement Breakdown'), findsOneWidget);
    expect(find.text('Apr 2026'), findsOneWidget);

    // Export PDF button in AppBar
    final pdfButton = find.byTooltip('Export PDF Report');
    expect(pdfButton, findsOneWidget);
    await tester.tap(pdfButton);
    await tester.pumpAndSettle();
    verify(() => mockPdf.shareReportPdf(any())).called(1);

    // Export Excel button in AppBar
    final excelButton = find.byTooltip('Export Excel Spreadsheet (.xlsx)');
    expect(excelButton, findsOneWidget);
    await tester.tap(excelButton);
    await tester.pumpAndSettle();
    verify(() => mockExcel.shareReportExcel(any())).called(1);

    // Banner PDF button
    final bannerPdfButton = find.widgetWithText(OutlinedButton, 'PDF');
    expect(bannerPdfButton, findsOneWidget);
    await tester.tap(bannerPdfButton);
    await tester.pumpAndSettle();

    // Banner Excel button
    final bannerExcelButton = find.widgetWithText(OutlinedButton, 'Excel');
    expect(bannerExcelButton, findsOneWidget);
    await tester.tap(bannerExcelButton);
    await tester.pumpAndSettle();
  });

  testWidgets('AnalyticsScreen displays quarterly agricultural breakdown when quarterly horizon active', (tester) async {
    tester.view.physicalSize = const Size(1180, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final quarterlyReport = AnalyticsReportData(
      horizon: AnalyticsTimeHorizon.quarterly,
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2027, 3, 31),
      summary: const FinancialSummaryData(
        totalIncome: 150000,
        totalExpense: 60000,
        totalUdharLent: 0,
        totalUdharCollected: 0,
        totalUdharBorrowed: 0,
        totalUdharRepaid: 0,
      ),
      categoryBreakdown: [],
      pnlTrend: [],
      quarterlyBreakdown: [
        const QuarterlyBreakdownRecord(
          quarterNumber: 1,
          quarterName: 'Q1',
          agriculturalCycle: 'Jute & Early Sowing',
          monthsLabel: 'Apr - Jun',
          income: 150000.0,
          expense: 60000.0,
        ),
      ],
      tenYearComparison: [],
    );

    await pumpApp(
      tester,
      const AnalyticsScreen(),
      overrides: [
        selectedHorizonProvider.overrideWith((ref) => AnalyticsTimeHorizon.quarterly),
        analyticsReportProvider.overrideWith((ref) async => quarterlyReport),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Agricultural Crop-Cycle Analysis (Kishanganj, Bihar)'), findsOneWidget);
    expect(find.text('Jute & Early Sowing (Apr - Jun)'), findsOneWidget);
  });

  testWidgets('AnalyticsScreen displays 10-year lookback table when tenYear horizon active', (tester) async {
    tester.view.physicalSize = const Size(1180, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final tenYearReport = AnalyticsReportData(
      horizon: AnalyticsTimeHorizon.tenYear,
      startDate: DateTime(2016, 4, 1),
      endDate: DateTime(2026, 3, 31),
      summary: const FinancialSummaryData(
        totalIncome: 5000000,
        totalExpense: 2000000,
        totalUdharLent: 50000,
        totalUdharCollected: 15000,
        totalUdharBorrowed: 0,
        totalUdharRepaid: 0,
      ),
      categoryBreakdown: [],
      pnlTrend: [],
      quarterlyBreakdown: [],
      tenYearComparison: [
        const TenYearComparisonRecord(
          year: 2026,
          totalIncome: 1500000.0,
          totalExpense: 600000.0,
          udharLent: 50000.0,
          udharCollected: 15000.0,
        ),
      ],
    );

    await pumpApp(
      tester,
      const AnalyticsScreen(),
      overrides: [
        selectedHorizonProvider.overrideWith((ref) => AnalyticsTimeHorizon.tenYear),
        analyticsReportProvider.overrideWith((ref) async => tenYearReport),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('10-Year Annual Trend Lookback'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
  });

  testWidgets('AnalyticsScreen displays custom date range selector', (tester) async {
    tester.view.physicalSize = const Size(1180, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const AnalyticsScreen(),
      overrides: [
        selectedHorizonProvider.overrideWith((ref) => AnalyticsTimeHorizon.custom),
        customDateRangeProvider.overrideWith((ref) => DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 15))),
        analyticsReportProvider.overrideWith(
          (ref) async => AnalyticsReportData(
            horizon: AnalyticsTimeHorizon.custom,
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 1, 15),
            summary: const FinancialSummaryData(
              totalIncome: 10000,
              totalExpense: 0,
              totalUdharLent: 0,
              totalUdharCollected: 0,
              totalUdharBorrowed: 0,
              totalUdharRepaid: 0,
            ),
            categoryBreakdown: [],
            pnlTrend: [],
            quarterlyBreakdown: [],
            tenYearComparison: [],
          ),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('01 Jan 2026 – 15 Jan 2026'), findsOneWidget);
    expect(find.text('Change Dates'), findsOneWidget);
  });

  testWidgets('AnalyticsScreen displays empty state when no data exists', (tester) async {
    tester.view.physicalSize = const Size(1180, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final emptyReport = AnalyticsReportData(
      horizon: AnalyticsTimeHorizon.monthly,
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 4, 30),
      summary: FinancialSummaryData.zero,
      categoryBreakdown: [],
      pnlTrend: [],
      quarterlyBreakdown: [],
      tenYearComparison: [],
    );

    await pumpApp(
      tester,
      const AnalyticsScreen(),
      overrides: [
        analyticsReportProvider.overrideWith((ref) async => emptyReport),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('No financial records for this period'), findsOneWidget);
  });

  testWidgets('AnalyticsScreen renders All Transaction History section with entries', (tester) async {
    tester.view.physicalSize = const Size(1180, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final reportWithTxns = AnalyticsReportData(
      horizon: AnalyticsTimeHorizon.monthly,
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 4, 30),
      summary: const FinancialSummaryData(
        totalIncome: 10000,
        totalExpense: 3000,
        totalUdharLent: 5000,
        totalUdharCollected: 0,
        totalUdharBorrowed: 0,
        totalUdharRepaid: 0,
      ),
      categoryBreakdown: [],
      pnlTrend: [
        PeriodPnLRecord(
          periodLabel: 'Apr 2026',
          date: DateTime(2026, 4, 1),
          income: 10000,
          expense: 3000,
        ),
      ],
      quarterlyBreakdown: [],
      tenYearComparison: [],
      transactions: [
        AnalyticsTransactionItem(
          id: 't-1',
          title: 'Wheat Harvest Sale',
          subtitle: 'Agriculture Income',
          date: DateTime(2026, 4, 15),
          amount: 10000,
          type: 'income',
        ),
        AnalyticsTransactionItem(
          id: 't-2',
          title: 'Kamran ko dhopning ke liye',
          subtitle: 'Kamran • Udhar Given',
          date: DateTime(2026, 4, 18),
          amount: 5000,
          type: 'udhar_lent',
        ),
      ],
    );

    await pumpApp(
      tester,
      const AnalyticsScreen(),
      overrides: [
        analyticsReportProvider.overrideWith((ref) async => reportWithTxns),
      ],
    );

    expect(find.text('All Transaction History'), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);
    expect(find.text('Wheat Harvest Sale'), findsOneWidget);
    expect(find.text('Kamran ko dhopning ke liye'), findsOneWidget);

    // Test Search Filtering
    await tester.tap(find.byTooltip('Search All Transactions'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kamran');
    await tester.pumpAndSettle();

    expect(find.text('1 / 2 entries'), findsOneWidget);
    expect(find.text('Kamran ko dhopning ke liye'), findsOneWidget);
    expect(find.text('Wheat Harvest Sale'), findsNothing);
  });
}
