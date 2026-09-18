import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';
import '../../data/models/analytics_models.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/services/analytics_excel_service.dart';
import '../../data/services/analytics_pdf_service.dart';

final analyticsDatabaseHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper(AppDatabase.instance),
);

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return LocalAnalyticsRepositoryImpl(
    AppStorageConfig.isSqlite
        ? ref.watch(analyticsDatabaseHelperProvider)
        : null,
  );
});

final analyticsPdfServiceProvider = Provider<AnalyticsPdfService>((ref) {
  return const AnalyticsPdfService();
});

final analyticsExcelServiceProvider = Provider<AnalyticsExcelService>((ref) {
  return const AnalyticsExcelService();
});

final selectedHorizonProvider = StateProvider<AnalyticsTimeHorizon>((ref) {
  return AnalyticsTimeHorizon.monthly;
});

final customDateRangeProvider = StateProvider<DateTimeRange?>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, 1),
    end: DateTime(now.year, now.month, now.day),
  );
});

final analyticsReportProvider = FutureProvider<AnalyticsReportData>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  final horizon = ref.watch(selectedHorizonProvider);
  final dateRange = ref.watch(customDateRangeProvider);

  // Read fiscal year setting from settingsBox
  String fiscalYear = 'april';
  try {
    final settingsBox = HiveRegistrar.settingsBox;
    final val = settingsBox.get('app_fiscal_year_month') as int?;
    if (val == 1) {
      fiscalYear = 'january';
    }
  } catch (_) {}

  final result = await repository.getReportData(
    horizon: horizon,
    customStartDate: horizon == AnalyticsTimeHorizon.custom ? dateRange?.start : null,
    customEndDate: horizon == AnalyticsTimeHorizon.custom ? dateRange?.end : null,
    fiscalYearStart: fiscalYear,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (reportData) => reportData,
  );
});
