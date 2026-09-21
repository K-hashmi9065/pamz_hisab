import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/fund_ledger/data/datasources/fl_contact_datasource.dart';
import 'package:pamz_khata/feature/fund_ledger/data/datasources/fl_transaction_datasource.dart';
import 'package:pamz_khata/feature/fund_ledger/data/models/fl_contact_model.dart';
import 'package:pamz_khata/feature/fund_ledger/data/models/fl_transaction_model.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';

/// In-memory implementation of FLContactDataSource to test CRUD parity.
class InMemoryFLContactDataSource implements FLContactDataSource {
  final Map<String, FLContactModel> _store = {};

  @override
  Future<List<FLContactModel>> getAll() async {
    return _store.values.where((c) => !c.isDeleted).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<FLContactModel?> findById(String id) async {
    final c = _store[id];
    if (c == null || c.isDeleted) return null;
    return c;
  }

  @override
  Future<bool> existsByMobile(String mobile, {String? excludeId}) async {
    return _store.values.any(
      (c) => !c.isDeleted && c.mobileNumber == mobile && c.id != excludeId,
    );
  }

  @override
  Future<void> insert(FLContactModel model) async {
    _store[model.id] = model;
  }

  @override
  Future<void> update(FLContactModel model) async {
    _store[model.id] = model;
  }

  @override
  Future<void> softDelete(String id) async {
    final existing = _store[id];
    if (existing != null) {
      _store[id] = existing.copyWith(isDeleted: true);
    }
  }
}

/// In-memory implementation of FLTransactionDataSource to test Transaction CRUD parity.
class InMemoryFLTransactionDataSource implements FLTransactionDataSource {
  final Map<String, FLTransactionModel> _store = {};

  @override
  Future<void> insert(FLTransactionModel model) async {
    _store[model.id] = model;
  }

  @override
  Future<List<FLTransactionModel>> getByContact(String contactId) async {
    return _store.values
        .where((t) => t.contactId == contactId && !t.isDeleted)
        .toList()
      ..sort((a, b) => b.txnDate.compareTo(a.txnDate));
  }

  @override
  Future<List<FLTransactionModel>> getAll({
    FLTransactionType? type,
    String? contactId,
    String? fromDate,
    String? toDate,
  }) async {
    return _store.values.where((t) {
      if (t.isDeleted) return false;
      if (type != null && t.type != type.dbValue) return false;
      if (contactId != null && t.contactId != contactId) return false;
      if (fromDate != null && t.txnDate.compareTo(fromDate) < 0) return false;
      if (toDate != null && t.txnDate.compareTo(toDate) > 0) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.txnDate.compareTo(a.txnDate));
  }

  @override
  Future<void> softDelete(String id) async {
    final existing = _store[id];
    if (existing != null) {
      _store[id] = existing.copyWith(isDeleted: true);
    }
  }

  @override
  Future<FLContactTotals> getTotals(String contactId) async {
    double received = 0;
    double utilized = 0;
    double returned = 0;

    for (final t in _store.values) {
      if (t.contactId == contactId && !t.isDeleted) {
        if (t.type == FLTransactionType.received.dbValue) {
          received += t.amount;
        } else if (t.type == FLTransactionType.utilized.dbValue) {
          utilized += t.amount;
        } else if (t.type == FLTransactionType.returned.dbValue) {
          returned += t.amount;
        }
      }
    }

    return FLContactTotals(
      totalReceived: received,
      totalUtilized: utilized,
      totalReturned: returned,
    );
  }

  @override
  Future<FLContactTotals> getGlobalTotals() async {
    double received = 0;
    double utilized = 0;
    double returned = 0;

    for (final t in _store.values) {
      if (!t.isDeleted) {
        if (t.type == FLTransactionType.received.dbValue) {
          received += t.amount;
        } else if (t.type == FLTransactionType.utilized.dbValue) {
          utilized += t.amount;
        } else if (t.type == FLTransactionType.returned.dbValue) {
          returned += t.amount;
        }
      }
    }

    return FLContactTotals(
      totalReceived: received,
      totalUtilized: utilized,
      totalReturned: returned,
    );
  }
}

void main() {
  group('Fund Ledger Datasource & Storage Parity Tests', () {
    late InMemoryFLContactDataSource contactDs;
    late InMemoryFLTransactionDataSource txnDs;

    final now = DateTime(2026, 9, 21);

    setUp(() {
      contactDs = InMemoryFLContactDataSource();
      txnDs = InMemoryFLTransactionDataSource();
    });

    test('1. Contact CRUD: insert, findById, existsByMobile, update, softDelete', () async {
      final contact = FLContact(
        id: 'c1',
        name: 'Zaid Khan',
        mobileNumber: '9876543210',
        aadhaarNumber: '112233445566',
        project: 'Relief',
        createdAt: now,
        updatedAt: now,
      );

      // Insert
      await contactDs.insert(FLContactModel.fromEntity(contact));
      expect(await contactDs.findById('c1'), isNotNull);
      expect(await contactDs.existsByMobile('9876543210'), isTrue);
      expect(await contactDs.existsByMobile('9000000000'), isFalse);

      // Update
      final updated = contact.copyWith(name: 'Zaid Ahmad');
      await contactDs.update(FLContactModel.fromEntity(updated));
      expect((await contactDs.findById('c1'))?.name, equals('Zaid Ahmad'));

      // Soft delete
      await contactDs.softDelete('c1');
      expect(await contactDs.findById('c1'), isNull);
      expect((await contactDs.getAll()).isEmpty, isTrue);
    });

    test('2. Transaction CRUD & Totals Parity (Received, Utilized, Returned)', () async {
      // Received 10,000
      await txnDs.insert(FLTransactionModel.fromEntity(FLTransaction(
        id: 't1',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 10000.0,
        txnDate: '2026-09-01',
        paymentMode: 'Cash',
        createdAt: now,
        updatedAt: now,
      )));

      // Utilized 6,000
      await txnDs.insert(FLTransactionModel.fromEntity(FLTransaction(
        id: 't2',
        contactId: 'c1',
        type: FLTransactionType.utilized,
        amount: 6000.0,
        txnDate: '2026-09-05',
        title: 'Groceries',
        createdAt: now,
        updatedAt: now,
      )));

      // Returned 3,000
      await txnDs.insert(FLTransactionModel.fromEntity(FLTransaction(
        id: 't3',
        contactId: 'c1',
        type: FLTransactionType.returned,
        amount: 3000.0,
        txnDate: '2026-09-10',
        paymentMode: 'UPI',
        paymentReference: 'UPI/12345',
        createdAt: now,
        updatedAt: now,
      )));

      final totals = await txnDs.getTotals('c1');
      expect(totals.totalReceived, equals(10000.0));
      expect(totals.totalUtilized, equals(6000.0));
      expect(totals.totalReturned, equals(3000.0));

      // Available = Received - Returned = 7,000
      final available = totals.totalReceived - totals.totalReturned;
      expect(available, equals(7000.0));

      // History count
      final history = await txnDs.getByContact('c1');
      expect(history.length, equals(3));

      // Soft delete t3 (Returned)
      await txnDs.softDelete('t3');
      final newTotals = await txnDs.getTotals('c1');
      expect(newTotals.totalReturned, equals(0.0));
      expect(newTotals.totalReceived - newTotals.totalReturned, equals(10000.0));
    });
  });
}
