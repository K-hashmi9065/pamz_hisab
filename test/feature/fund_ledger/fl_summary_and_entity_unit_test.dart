import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact_summary.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/usecases/fl_summary_calculator.dart';

void main() {
  // ─── Fixtures ──────────────────────────────────────────────────────────────

  final contact = FLContact(
    id: 'c1',
    name: 'Ramesh Fund',
    mobileNumber: '9876500000',
    aadhaarNumber: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  FLTransaction createTxn(FLTransactionType type, double amount, {bool isDeleted = false}) {
    return FLTransaction(
      id: 'txn-${type.name}-$amount',
      contactId: 'c1',
      type: type,
      amount: amount,
      txnDate: '2026-03-01',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
      isDeleted: isDeleted,
    );
  }

  // ─── FLContactSummary tests ────────────────────────────────────────────────

  group('FLContactSummary', () {
    test('availableAmount = totalReceived - totalReturned (NOT minus utilized)', () {
      final summary = FLContactSummary(
        contact: contact,
        totalReceived: 100000,
        totalUtilized: 40000,
        totalReturned: 30000,
      );
      expect(summary.availableAmount, 70000.0); // 100000 - 30000
    });

    test('utilized does NOT reduce availableAmount', () {
      final withUtilized = FLContactSummary(
        contact: contact,
        totalReceived: 50000,
        totalUtilized: 50000, // fully utilized
        totalReturned: 0,
      );
      expect(withUtilized.availableAmount, 50000.0); // still 50000 - 0
    });

    test('availableAmount is zero when fully returned', () {
      final summary = FLContactSummary(
        contact: contact,
        totalReceived: 25000,
        totalUtilized: 10000,
        totalReturned: 25000,
      );
      expect(summary.availableAmount, 0.0);
    });

    test('FLContactSummary.empty() initializes all amounts to zero', () {
      final empty = FLContactSummary.empty(contact);
      expect(empty.totalReceived, 0.0);
      expect(empty.totalUtilized, 0.0);
      expect(empty.totalReturned, 0.0);
      expect(empty.availableAmount, 0.0);
      expect(empty.contact.id, contact.id);
    });

    test('copyWith overrides specified fields, keeps others', () {
      final base = FLContactSummary(
        contact: contact,
        totalReceived: 10000,
        totalUtilized: 3000,
        totalReturned: 2000,
      );
      final updated = base.copyWith(totalReceived: 20000, totalReturned: 5000);
      expect(updated.totalReceived, 20000);
      expect(updated.totalReturned, 5000);
      expect(updated.totalUtilized, 3000); // unchanged
      expect(updated.availableAmount, 15000.0);
    });

    test('copyWith with contact override', () {
      final anotherContact = FLContact(
        id: 'c2',
        name: 'Another',
        mobileNumber: '9000000000',
        aadhaarNumber: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final summary = FLContactSummary.empty(contact);
      final updated = summary.copyWith(contact: anotherContact);
      expect(updated.contact.id, 'c2');
    });

    test('toString contains key values', () {
      final summary = FLContactSummary(
        contact: contact,
        totalReceived: 10000,
        totalUtilized: 3000,
        totalReturned: 2000,
      );
      final str = summary.toString();
      expect(str, contains('10000'));
      expect(str, contains('3000'));
      expect(str, contains('2000'));
    });
  });

  // ─── FLSummaryCalculator tests ────────────────────────────────────────────

  group('FLSummaryCalculator.fromTransactions', () {
    test('correctly totals received, utilized, returned', () {
      final txns = [
        createTxn(FLTransactionType.received, 50000),
        createTxn(FLTransactionType.received, 30000),
        createTxn(FLTransactionType.utilized, 20000),
        createTxn(FLTransactionType.returned, 10000),
      ];
      final totals = FLSummaryCalculator.fromTransactions(txns);
      expect(totals.totalReceived, 80000);
      expect(totals.totalUtilized, 20000);
      expect(totals.totalReturned, 10000);
      expect(totals.availableAmount, 70000); // 80000 - 10000
    });

    test('soft-deleted transactions are excluded', () {
      final txns = [
        createTxn(FLTransactionType.received, 100000),
        createTxn(FLTransactionType.received, 50000, isDeleted: true), // excluded
        createTxn(FLTransactionType.returned, 20000, isDeleted: true), // excluded
      ];
      final totals = FLSummaryCalculator.fromTransactions(txns);
      expect(totals.totalReceived, 100000); // only non-deleted
      expect(totals.totalReturned, 0);
    });

    test('empty list produces all-zero totals', () {
      final totals = FLSummaryCalculator.fromTransactions([]);
      expect(totals.totalReceived, 0);
      expect(totals.totalUtilized, 0);
      expect(totals.totalReturned, 0);
      expect(totals.availableAmount, 0);
    });

    test('all-deleted list produces all-zero totals', () {
      final txns = [
        createTxn(FLTransactionType.received, 99999, isDeleted: true),
        createTxn(FLTransactionType.utilized, 50000, isDeleted: true),
      ];
      final totals = FLSummaryCalculator.fromTransactions(txns);
      expect(totals.totalReceived, 0);
      expect(totals.totalUtilized, 0);
    });
  });

  group('FLSummaryCalculator.calculateAvailable', () {
    test('returns received minus returned', () {
      expect(FLSummaryCalculator.calculateAvailable(received: 80000, returned: 30000), 50000);
    });

    test('returns 0 when returned equals received', () {
      expect(FLSummaryCalculator.calculateAvailable(received: 50000, returned: 50000), 0);
    });

    test('returns negative when returned > received (data anomaly)', () {
      expect(FLSummaryCalculator.calculateAvailable(received: 1000, returned: 2000), -1000);
    });
  });

  group('FLTotals value object', () {
    test('availableAmount computed correctly', () {
      const t = FLTotals(totalReceived: 100000, totalUtilized: 40000, totalReturned: 25000);
      expect(t.availableAmount, 75000); // 100000 - 25000
    });

    test('operator+ sums component fields', () {
      const a = FLTotals(totalReceived: 10000, totalUtilized: 2000, totalReturned: 3000);
      const b = FLTotals(totalReceived: 5000, totalUtilized: 1000, totalReturned: 2000);
      final sum = a + b;
      expect(sum.totalReceived, 15000);
      expect(sum.totalUtilized, 3000);
      expect(sum.totalReturned, 5000);
      expect(sum.availableAmount, 10000);
    });

    test('FLTotals.zero() produces all zeros', () {
      final z = FLTotals.zero();
      expect(z.totalReceived, 0);
      expect(z.totalUtilized, 0);
      expect(z.totalReturned, 0);
      expect(z.availableAmount, 0);
    });

    test('toString contains all values', () {
      const t = FLTotals(totalReceived: 12345, totalUtilized: 6789, totalReturned: 1111);
      expect(t.toString(), contains('12345'));
      expect(t.toString(), contains('6789'));
      expect(t.toString(), contains('1111'));
    });

    test('totalsFromList delegates to fromTransactions correctly', () {
      final txns = [createTxn(FLTransactionType.received, 5000)];
      final totals = FLSummaryCalculator.totalsFromList(txns);
      expect(totals.totalReceived, 5000);
    });
  });
}
