import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/fund_ledger/data/datasources/fl_contact_datasource.dart';
import 'package:pamz_khata/feature/fund_ledger/data/datasources/fl_transaction_datasource.dart';
import 'package:pamz_khata/feature/fund_ledger/data/models/fl_contact_model.dart';
import 'package:pamz_khata/feature/fund_ledger/data/models/fl_transaction_model.dart';
import 'package:pamz_khata/feature/fund_ledger/data/repositories/fl_contact_repository_impl.dart';
import 'package:pamz_khata/feature/fund_ledger/data/repositories/fl_transaction_repository_impl.dart';
import 'package:pamz_khata/feature/fund_ledger/data/services/fl_pdf_service.dart';
import 'package:pamz_khata/feature/fund_ledger/data/services/fl_share_service.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_share_statement.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';

class ThrowingContactDataSource implements FLContactDataSource {
  @override
  Future<List<FLContactModel>> getAll() => throw Exception('GetAll exploded');

  @override
  Future<FLContactModel?> findById(String id) => throw Exception('Find exploded');

  @override
  Future<bool> existsByMobile(String mobile, {String? excludeId}) => throw Exception('Exists exploded');

  @override
  Future<void> insert(FLContactModel model) => throw Exception('Insert exploded');

  @override
  Future<void> update(FLContactModel model) => throw Exception('Update exploded');

  @override
  Future<void> softDelete(String id) => throw Exception('Delete exploded');
}

class ThrowingTransactionDataSource implements FLTransactionDataSource {
  @override
  Future<List<FLTransactionModel>> getByContact(String contactId) => throw Exception('GetByContact exploded');

  @override
  Future<List<FLTransactionModel>> getAll({
    FLTransactionType? type,
    String? contactId,
    String? fromDate,
    String? toDate,
  }) => throw Exception('GetAll exploded');

  @override
  Future<void> insert(FLTransactionModel model) => throw Exception('Insert exploded');

  @override
  Future<void> update(FLTransactionModel model) => throw Exception('Update exploded');

  @override
  Future<void> softDelete(String id) => throw Exception('Delete exploded');

  @override
  Future<FLContactTotals> getTotals(String contactId) => throw Exception('GetTotals exploded');

  @override
  Future<FLContactTotals> getGlobalTotals() => throw Exception('GetGlobalTotals exploded');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FLContactRepositoryImpl Error & Success Paths', () {
    test('Handles exceptions gracefully and returns DatabaseFailure', () async {
      final repo = FLContactRepositoryImpl(ThrowingContactDataSource());
      final now = DateTime(2026, 9, 21);
      final contact = FLContact(id: 'c1', name: 'Test', mobileNumber: '9876543210', createdAt: now, updatedAt: now);

      expect((await repo.getAll()).isLeft(), isTrue);
      expect((await repo.findById('c1')).isLeft(), isTrue);
      expect((await repo.existsByMobile('9876543210')).isLeft(), isTrue);
      expect((await repo.insert(contact)).isLeft(), isTrue);
      expect((await repo.update(contact)).isLeft(), isTrue);
      expect((await repo.softDelete('c1')).isLeft(), isTrue);
    });
  });

  group('FLTransactionRepositoryImpl Error & Success Paths', () {
    test('Handles exceptions gracefully and returns DatabaseFailure', () async {
      final repo = FLTransactionRepositoryImpl(ThrowingTransactionDataSource());
      final now = DateTime(2026, 9, 21);
      final txn = FLTransaction(
        id: 't1',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 500,
        txnDate: '2026-09-21',
        paymentMode: 'Cash',
        createdAt: now,
        updatedAt: now,
      );

      expect((await repo.getByContact('c1')).isLeft(), isTrue);
      expect((await repo.getAll()).isLeft(), isTrue);
      expect((await repo.insert(txn)).isLeft(), isTrue);
      expect((await repo.update(txn)).isLeft(), isTrue);
      expect((await repo.softDelete('t1')).isLeft(), isTrue);
      expect((await repo.getTotals('c1')).isLeft(), isTrue);
      expect((await repo.getGlobalTotals()).isLeft(), isTrue);
    });
  });

  group('FLShareService Tests', () {
    test('shareStatement returns safely on invalid PDF environment', () async {
      const shareService = FLShareService(pdfService: FLPdfService());
      const statement = FLShareStatement(
        contactName: 'Zaid Khan',
        mobileNumber: '9876543210',
        aadhaarNumber: '112233445566',
        receivedEntries: [],
        returnedEntries: [],
      );

      // In unit test environment without real channel, it should return without crashing
      final res = await shareService.shareStatement(statement);
      expect(res, isA<bool>());
    });
  });
}
