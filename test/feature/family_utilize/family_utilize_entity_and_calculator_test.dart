import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/family_utilize/data/models/family_utilize_model.dart';
import 'package:pamz_khata/feature/family_utilize/domain/entities/family_utilize.dart';
import 'package:pamz_khata/feature/family_utilize/domain/entities/family_utilize_summary.dart';

void main() {
  group('FamilyUtilize Entity & Summary Calculation Tests', () {
    test('1. Zero utilization yields exact available equal to Received - Returned', () {
      const summary = FamilyUtilizeSummary(
        totalReceived: 50000,
        totalReturned: 5000,
        totalFamilyUtilized: 0,
      );

      expect(summary.availableBeforeFamilyUtilize, 45000);
      expect(summary.remainingAvailable, 45000);
      expect(summary.totalFamilyUtilized, 0);
    });

    test('2. Multiple utilization transactions reduce remaining available balance correctly', () {
      // Example from business rules:
      // Received = ₹50,000, Returned = ₹5,000 -> Fund Available = ₹45,000
      // Education = ₹5,000, Electricity = ₹2,000 -> Total Family Utilized = ₹7,000
      // Final Available Balance = ₹38,000
      const summary = FamilyUtilizeSummary(
        totalReceived: 50000,
        totalReturned: 5000,
        totalFamilyUtilized: 7000,
      );

      expect(summary.availableBeforeFamilyUtilize, 45000);
      expect(summary.totalFamilyUtilized, 7000);
      expect(summary.remainingAvailable, 38000);
    });

    test('3. Exact balance calculation with Grocery, Medical, House Expense', () {
      final now = DateTime(2026, 9, 23);
      final txns = [
        FamilyUtilize(
          id: 'u1',
          amount: 5000,
          category: 'Education',
          title: 'School Fee',
          paidTo: 'ABC School',
          paymentMode: 'UPI',
          paymentReference: '123456789012',
          transactionDate: '2026-09-01',
          createdAt: now,
          updatedAt: now,
        ),
        FamilyUtilize(
          id: 'u2',
          amount: 2500,
          category: 'Electricity',
          title: 'Electricity Bill',
          paidTo: 'NBPDCL',
          paymentMode: 'Cash',
          transactionDate: '2026-09-05',
          createdAt: now,
          updatedAt: now,
        ),
        FamilyUtilize(
          id: 'u3',
          amount: 3000,
          category: 'Medical',
          title: 'Hospital checkup',
          paidTo: 'City Hospital',
          paymentMode: 'Cheque',
          paymentReference: '654321',
          transactionDate: '2026-09-10',
          createdAt: now,
          updatedAt: now,
        ),
        FamilyUtilize(
          id: 'u4',
          amount: 4000,
          category: 'Grocery',
          title: 'Monthly Ration',
          paymentMode: 'Draft',
          paymentReference: '789012',
          transactionDate: '2026-09-15',
          createdAt: now,
          updatedAt: now,
        ),
        FamilyUtilize(
          id: 'u5',
          amount: 6000,
          category: 'House Expense',
          title: 'House Maintenance',
          transactionDate: '2026-09-20',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final totalFamilyUtilized =
          txns.fold<double>(0.0, (sum, item) => sum + item.amount);
      expect(totalFamilyUtilized, 20500); // 5000 + 2500 + 3000 + 4000 + 6000

      const totalReceived = 100000.0;
      const totalReturned = 10000.0;

      final summary = FamilyUtilizeSummary(
        totalReceived: totalReceived,
        totalReturned: totalReturned,
        totalFamilyUtilized: totalFamilyUtilized,
      );

      expect(summary.availableBeforeFamilyUtilize, 90000.0);
      expect(summary.remainingAvailable, 69500.0); // 90000 - 20500
    });

    test('4. Soft-deleted records are excluded from total calculation', () {
      final now = DateTime(2026, 9, 23);
      final txns = [
        FamilyUtilize(
          id: 'u1',
          amount: 5000,
          category: 'Education',
          title: 'Active School Fee',
          transactionDate: '2026-09-01',
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
        FamilyUtilize(
          id: 'u2',
          amount: 15000,
          category: 'Medical',
          title: 'Cancelled Surgery',
          transactionDate: '2026-09-05',
          createdAt: now,
          updatedAt: now,
          isDeleted: true, // Soft deleted
        ),
      ];

      final activeTotal = txns
          .where((t) => !t.isDeleted)
          .fold<double>(0.0, (sum, item) => sum + item.amount);

      expect(activeTotal, 5000.0);
    });

    test('5. FamilyUtilize entity copyWith and preset category matching', () {
      final now = DateTime(2026, 9, 23);
      final item = FamilyUtilize(
        id: 'u1',
        amount: 5000,
        category: 'Education',
        title: 'Tuition Fee',
        paidTo: 'Delhi Public School',
        mobileNumber: '9876543210',
        paymentMode: 'Cash',
        paymentReference: null,
        description: 'Semester 1',
        transactionDate: '2026-09-23',
        createdAt: now,
        updatedAt: now,
      );

      final updated = item.copyWith(
        amount: 6000,
        title: 'Tuition Fee Revised',
        paidTo: 'DPS Kishanganj',
        paymentMode: 'UPI',
        paymentReference: '998877665544',
      );

      expect(updated.id, 'u1');
      expect(updated.amount, 6000);
      expect(updated.title, 'Tuition Fee Revised');
      expect(updated.paidTo, 'DPS Kishanganj');
      expect(updated.mobileNumber, '9876543210');
      expect(updated.paymentMode, 'UPI');
      expect(updated.paymentReference, '998877665544');
      expect(updated.description, 'Semester 1');

      // Preset category
      final eduPreset = FamilyUtilize.getCategoryPreset('Education');
      expect(eduPreset.name, 'Education');

      final unknownPreset = FamilyUtilize.getCategoryPreset('Cryptocurrency');
      expect(unknownPreset.name, 'Other');
    });

    test('6. FamilyUtilizeModel serialization handles new and historical null payment fields safely', () {
      final now = DateTime(2026, 9, 23);

      // Historical record (null payment_mode and payment_reference)
      final historicalMap = {
        'id': 'hist_1',
        'amount': 2500.0,
        'category': 'Electricity',
        'title': 'Old Bill',
        'paid_to': 'NBPDCL',
        'mobile_number': null,
        'description': null,
        'transaction_date': '2026-09-01',
        'payment_mode': null,
        'payment_reference': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_deleted': 0,
      };

      final modelFromHist = FamilyUtilizeModel.fromMap(historicalMap);
      expect(modelFromHist.paymentMode, isNull);
      expect(modelFromHist.paymentReference, isNull);
      final entityFromHist = modelFromHist.toEntity();
      expect(entityFromHist.paymentMode, isNull);
      expect(entityFromHist.paymentReference, isNull);

      // New record with UPI and UTR
      final newEntity = FamilyUtilize(
        id: 'new_1',
        amount: 5000,
        category: 'Education',
        title: 'School Fee',
        paymentMode: 'UPI',
        paymentReference: '123456789012',
        transactionDate: '2026-09-23',
        createdAt: now,
        updatedAt: now,
      );

      final newModel = FamilyUtilizeModel.fromEntity(newEntity);
      final newMap = newModel.toMap();
      expect(newMap['payment_mode'], 'UPI');
      expect(newMap['payment_reference'], '123456789012');

      final deserialized = FamilyUtilizeModel.fromMap(newMap).toEntity();
      expect(deserialized.paymentMode, 'UPI');
      expect(deserialized.paymentReference, '123456789012');
    });
  });
}
