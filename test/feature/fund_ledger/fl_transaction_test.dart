import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/fund_ledger/data/models/fl_transaction_model.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';

void main() {
  group('FLTransaction Entity & Model Tests', () {
    final now = DateTime(2026, 9, 21, 11, 30);

    test('1. FLTransactionType dbValue and fromDb serialization', () {
      expect(FLTransactionType.received.dbValue, equals('received'));
      expect(FLTransactionType.utilized.dbValue, equals('utilized'));
      expect(FLTransactionType.returned.dbValue, equals('returned'));

      expect(FLTransactionType.fromDb('received'), equals(FLTransactionType.received));
      expect(FLTransactionType.fromDb('utilized'), equals(FLTransactionType.utilized));
      expect(FLTransactionType.fromDb('returned'), equals(FLTransactionType.returned));

      expect(() => FLTransactionType.fromDb('unknown'), throwsArgumentError);
    });

    test('2. FLTransactionType labels are user-friendly', () {
      expect(FLTransactionType.received.label, equals('Received'));
      expect(FLTransactionType.utilized.label, equals('Utilized'));
      expect(FLTransactionType.returned.label, equals('Returned'));
    });

    test('3. FLTransaction received model mapping round-trip', () {
      final txn = FLTransaction(
        id: 'txn-001',
        contactId: 'contact-001',
        type: FLTransactionType.received,
        amount: 25000.0,
        txnDate: '2026-09-21',
        txnTime: '11:30',
        paymentMode: 'UPI',
        paymentReference: 'UPI/123456789',
        note: 'Initial deposit',
        createdAt: now,
        updatedAt: now,
      );

      final model = FLTransactionModel.fromEntity(txn);
      final map = model.toMap();

      expect(map['id'], equals('txn-001'));
      expect(map['contact_id'], equals('contact-001'));
      expect(map['type'], equals('received'));
      expect(map['amount'], equals(25000.0));
      expect(map['txn_date'], equals('2026-09-21'));
      expect(map['payment_mode'], equals('UPI'));
      expect(map['payment_reference'], equals('UPI/123456789'));

      final restoredEntity = FLTransactionModel.fromMap(map).toEntity();
      expect(restoredEntity.id, equals(txn.id));
      expect(restoredEntity.amount, equals(25000.0));
      expect(restoredEntity.type, equals(FLTransactionType.received));
      expect(restoredEntity.paymentMode, equals('UPI'));
    });

    test('4. FLTransaction utilized model mapping round-trip', () {
      final txn = FLTransaction(
        id: 'txn-002',
        contactId: 'contact-001',
        type: FLTransactionType.utilized,
        amount: 8500.0,
        txnDate: '2026-09-22',
        title: 'Emergency Medical Supplies',
        description: 'Medicines and equipment for clinic',
        createdAt: now,
        updatedAt: now,
      );

      final model = FLTransactionModel.fromEntity(txn);
      final map = model.toMap();

      expect(map['type'], equals('utilized'));
      expect(map['title'], equals('Emergency Medical Supplies'));
      expect(map['description'], equals('Medicines and equipment for clinic'));

      final restored = FLTransactionModel.fromMap(map).toEntity();
      expect(restored.type, equals(FLTransactionType.utilized));
      expect(restored.title, equals('Emergency Medical Supplies'));
      expect(restored.description, equals('Medicines and equipment for clinic'));
    });

    test('5. FLTransaction returned model mapping round-trip', () {
      final txn = FLTransaction(
        id: 'txn-003',
        contactId: 'contact-001',
        type: FLTransactionType.returned,
        amount: 5000.0,
        txnDate: '2026-09-23',
        paymentMode: 'Bank Transfer',
        paymentReference: 'IMPS/99887766',
        note: 'Refund of surplus',
        createdAt: now,
        updatedAt: now,
      );

      final model = FLTransactionModel.fromEntity(txn);
      final map = model.toMap();

      expect(map['type'], equals('returned'));
      expect(map['amount'], equals(5000.0));
      expect(map['payment_mode'], equals('Bank Transfer'));

      final restored = FLTransactionModel.fromMap(map).toEntity();
      expect(restored.type, equals(FLTransactionType.returned));
      expect(restored.amount, equals(5000.0));
    });
  });
}
