import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Date utility helpers for PAMZ Hisab.
abstract final class AppDateUtils {
  AppDateUtils._();

  static final _displayFmt = DateFormat(AppConstants.displayDateFormat);
  static final _monthYearFmt = DateFormat(AppConstants.monthYearFormat);
  static final _isoFmt = DateFormat(AppConstants.iso8601Format);
  static final _monthKeyFmt = DateFormat(AppConstants.monthKey);

  /// Parses an ISO8601 date string to [DateTime]. Returns null on failure.
  static DateTime? parseIso(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  /// Formats [DateTime] to ISO8601 string for DB storage.
  static String toIso(DateTime dt) => dt.toIso8601String();

  /// Formats [DateTime] to user-facing display: "08 Sep 2026"
  static String toDisplay(DateTime dt) => _displayFmt.format(dt);

  /// Formats to "Sep 2026"
  static String toMonthYear(DateTime dt) => _monthYearFmt.format(dt);

  /// Formats to "2026-09" — key used in monthly_summary table.
  static String toMonthKey(DateTime dt) => _monthKeyFmt.format(dt);

  /// Formats to "2026-09-08" — for range queries.
  static String toDateOnly(DateTime dt) => _isoFmt.format(dt);

  /// Returns true if [dt] is before today (overdue).
  static bool isOverdue(DateTime dt) =>
      dt.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0));

  /// Returns a human-relative label: "Today", "Yesterday", or display date.
  static String toRelativeDisplay(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return toDisplay(dt);
  }

  /// Start of current month (for reporting).
  static DateTime get startOfThisMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// End of current month.
  static DateTime get endOfThisMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  /// Start of a fiscal year given [month] = fiscal year start month (1=Jan, 4=Apr).
  static DateTime fiscalYearStart(int startMonth) {
    final now = DateTime.now();
    final year = now.month >= startMonth ? now.year : now.year - 1;
    return DateTime(year, startMonth, 1);
  }
}
