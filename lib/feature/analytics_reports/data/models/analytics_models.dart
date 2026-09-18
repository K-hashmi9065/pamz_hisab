enum AnalyticsTimeHorizon {
  daily,
  weekly,
  monthly,
  yearly,
  quarterly,
  tenYear,
  custom,
}

/// Overall financial summary metrics for a given date period.
class FinancialSummaryData {
  const FinancialSummaryData({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalUdharLent,
    required this.totalUdharCollected,
    required this.totalUdharBorrowed,
    required this.totalUdharRepaid,
  });

  final double totalIncome;
  final double totalExpense;
  final double totalUdharLent;
  final double totalUdharCollected;
  final double totalUdharBorrowed;
  final double totalUdharRepaid;

  double get netSavings => totalIncome - totalExpense;
  double get netUdharReceivable => totalUdharLent - totalUdharCollected;
  double get netUdharPayable => totalUdharBorrowed - totalUdharRepaid;

  static const zero = FinancialSummaryData(
    totalIncome: 0,
    totalExpense: 0,
    totalUdharLent: 0,
    totalUdharCollected: 0,
    totalUdharBorrowed: 0,
    totalUdharRepaid: 0,
  );
}

/// Spending breakdown per category with percentage contribution.
class CategorySpendingBreakdown {
  const CategorySpendingBreakdown({
    required this.categoryId,
    required this.categoryName,
    this.iconKey,
    this.colorHex,
    required this.domain,
    required this.amount,
    required this.percentage,
  });

  final String categoryId;
  final String categoryName;
  final String? iconKey;
  final String? colorHex;
  final String domain; // 'income' or 'expense'
  final double amount;
  final double percentage; // 0.0 to 100.0
}

/// Period P&L record for trend charts and tables.
class PeriodPnLRecord {
  const PeriodPnLRecord({
    required this.periodLabel,
    required this.date,
    required this.income,
    required this.expense,
  });

  final String periodLabel;
  final DateTime date;
  final double income;
  final double expense;

  double get netProfit => income - expense;
}

/// Quarterly report aligned to regional Kishanganj agricultural harvest & sowing cycles.
class QuarterlyBreakdownRecord {
  const QuarterlyBreakdownRecord({
    required this.quarterNumber,
    required this.quarterName,
    required this.agriculturalCycle,
    required this.monthsLabel,
    required this.income,
    required this.expense,
  });

  final int quarterNumber; // 1, 2, 3, 4
  final String quarterName; // "Q1", "Q2", "Q3", "Q4"
  final String agriculturalCycle; // e.g. "Jute / Summer Sowing", "Monsoon Rice", "Kharif Harvest", "Rabi Crops"
  final String monthsLabel; // e.g. "Apr – Jun"
  final double income;
  final double expense;

  double get netProfit => income - expense;
}

/// Historical year-over-year comparison entry for 10-year lookback.
class TenYearComparisonRecord {
  const TenYearComparisonRecord({
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.udharLent,
    required this.udharCollected,
  });

  final int year;
  final double totalIncome;
  final double totalExpense;
  final double udharLent;
  final double udharCollected;

  double get netSavings => totalIncome - totalExpense;
  double get netUdharOutstanding => udharLent - udharCollected;
}

/// Complete aggregated analytics report model.
class AnalyticsReportData {
  const AnalyticsReportData({
    required this.horizon,
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.categoryBreakdown,
    required this.pnlTrend,
    required this.quarterlyBreakdown,
    required this.tenYearComparison,
  });

  final AnalyticsTimeHorizon horizon;
  final DateTime startDate;
  final DateTime endDate;
  final FinancialSummaryData summary;
  final List<CategorySpendingBreakdown> categoryBreakdown;
  final List<PeriodPnLRecord> pnlTrend;
  final List<QuarterlyBreakdownRecord> quarterlyBreakdown;
  final List<TenYearComparisonRecord> tenYearComparison;
}
