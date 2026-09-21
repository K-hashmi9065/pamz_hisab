import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_contact_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/usecases/fl_contact_usecases.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/usecases/fl_transaction_usecases.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_contact_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_transaction_providers.dart';

class MockFLContactRepository implements FLContactRepository {
  final List<FLContact> contacts = [];
  bool shouldFail = false;

  @override
  Future<Either<Failure, void>> insert(FLContact contact) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB failed'));
    contacts.add(contact);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> update(FLContact contact) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB update failed'));
    final idx = contacts.indexWhere((c) => c.id == contact.id);
    if (idx != -1) contacts[idx] = contact;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB delete failed'));
    contacts.removeWhere((c) => c.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, FLContact?>> findById(String id) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB find failed'));
    final found = contacts.where((c) => c.id == id).firstOrNull;
    return Right(found);
  }

  @override
  Future<Either<Failure, List<FLContact>>> getAll() async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB getAll failed'));
    return Right(List.from(contacts));
  }

  @override
  Future<Either<Failure, bool>> existsByMobile(String mobileNumber, {String? excludeId}) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB exists failed'));
    final exists = contacts.any((c) => c.mobileNumber == mobileNumber && c.id != excludeId);
    return Right(exists);
  }
}

class MockFLTransactionRepository implements FLTransactionRepository {
  final List<FLTransaction> txns = [];
  bool shouldFail = false;

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB txn insert failed'));
    txns.add(transaction);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB txn delete failed'));
    txns.removeWhere((t) => t.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<FLTransaction>>> getByContact(String contactId) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB getByContact failed'));
    return Right(txns.where((t) => t.contactId == contactId).toList());
  }

  @override
  Future<Either<Failure, List<FLTransaction>>> getAll({
    FLTransactionType? type,
    String? contactId,
    DateTime? from,
    DateTime? to,
  }) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB getAll failed'));
    return Right(List.from(txns));
  }

  @override
  Future<Either<Failure, FLContactTotals>> getTotals(String contactId) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB getTotals failed'));
    double rec = 0, uti = 0, ret = 0;
    for (final t in txns.where((t) => t.contactId == contactId)) {
      if (t.type == FLTransactionType.received) rec += t.amount;
      if (t.type == FLTransactionType.utilized) uti += t.amount;
      if (t.type == FLTransactionType.returned) ret += t.amount;
    }
    return Right(FLContactTotals(totalReceived: rec, totalUtilized: uti, totalReturned: ret));
  }

  @override
  Future<Either<Failure, FLContactTotals>> getGlobalTotals() async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'DB getGlobalTotals failed'));
    double rec = 0, uti = 0, ret = 0;
    for (final t in txns) {
      if (t.type == FLTransactionType.received) rec += t.amount;
      if (t.type == FLTransactionType.utilized) uti += t.amount;
      if (t.type == FLTransactionType.returned) ret += t.amount;
    }
    return Right(FLContactTotals(totalReceived: rec, totalUtilized: uti, totalReturned: ret));
  }
}

