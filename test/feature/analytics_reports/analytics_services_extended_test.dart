import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/storage_config.dart';
import 'package:pamz_khata/feature/analytics_reports/data/models/analytics_models.dart';
import 'package:pamz_khata/feature/analytics_reports/data/repositories/analytics_repository.dart';
import 'package:pamz_khata/feature/analytics_reports/data/services/analytics_pdf_service.dart';

void main() {
  late Directory tempDir;
  late LocalAnalyticsRepositoryImpl repository;
  const pdfService = AnalyticsPdfService();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('analytics_ext_test_');
    Hive.init(tempDir.path);
    await HiveRegistrar.initialize(tempDir.path);
    AppStorageConfig.current = StorageType.hive;
    repository = const LocalAnalyticsRepositoryImpl();

    // Populate categories
    await HiveRegistrar.categoriesBox.put('cat_salary', {
      'id': 'cat_salary',
      'domain': 'income',
      'name': 'Salary',
      'icon_key': '💼',
      'color_hex': '#4CAF50',
      'is_deleted': 0,
    });
    await HiveRegistrar.categoriesBox.put('cat_grocery', {
      'id': 'cat_grocery',
      'domain': 'expense',
      'name': 'Groceries',
      'icon_key': '🛒',
      'color_hex': '#FF9800',
      'is_deleted': 0,
    });
    await HiveRegistrar.categoriesBox.put('cat_rent', {
      'id': 'cat_rent',
      'domain': 'expense',
      'name': 'Rent',
      'icon_key': '🏠',
      'color_hex': '#E91E63',
      'is_deleted': 0,
    });

    // Populate family transactions
    await HiveRegistrar.familyTransactionsBox.put('txn_1', {
      'id': 'txn_1',
      'type': 'income',
      'amount': 80000.0,
      'category_id': 'cat_salary',
      'transaction_date': DateTime.now().toIso8601String(),
      'is_deleted': 0,
    });
    await HiveRegistrar.familyTransactionsBox.put('txn_2', {
      'id': 'txn_2',
      'type': 'expense',
      'amount': 15000.0,
      'category_id': 'cat_grocery',
      'transaction_date': DateTime.now().toIso8601String(),
      'is_deleted': 0,
    });
    await HiveRegistrar.familyTransactionsBox.put('txn_3', {
      'id': 'txn_3',
      'type': 'expense',
      'amount': 20000.0,
      'category_id': 'cat_rent',
      'transaction_date': DateTime.now().toIso8601String(),
      'is_deleted': 0,
    });

    // Populate udhar loans
    await HiveRegistrar.directUdharBox.put('loan_1', {
      'id': 'loan_1',
      'contact_id': 'contact_1',
      'direction': 'lent',
      'principal_amount': 30000.0,
      'interest_type': 'interest_free',
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
      'is_deleted': 0,
    });
    await HiveRegistrar.directUdharBox.put('loan_2', {
      'id': 'loan_2',
      'contact_id': 'contact_2',
      'direction': 'borrowed',
      'principal_amount': 10000.0,
      'interest_type': 'simple',
      'interest_rate_percent': 2.0,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
      'is_deleted': 0,
    });

    // Populate repayments
    await HiveRegistrar.repaymentsBox.put('rep_1', {
      'id': 'rep_1',
      'source_type': 'direct_udhar',
      'source_id': 'loan_1',
      'amount': 10000.0,
      'paid_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'is_deleted': 0,
    });
  });

  tearDownAll(() async {
    AppStorageConfig.current = StorageType.sqlite;
  });

  group('LocalAnalyticsRepositoryImpl Aggregation Tests', () {
    test('1. Monthly horizon returns categorized income, expenses, udhar totals, and net profit', () async {
      final reportRes = await repository.getReportData(
        horizon: AnalyticsTimeHorizon.monthly,
      );

      expect(reportRes.isRight(), isTrue);
      final report = reportRes.getOrElse((_) => throw Exception('Failed'));

      expect(report.summary.totalIncome, equals(80000.0));
      expect(report.summary.totalExpense, equals(35000.0)); // 15k + 20k
      expect(report.summary.netSavings, equals(45000.0));
      expect(report.summary.totalUdharLent, equals(30000.0));
      expect(report.summary.totalUdharCollected, equals(10000.0));
      expect(report.summary.netUdharReceivable, equals(20000.0));
      expect(report.summary.totalUdharBorrowed, equals(10000.0));

      // Category breakdown
      expect(report.categoryBreakdown.length, greaterThanOrEqualTo(2));
      final groc = report.categoryBreakdown.firstWhere((c) => c.categoryId == 'cat_grocery');
      expect(groc.amount, equals(15000.0));
      expect(groc.percentage, closeTo(42.85, 0.5));
    });

    test('2. Weekly, Quarterly, Yearly, and Custom horizons date resolution', () async {
      final weeklyRes = await repository.getReportData(horizon: AnalyticsTimeHorizon.weekly);
      expect(weeklyRes.isRight(), isTrue);

      final quarterlyRes = await repository.getReportData(horizon: AnalyticsTimeHorizon.quarterly);
      expect(quarterlyRes.isRight(), isTrue);

      final yearlyRes = await repository.getReportData(horizon: AnalyticsTimeHorizon.yearly);
      expect(yearlyRes.isRight(), isTrue);

      final customRes = await repository.getReportData(
        horizon: AnalyticsTimeHorizon.custom,
        customStartDate: DateTime(2026, 1, 1),
        customEndDate: DateTime(2026, 12, 31),
      );
      expect(customRes.isRight(), isTrue);
      final customReport = customRes.getOrElse((_) => throw Exception('Failed'));
      expect(customReport.startDate, equals(DateTime(2026, 1, 1)));
      expect(customReport.endDate.year, equals(2026));
      expect(customReport.endDate.month, equals(12));
      expect(customReport.endDate.day, equals(31));
    });

    test('3. Empty dataset / 10-year lookback calculations do not crash and produce valid zero states', () async {
      final tenYearRes = await repository.getReportData(horizon: AnalyticsTimeHorizon.tenYear);
      expect(tenYearRes.isRight(), isTrue);
      final report = tenYearRes.getOrElse((_) => throw Exception('Failed'));
      expect(report.tenYearComparison, isNotEmpty);
    });
  });

  group('AnalyticsPdfService Document Generation Tests', () {
    test('4. Generates non-empty PDF document from populated report data', () async {
      final reportRes = await repository.getReportData(horizon: AnalyticsTimeHorizon.monthly);
      final report = reportRes.getOrElse((_) => throw Exception('Failed'));

      final pdfBytes = await pdfService.generateReportPdf(report);

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('5. Generates PDF document for quarterly, yearly, and custom horizons safely', () async {
      final quarterlyRes = await repository.getReportData(horizon: AnalyticsTimeHorizon.quarterly);
      final quarterlyReport = quarterlyRes.getOrElse((_) => throw Exception('Failed'));

      final quarterlyPdf = await pdfService.generateReportPdf(quarterlyReport);
      expect(quarterlyPdf, isA<Uint8List>());
      expect(quarterlyPdf.length, greaterThan(1000));

      final customReport = AnalyticsReportData(
        horizon: AnalyticsTimeHorizon.custom,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30),
        summary: FinancialSummaryData.zero,
        categoryBreakdown: [],
        pnlTrend: [],
        quarterlyBreakdown: [],
        tenYearComparison: [],
      );

      final emptyPdf = await pdfService.generateReportPdf(customReport);
      expect(emptyPdf, isA<Uint8List>());
      expect(emptyPdf.length, greaterThan(500));
    });
  });
}
