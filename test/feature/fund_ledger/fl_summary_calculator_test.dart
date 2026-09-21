import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact_summary.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_dashboard_summary.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/usecases/fl_summary_calculator.dart';

void main() {
  group('FLSummaryCalculator Unit Tests (Authoritative Formula)', () {
    test('1. Authoritative formula: available = received - returned', () {
      const received = 50000.0;
      const utilized = 25000.0;
      const returned = 10000.0;

      final available = FLSummaryCalculator.calculateAvailable(
        received: received,
        returned: returned,
      );

      // Expected: 50,000 - 10,000 = 40,000
      expect(available, equals(40000.0));
      // Utilized must NOT affect available responsibility
      expect(available, isNot(equals(received - returned - utilized)));
    });

    test('2. FLDashboardSummary computed property matches formula', () {
      const summary = FLDashboardSummary(
        totalReceived: 100000.0,
        totalUtilized: 75000.0,
        totalReturned: 20000.0,
        recentTransactions: [],
      );

      expect(summary.availableAmount, equals(80000.0));
    });

    test('3. FLContactSummary computed property matches formula', () {
      final summary = FLContactSummary(
        contact: FLContact(
          id: 'c1',
          name: 'Test',
          mobileNumber: '9999999999',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        totalReceived: 35000.0,
        totalUtilized: 12000.0,
        totalReturned: 5000.0,
      );

      expect(summary.availableAmount, equals(30000.0));
    });

    test('4. Zero totals produce zero available', () {
      final available = FLSummaryCalculator.calculateAvailable(
        received: 0,
        returned: 0,
      );
      expect(available, equals(0.0));
    });

    test('5. Over-returned produces negative available (deficit / over-settlement)', () {
      final available = FLSummaryCalculator.calculateAvailable(
        received: 10000.0,
        returned: 15000.0,
      );
      expect(available, equals(-5000.0));
    });

    test('6. Decimal precision is preserved accurately', () {
      final available = FLSummaryCalculator.calculateAvailable(
        received: 12345.67,
        returned: 2345.67,
      );
      expect(available, closeTo(10000.0, 0.001));
    });

    test('7. Critical authoritative rule verification: Received=10000, Utilized=6000, Returned=3000 -> Available=7000 NOT 1000', () {
      const received = 10000.0;
      const utilized = 6000.0;
      const returned = 3000.0;

      final transactions = [
        FLTransaction(
          id: '1',
          contactId: 'c1',  
          type: FLTransactionType.received,
          amount: received,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
        FLTransaction(
          id: '2',
          contactId: 'c1',
          type: FLTransactionType.utilized,
          amount: utilized,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
        FLTransaction(
          id: '3',
          contactId: 'c1',
          type: FLTransactionType.returned,
          amount: returned,
          txnDate: '2026-03-01',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      ];

      final summary = FLSummaryCalculator.fromTransactions(transactions);
      expect(summary.totalReceived, equals(10000.0));
      expect(summary.totalUtilized, equals(6000.0));
      expect(summary.totalReturned, equals(3000.0));
      expect(summary.availableAmount, equals(7000.0));
      expect(summary.availableAmount, isNot(equals(1000.0)));

      final available = FLSummaryCalculator.calculateAvailable(
        received: received,
        returned: returned,
      );

      expect(available, equals(7000.0));
      expect(available, isNot(equals(1000.0)));
      expect(available, equals(received - returned));
    });
  });
}