void main() {
  group('FL Contact Usecases & Validation Tests', () {
    late MockFLContactRepository repo;
    final now = DateTime(2026, 9, 21);

    setUp(() {
      repo = MockFLContactRepository();
    });

    test('CreateFLContactUsecase validates empty name, invalid mobile, and duplicate mobile', () async {
      final usecase = CreateFLContactUsecase(repo);

      // Empty name
      final emptyNameRes = await usecase(FLContact(
        id: '',
        name: '   ',
        mobileNumber: '9876543210',
        createdAt: now,
        updatedAt: now,
      ));
      expect(emptyNameRes.isLeft(), isTrue);

      // Invalid mobile
      final invalidMobileRes = await usecase(FLContact(
        id: '',
        name: 'Valid Name',
        mobileNumber: '123',
        createdAt: now,
        updatedAt: now,
      ));
      expect(invalidMobileRes.isLeft(), isTrue);

      // Successful insert
      final successRes = await usecase(FLContact(
        id: 'c1',
        name: 'Valid Name',
        mobileNumber: '9876543210',
        createdAt: now,
        updatedAt: now,
      ));
      expect(successRes.isRight(), isTrue);

      // Duplicate phone failure
      final duplicateRes = await usecase(FLContact(
        id: 'c2',
        name: 'Another Name',
        mobileNumber: '9876543210',
        createdAt: now,
        updatedAt: now,
      ));
      expect(duplicateRes.isLeft(), isTrue);
    });

    test('UpdateFLContactUsecase validates name, mobile, and handles excludeId duplicate check', () async {
      final usecase = UpdateFLContactUsecase(repo);
      await repo.insert(FLContact(id: 'c1', name: 'Zaid', mobileNumber: '9876543210', createdAt: now, updatedAt: now));
      await repo.insert(FLContact(id: 'c2', name: 'Bilal', mobileNumber: '9876543211', createdAt: now, updatedAt: now));

      // Empty name update
      final emptyRes = await usecase(FLContact(id: 'c1', name: '', mobileNumber: '9876543210', createdAt: now, updatedAt: now));
      expect(emptyRes.isLeft(), isTrue);

      // Invalid mobile update
      final invalidMobRes = await usecase(FLContact(id: 'c1', name: 'Zaid', mobileNumber: 'abc', createdAt: now, updatedAt: now));
      expect(invalidMobRes.isLeft(), isTrue);

      // Duplicate mobile of c2
      final dupRes = await usecase(FLContact(id: 'c1', name: 'Zaid', mobileNumber: '9876543211', createdAt: now, updatedAt: now));
      expect(dupRes.isLeft(), isTrue);

      // Same mobile on c1 (allowed)
      final sameRes = await usecase(FLContact(id: 'c1', name: 'Zaid Updated', mobileNumber: '9876543210', createdAt: now, updatedAt: now));
      expect(sameRes.isRight(), isTrue);
    });

    test('GetFLContacts, GetById, and Delete usecases invoke repository correctly', () async {
      final getContacts = GetFLContactsUsecase(repo);
      final getById = GetFLContactByIdUsecase(repo);
      final deleteContact = DeleteFLContactUsecase(repo);

      await repo.insert(FLContact(id: 'c1', name: 'Zaid', mobileNumber: '9876543210', createdAt: now, updatedAt: now));

      expect((await getContacts()).getOrElse((_) => []).length, equals(1));
      expect((await getById('c1')).getOrElse((_) => null)?.name, equals('Zaid'));

      await deleteContact('c1');
      expect((await getContacts()).getOrElse((_) => []).isEmpty, isTrue);
    });

    test('validateAadhaar handles null, valid 12-digit, and invalid formats', () {
      expect(validateAadhaar(null), isNull);
      expect(validateAadhaar(''), isNull);
      expect(validateAadhaar('123456789012'), isNull);
      expect(validateAadhaar('1234 5678 9012'), isNull);
      expect(validateAadhaar('12345'), isNotNull);
      expect(validateAadhaar('123456789012345'), isNotNull);
      expect(validateAadhaar('12345678901A'), isNotNull);
    });
  });

  group('FL Transaction Usecases & Business Rule Tests', () {
    late MockFLTransactionRepository txnRepo;
    final now = DateTime(2026, 9, 21);

    setUp(() {
      txnRepo = MockFLTransactionRepository();
    });

    test('AddFLTransactionUsecase validates positive amount, payment modes, and title requirement', () async {
      final usecase = AddFLTransactionUsecase(txnRepo);

      // Non-positive amount
      final zeroAmtRes = await usecase(FLTransaction(
        id: '',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 0,
        txnDate: '2026-09-21',
        paymentMode: 'cash',
        createdAt: now,
        updatedAt: now,
      ));
      expect(zeroAmtRes.isLeft(), isTrue);

      // Missing payment mode on Received
      final missingModeRes = await usecase(FLTransaction(
        id: '',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 500,
        txnDate: '2026-09-21',
        paymentMode: '',
        createdAt: now,
        updatedAt: now,
      ));
      expect(missingModeRes.isLeft(), isTrue);

      // UPI without reference
      final upiNoRefRes = await usecase(FLTransaction(
        id: '',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 500,
        txnDate: '2026-09-21',
        paymentMode: 'upi',
        paymentReference: '',
        createdAt: now,
        updatedAt: now,
      ));
      expect(upiNoRefRes.isLeft(), isTrue);

      // Utilized without title
      final utilNoTitleRes = await usecase(FLTransaction(
        id: '',
        contactId: 'c1',
        type: FLTransactionType.utilized,
        amount: 500,
        txnDate: '2026-09-21',
        title: '',
        createdAt: now,
        updatedAt: now,
      ));
      expect(utilNoTitleRes.isLeft(), isTrue);
    });

    test('AddFLTransactionUsecase rejects Return > Available Amount', () async {
      final usecase = AddFLTransactionUsecase(txnRepo);

      // Receive 5000
      await usecase(FLTransaction(
        id: 't1',
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 5000,
        txnDate: '2026-09-21',
        paymentMode: 'cash',
        createdAt: now,
        updatedAt: now,
      ));

      // Attempt to return 6000 (exceeds available 5000)
      final returnExcessRes = await usecase(FLTransaction(
        id: 't2',
        contactId: 'c1',
        type: FLTransactionType.returned,
        amount: 6000,
        txnDate: '2026-09-21',
        paymentMode: 'cash',
        createdAt: now,
        updatedAt: now,
      ));
      expect(returnExcessRes.isLeft(), isTrue);

      // Valid return 5000
      final validReturnRes = await usecase(FLTransaction(
        id: 't3',
        contactId: 'c1',
        type: FLTransactionType.returned,
        amount: 5000,
        txnDate: '2026-09-21',
        paymentMode: 'cash',
        createdAt: now,
        updatedAt: now,
      ));
      expect(validReturnRes.isRight(), isTrue);
    });

    test('FLPaymentMode helpers return correct labels and reference requirements', () {
      expect(FLPaymentMode.label('cash'), equals('Cash'));
      expect(FLPaymentMode.label('upi'), equals('UPI'));
      expect(FLPaymentMode.label('cheque'), equals('Cheque'));
      expect(FLPaymentMode.label('draft'), equals('Draft'));
      expect(FLPaymentMode.label('other'), equals('other'));

      expect(FLPaymentMode.referenceLabel('cash'), isNull);
      expect(FLPaymentMode.referenceLabel('upi'), equals('UTR Number'));
      expect(FLPaymentMode.referenceLabel('cheque'), equals('Cheque Number'));
      expect(FLPaymentMode.referenceLabel('draft'), equals('Draft Number'));

      expect(FLPaymentMode.requiresReference('cash'), isFalse);
      expect(FLPaymentMode.requiresReference('upi'), isTrue);
      expect(FLPaymentMode.requiresReference('cheque'), isTrue);
      expect(FLPaymentMode.requiresReference('draft'), isTrue);
    });
  });

  group('FL Providers & State Notifiers Tests', () {
    late MockFLContactRepository contactRepo;
    late MockFLTransactionRepository txnRepo;
    late ProviderContainer container;
    final now = DateTime(2026, 9, 21);

    setUp(() {
      contactRepo = MockFLContactRepository();
      txnRepo = MockFLTransactionRepository();
      container = ProviderContainer(
        overrides: [
          flContactRepositoryProvider.overrideWithValue(contactRepo),
          flTransactionRepositoryProvider.overrideWithValue(txnRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('FLContactFormNotifier create, update, and delete flow with provider invalidation', () async {
      final notifier = container.read(flContactFormNotifierProvider.notifier);
      final contact = FLContact(id: 'c1', name: 'Zaid', mobileNumber: '9876543210', createdAt: now, updatedAt: now);

      final createSuccess = await notifier.createContact(contact);
      expect(createSuccess, isTrue);
      expect(contactRepo.contacts.length, equals(1));

      final updateSuccess = await notifier.updateContact(contact.copyWith(name: 'Zaid K'));
      expect(updateSuccess, isTrue);
      expect(contactRepo.contacts.first.name, equals('Zaid K'));

      final deleteSuccess = await notifier.deleteContact('c1');
      expect(deleteSuccess, isTrue);
      expect(contactRepo.contacts.isEmpty, isTrue);
    });

    test('FLTransactionFormNotifier add and delete flow with provider invalidation', () async {
      final notifier = container.read(flTransactionFormNotifierProvider.notifier);

      final addSuccess = await notifier.add(
        contactId: 'c1',
        type: FLTransactionType.received,
        amount: 2500,
        txnDate: '2026-09-21',
        paymentMode: 'cash',
      );
      expect(addSuccess, isTrue);
      expect(txnRepo.txns.length, equals(1));

      final delSuccess = await notifier.delete(txnRepo.txns.first.id, 'c1');
      expect(delSuccess, isTrue);
      expect(txnRepo.txns.isEmpty, isTrue);
    });

    test('Search and Reports Filters work properly', () async {
      await contactRepo.insert(FLContact(id: 'c1', name: 'Alpha', mobileNumber: '9876543210', project: 'Relief', createdAt: now, updatedAt: now));
      await contactRepo.insert(FLContact(id: 'c2', name: 'Beta', mobileNumber: '9123456780', project: 'Education', createdAt: now, updatedAt: now));

      // Initial list
      final initial = await container.read(flContactListProvider.future);
      expect(initial.length, equals(2));

      // Filter query
      container.read(flContactSearchQueryProvider.notifier).state = 'beta';
      final filtered = container.read(flFilteredContactListProvider);
      expect(filtered.value?.length, equals(1));
      expect(filtered.value?.first.name, equals('Beta'));
    });
  });
}
