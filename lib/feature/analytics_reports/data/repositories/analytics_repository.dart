import 'package:fpdart/fpdart.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/hive/hive_registrar.dart';
import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../models/analytics_models.dart';

abstract class AnalyticsRepository {
  Future<Either<Failure, AnalyticsReportData>> getReportData({
    required AnalyticsTimeHorizon horizon,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String fiscalYearStart = 'april', // 'april' or 'january'
  });
}

class LocalAnalyticsRepositoryImpl implements AnalyticsRepository {
  final DatabaseHelper? _dbHelper;
  const LocalAnalyticsRepositoryImpl([this._dbHelper]);

  DatabaseHelper get _helper =>
      _dbHelper ?? DatabaseHelper(AppDatabase.instance);

  @override
  Future<Either<Failure, AnalyticsReportData>> getReportData({
    required AnalyticsTimeHorizon horizon,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String fiscalYearStart = 'april',
  }) async {
    try {
      final now = DateTime.now();
      final (startDate, endDate) = _resolveDateRange(
        horizon: horizon,
        now: now,
        customStart: customStartDate,
        customEnd: customEndDate,
        fiscalYearStart: fiscalYearStart,
      );

      // 1. Fetch raw records from active local storage backend (Hive or SQLite)
      final raw = await _fetchRawData();
      final categoriesMap = raw.categoriesMap;

      // Extract Family Transactions in range
      final List<Map<String, dynamic>> inRangeTxns = [];
      final List<Map<String, dynamic>> allTxns = [];
      for (final txn in raw.allTxns) {
        final isDeleted = (txn['is_deleted'] as int? ?? 0) == 1;
        if (!isDeleted) {
          final dateStr = txn['transaction_date'] as String?;
          if (dateStr != null) {
            final txnDate = DateTime.tryParse(dateStr);
            if (txnDate != null) {
              txn['_parsed_date'] = txnDate;
              allTxns.add(txn);
              if (!txnDate.isBefore(startDate) && !txnDate.isAfter(endDate)) {
                inRangeTxns.add(txn);
              }
            }
          }
        }
      }

      // Extract Udhar Loans in range
      final List<Map<String, dynamic>> inRangeLoans = [];
      final List<Map<String, dynamic>> allLoans = [];
      for (final loan in raw.allLoans) {
        final isDeleted = (loan['is_deleted'] as int? ?? 0) == 1;
        if (!isDeleted) {
          final createdAtStr = loan['created_at'] as String?;
          if (createdAtStr != null) {
            final loanDate = DateTime.tryParse(createdAtStr);
            if (loanDate != null) {
              loan['_parsed_date'] = loanDate;
              allLoans.add(loan);
              if (!loanDate.isBefore(startDate) && !loanDate.isAfter(endDate)) {
                inRangeLoans.add(loan);
              }
            }
          }
        }
      }

      // Extract Repayments in range
      final List<Map<String, dynamic>> inRangeRepayments = [];
      final List<Map<String, dynamic>> allRepayments = [];
      for (final rep in raw.allRepayments) {
        final isDeleted = (rep['is_deleted'] as int? ?? 0) == 1;
        if (!isDeleted) {
          final paidAtStr = rep['paid_at'] as String?;
          if (paidAtStr != null) {
            final repDate = DateTime.tryParse(paidAtStr);
            if (repDate != null) {
              rep['_parsed_date'] = repDate;
              allRepayments.add(rep);
              if (!repDate.isBefore(startDate) && !repDate.isAfter(endDate)) {
                inRangeRepayments.add(rep);
              }
            }
          }
        }
      }

      // 2. Compute Financial Summary
      double totalIncome = 0;
      double totalExpense = 0;
      final Map<String, double> categorySpendingTotals = {};

      for (final txn in inRangeTxns) {
        final type = txn['type'] as String?;
        final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
        final catId = txn['category_id'] as String? ?? 'unknown';

        if (type == 'income') {
          totalIncome += amount;
        } else if (type == 'expense') {
          totalExpense += amount;
          categorySpendingTotals[catId] = (categorySpendingTotals[catId] ?? 0.0) + amount;
        }
      }

      double totalUdharLent = 0;
      double totalUdharBorrowed = 0;
      for (final loan in inRangeLoans) {
        final direction = loan['direction'] as String?;
        final principal = (loan['principal_amount'] as num?)?.toDouble() ?? 0.0;
        if (direction == 'lent') {
          totalUdharLent += principal;
        } else if (direction == 'borrowed') {
          totalUdharBorrowed += principal;
        }
      }

      double totalUdharCollected = 0;
      double totalUdharRepaid = 0;
      for (final rep in inRangeRepayments) {
        final amt = (rep['amount'] as num?)?.toDouble() ?? 0.0;
        final sourceId = rep['source_id'] as String?;
        // Match source loan
        final parentLoan = allLoans.firstWhere(
          (l) => l['id'] == sourceId,
          orElse: () => <String, dynamic>{},
        );
        final dir = parentLoan['direction'] as String? ?? 'lent';
        if (dir == 'lent') {
          totalUdharCollected += amt;
        } else {
          totalUdharRepaid += amt;
        }
      }

      final summary = FinancialSummaryData(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        totalUdharLent: totalUdharLent,
        totalUdharCollected: totalUdharCollected,
        totalUdharBorrowed: totalUdharBorrowed,
        totalUdharRepaid: totalUdharRepaid,
      );

      // 3. Compute Category Breakdown (sorted descending by amount)
      final List<CategorySpendingBreakdown> categoryBreakdown = [];
      categorySpendingTotals.forEach((catId, amount) {
        final catInfo = categoriesMap[catId];
        final name = catInfo?['name'] as String? ?? 'Other Expense';
        final icon = catInfo?['icon_key'] as String? ?? '🛒';
        final color = catInfo?['color_hex'] as String? ?? '#607D8B';
        final pct = totalExpense > 0 ? (amount / totalExpense) * 100.0 : 0.0;

        categoryBreakdown.add(
          CategorySpendingBreakdown(
            categoryId: catId,
            categoryName: name,
            iconKey: icon,
            colorHex: color,
            domain: 'expense',
            amount: amount,
            percentage: pct,
          ),
        );
      });
      categoryBreakdown.sort((a, b) => b.amount.compareTo(a.amount));

      // 4. Compute Period PnL Trends
      final List<PeriodPnLRecord> pnlTrend = _buildPnLTrend(
        horizon: horizon,
        startDate: startDate,
        endDate: endDate,
        inRangeTxns: inRangeTxns,
      );

      // 5. Compute Quarterly Breakdown (Agricultural Cycle aligned)
      final List<QuarterlyBreakdownRecord> quarterlyBreakdown = _buildQuarterlyBreakdown(
        allTxns: allTxns,
        year: now.year,
        isAprilFiscal: fiscalYearStart == 'april',
      );

      // 6. Compute 10-Year Comparison
      final List<TenYearComparisonRecord> tenYearComparison = _buildTenYearComparison(
        allTxns: allTxns,
        allLoans: allLoans,
        allRepayments: allRepayments,
        currentYear: now.year,
      );

      final reportData = AnalyticsReportData(
        horizon: horizon,
        startDate: startDate,
        endDate: endDate,
        summary: summary,
        categoryBreakdown: categoryBreakdown,
        pnlTrend: pnlTrend,
        quarterlyBreakdown: quarterlyBreakdown,
        tenYearComparison: tenYearComparison,
      );

      return right(reportData);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  Future<({
    Map<String, Map<String, dynamic>> categoriesMap,
    List<Map<String, dynamic>> allTxns,
    List<Map<String, dynamic>> allLoans,
    List<Map<String, dynamic>> allRepayments,
  })> _fetchRawData() async {
    if (AppStorageConfig.isHive) {
      final txnBox = HiveRegistrar.familyTransactionsBox;
      final catBox = HiveRegistrar.categoriesBox;
      final udharBox = HiveRegistrar.directUdharBox;
      final repaymentBox = HiveRegistrar.repaymentsBox;

      final Map<String, Map<String, dynamic>> categoriesMap = {};
      for (final key in catBox.keys) {
        final data = catBox.get(key);
        if (data is Map) {
          final cat = Map<String, dynamic>.from(data);
          categoriesMap[cat['id'] as String] = cat;
        }
      }

      final List<Map<String, dynamic>> allTxns = [];
      for (final key in txnBox.keys) {
        final data = txnBox.get(key);
        if (data is Map) {
          allTxns.add(Map<String, dynamic>.from(data));
        }
      }

      final List<Map<String, dynamic>> allLoans = [];
      for (final key in udharBox.keys) {
        final data = udharBox.get(key);
        if (data is Map) {
          allLoans.add(Map<String, dynamic>.from(data));
        }
      }

      final List<Map<String, dynamic>> allRepayments = [];
      for (final key in repaymentBox.keys) {
        final data = repaymentBox.get(key);
        if (data is Map) {
          allRepayments.add(Map<String, dynamic>.from(data));
        }
      }

      return (
        categoriesMap: categoriesMap,
        allTxns: allTxns,
        allLoans: allLoans,
        allRepayments: allRepayments,
      );
    } else {
      final catRows = await _helper.query('categories');
      final txnRows = await _helper.query('family_transactions');
      final loanRows = await _helper.query('direct_udhar_loans');
      final repRows = await _helper.query('repayments');

      final Map<String, Map<String, dynamic>> categoriesMap = {};
      for (final r in catRows) {
        final cat = Map<String, dynamic>.from(r);
        categoriesMap[cat['id'] as String] = cat;
      }

      return (
        categoriesMap: categoriesMap,
        allTxns: txnRows.map((r) => Map<String, dynamic>.from(r)).toList(),
        allLoans: loanRows.map((r) => Map<String, dynamic>.from(r)).toList(),
        allRepayments: repRows.map((r) => Map<String, dynamic>.from(r)).toList(),
      );
    }
  }

  (DateTime, DateTime) _resolveDateRange({
    required AnalyticsTimeHorizon horizon,
    required DateTime now,
    DateTime? customStart,
    DateTime? customEnd,
    required String fiscalYearStart,
  }) {
    switch (horizon) {
      case AnalyticsTimeHorizon.daily:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);

      case AnalyticsTimeHorizon.weekly:
        final start = now.subtract(const Duration(days: 6));
        final startNormalized = DateTime(start.year, start.month, start.day, 0, 0, 0);
        final endNormalized = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (startNormalized, endNormalized);

      case AnalyticsTimeHorizon.monthly:
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (start, end);

      case AnalyticsTimeHorizon.yearly:
        if (fiscalYearStart == 'april') {
          final isJanToMar = now.month < 4;
          final fiscalYear = isJanToMar ? now.year - 1 : now.year;
          final start = DateTime(fiscalYear, 4, 1, 0, 0, 0);
          final end = DateTime(fiscalYear + 1, 3, 31, 23, 59, 59);
          return (start, end);
        } else {
          final start = DateTime(now.year, 1, 1, 0, 0, 0);
          final end = DateTime(now.year, 12, 31, 23, 59, 59);
          return (start, end);
        }

      case AnalyticsTimeHorizon.quarterly:
        final start = DateTime(now.year, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);
        return (start, end);

      case AnalyticsTimeHorizon.tenYear:
        final start = DateTime(now.year - 9, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);
        return (start, end);

      case AnalyticsTimeHorizon.custom:
        final start = customStart != null
            ? DateTime(customStart.year, customStart.month, customStart.day, 0, 0, 0)
            : DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = customEnd != null
            ? DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59)
            : DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);
    }
  }

  List<PeriodPnLRecord> _buildPnLTrend({
    required AnalyticsTimeHorizon horizon,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> inRangeTxns,
  }) {
    final Map<String, (double, double, DateTime)> buckets = {};

    for (final txn in inRangeTxns) {
      final date = txn['_parsed_date'] as DateTime;
      final type = txn['type'] as String?;
      final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;

      final String key;
      final DateTime bucketDate;

      if (horizon == AnalyticsTimeHorizon.daily || horizon == AnalyticsTimeHorizon.weekly) {
        key = DateFormat('dd MMM').format(date);
        bucketDate = DateTime(date.year, date.month, date.day);
      } else if (horizon == AnalyticsTimeHorizon.tenYear) {
        key = '${date.year}';
        bucketDate = DateTime(date.year, 1, 1);
      } else {
        key = DateFormat('MMM yyyy').format(date);
        bucketDate = DateTime(date.year, date.month, 1);
      }

      final current = buckets[key] ?? (0.0, 0.0, bucketDate);
      if (type == 'income') {
        buckets[key] = (current.$1 + amount, current.$2, bucketDate);
      } else if (type == 'expense') {
        buckets[key] = (current.$1, current.$2 + amount, bucketDate);
      }
    }

    final List<PeriodPnLRecord> records = buckets.entries.map((e) {
      return PeriodPnLRecord(
        periodLabel: e.key,
        date: e.value.$3,
        income: e.value.$1,
        expense: e.value.$2,
      );
    }).toList();

    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  List<QuarterlyBreakdownRecord> _buildQuarterlyBreakdown({
    required List<Map<String, dynamic>> allTxns,
    required int year,
    required bool isAprilFiscal,
  }) {
    final quartersDef = isAprilFiscal
        ? [
            (1, 'Q1', 'Jute & Summer Sowing', 'Apr – Jun', DateTime(year, 4, 1), DateTime(year, 6, 30, 23, 59, 59)),
            (2, 'Q2', 'Monsoon Paddy & Tea', 'Jul – Sep', DateTime(year, 7, 1), DateTime(year, 9, 30, 23, 59, 59)),
            (3, 'Q3', 'Kharif Harvest & Sales', 'Oct – Dec', DateTime(year, 10, 1), DateTime(year, 12, 31, 23, 59, 59)),
            (4, 'Q4', 'Rabi Winter Crops & Wheat', 'Jan – Mar', DateTime(year + 1, 1, 1), DateTime(year + 1, 3, 31, 23, 59, 59)),
          ]
        : [
            (1, 'Q1', 'Rabi Winter Sowing', 'Jan – Mar', DateTime(year, 1, 1), DateTime(year, 3, 31, 23, 59, 59)),
            (2, 'Q2', 'Jute & Summer Sowing', 'Apr – Jun', DateTime(year, 4, 1), DateTime(year, 6, 30, 23, 59, 59)),
            (3, 'Q3', 'Monsoon Paddy & Tea', 'Jul – Sep', DateTime(year, 7, 1), DateTime(year, 9, 30, 23, 59, 59)),
            (4, 'Q4', 'Kharif Harvest & Sales', 'Oct – Dec', DateTime(year, 10, 1), DateTime(year, 12, 31, 23, 59, 59)),
          ];

    return quartersDef.map((q) {
      double inc = 0;
      double exp = 0;
      for (final txn in allTxns) {
        final d = txn['_parsed_date'] as DateTime;
        if (!d.isBefore(q.$5) && !d.isAfter(q.$6)) {
          final amt = (txn['amount'] as num?)?.toDouble() ?? 0.0;
          if (txn['type'] == 'income') inc += amt;
          if (txn['type'] == 'expense') exp += amt;
        }
      }

      return QuarterlyBreakdownRecord(
        quarterNumber: q.$1,
        quarterName: q.$2,
        agriculturalCycle: q.$3,
        monthsLabel: q.$4,
        income: inc,
        expense: exp,
      );
    }).toList();
  }

  List<TenYearComparisonRecord> _buildTenYearComparison({
    required List<Map<String, dynamic>> allTxns,
    required List<Map<String, dynamic>> allLoans,
    required List<Map<String, dynamic>> allRepayments,
    required int currentYear,
  }) {
    final List<TenYearComparisonRecord> results = [];

    for (int y = currentYear - 9; y <= currentYear; y++) {
      final yStart = DateTime(y, 1, 1, 0, 0, 0);
      final yEnd = DateTime(y, 12, 31, 23, 59, 59);

      double yIncome = 0;
      double yExpense = 0;
      for (final t in allTxns) {
        final d = t['_parsed_date'] as DateTime;
        if (!d.isBefore(yStart) && !d.isAfter(yEnd)) {
          final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
          if (t['type'] == 'income') yIncome += amt;
          if (t['type'] == 'expense') yExpense += amt;
        }
      }

      double yLent = 0;
      for (final l in allLoans) {
        final d = l['_parsed_date'] as DateTime;
        if (!d.isBefore(yStart) && !d.isAfter(yEnd)) {
          if (l['direction'] == 'lent') {
            yLent += (l['principal_amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      double yCollected = 0;
      for (final r in allRepayments) {
        final d = r['_parsed_date'] as DateTime;
        if (!d.isBefore(yStart) && !d.isAfter(yEnd)) {
          final srcId = r['source_id'] as String?;
          final l = allLoans.firstWhere((ln) => ln['id'] == srcId, orElse: () => <String, dynamic>{});
          if (l['direction'] == 'lent') {
            yCollected += (r['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      results.add(
        TenYearComparisonRecord(
          year: y,
          totalIncome: yIncome,
          totalExpense: yExpense,
          udharLent: yLent,
          udharCollected: yCollected,
        ),
      );
    }

    results.sort((a, b) => b.year.compareTo(a.year));
    return results;
  }
}
