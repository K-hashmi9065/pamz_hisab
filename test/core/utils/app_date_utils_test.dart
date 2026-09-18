import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/utils/app_date_utils.dart';

void main() {
  group('AppDateUtils Unit Tests', () {
    test('parseIso parses valid ISO string and returns null on invalid', () {
      expect(AppDateUtils.parseIso(null), isNull);
      expect(AppDateUtils.parseIso(''), isNull);
      expect(AppDateUtils.parseIso('invalid-date'), isNull);

      final dt = AppDateUtils.parseIso('2026-09-08T10:30:00.000Z');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 9);
      expect(dt.day, 8);
    });

    test('toIso formats DateTime to ISO8601 string', () {
      final dt = DateTime(2026, 9, 8, 12, 0, 0);
      expect(AppDateUtils.toIso(dt), dt.toIso8601String());
    });

    test('toDisplay formats DateTime to readable date', () {
      final dt = DateTime(2026, 9, 8);
      expect(AppDateUtils.toDisplay(dt), contains('2026'));
      expect(AppDateUtils.toDisplay(dt), contains('Sep'));
    });

    test('toMonthYear formats DateTime to Month Year', () {
      final dt = DateTime(2026, 9, 8);
      expect(AppDateUtils.toMonthYear(dt), 'Sep 2026');
    });

    test('toMonthKey formats to yyyy-MM key', () {
      final dt = DateTime(2026, 9, 8);
      expect(AppDateUtils.toMonthKey(dt), '2026-09');
    });

    test('toDateOnly formats to yyyy-MM-dd', () {
      final dt = DateTime(2026, 9, 8);
      expect(AppDateUtils.toDateOnly(dt), '2026-09-08');
    });

    test('isOverdue returns true for past dates and false for future dates', () {
      final past = DateTime.now().subtract(const Duration(days: 5));
      final future = DateTime.now().add(const Duration(days: 5));

      expect(AppDateUtils.isOverdue(past), isTrue);
      expect(AppDateUtils.isOverdue(future), isFalse);
    });

    test('toRelativeDisplay returns Today, Yesterday, X days ago, or display date', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final threeDaysAgo = today.subtract(const Duration(days: 3));
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));

      expect(AppDateUtils.toRelativeDisplay(today), 'Today');
      expect(AppDateUtils.toRelativeDisplay(yesterday), 'Yesterday');
      expect(AppDateUtils.toRelativeDisplay(threeDaysAgo), '3 days ago');
      expect(AppDateUtils.toRelativeDisplay(thirtyDaysAgo), AppDateUtils.toDisplay(thirtyDaysAgo));
    });

    test('startOfThisMonth and endOfThisMonth produce valid month boundaries', () {
      final start = AppDateUtils.startOfThisMonth;
      final end = AppDateUtils.endOfThisMonth;

      expect(start.day, 1);
      expect(end.isAfter(start), isTrue);
      expect(start.month, end.month);
    });

    test('fiscalYearStart calculates correct start for April (Indian FY) and Jan (CY)', () {
      final aprStart = AppDateUtils.fiscalYearStart(4);
      expect(aprStart.month, 4);
      expect(aprStart.day, 1);

      final janStart = AppDateUtils.fiscalYearStart(1);
      expect(janStart.month, 1);
      expect(janStart.day, 1);
    });
  });
}
