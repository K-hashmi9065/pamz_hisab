import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/feature/direct_udhar/data/models/direct_udhar_models.dart';
import 'package:pamz_khata/feature/direct_udhar/data/repositories/direct_udhar_hive_repository_impl.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';

void main() {
  late Directory tempDir;
  late DirectUdharHiveRepositoryImpl repository;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('direct_udhar_ext_test_');
    Hive.init(tempDir.path);
    await HiveRegistrar.initialize(tempDir.path);
    repository = const DirectUdharHiveRepositoryImpl();
  });

  tearDownAll(() async {
    // Keep clean teardown
  });

  group('DirectUdharLoan & Repayment Entity & Model Tests', () {
    test('1. DirectUdharLoan entity getters, copyWith, equality, and status computation', () {
      final pastDate = DateTime(2026, 1, 1);
      final futureDate = DateTime(2026, 12, 1);

      final openSimpleLoan = DirectUdharLoan(
        id: 'loan-1',
        contactId: 'c1',
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        dueDate: pastDate,
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: pastDate,
        updatedAt: pastDate,
      );

      expect(openSimpleLoan.isOpen, isTrue);
      expect(openSimpleLoan.isClosed, isFalse);
      expect(openSimpleLoan.isOverdue, isTrue);
      expect(openSimpleLoan.isSimpleInterest, isTrue);
      expect(openSimpleLoan.isInterestFree, isFalse);

      final closedLoan = openSimpleLoan.copyWith(
        status: LoanStatus.closed,
        interestType: InterestType.interestFree,
        interestRatePercent: 0,
        dueDate: futureDate,
      );

      expect(closedLoan.isOpen, isFalse);
      expect(closedLoan.isClosed, isTrue);
      expect(closedLoan.isOverdue, isFalse);
      expect(closedLoan.isSimpleInterest, isFalse);
      expect(closedLoan.isInterestFree, isTrue);

      expect(openSimpleLoan == openSimpleLoan.copyWith(), isTrue);
      expect(openSimpleLoan == closedLoan, isTrue); // Same ID equality
      expect(openSimpleLoan.hashCode, 'loan-1'.hashCode);
    });

    test('2. Repayment entity copyWith and equality', () {
      final rep = Repayment(
        id: 'rep-1',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: 'loan-1',
        amount: 5000,
        paymentMode: 'cash',
        paidAt: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
      );

      final copied = rep.copyWith(amount: 6000, memo: 'Updated repayment');
      expect(copied.amount, 6000);
      expect(copied.memo, 'Updated repayment');
      expect(rep == copied, isTrue);
      expect(rep.hashCode, 'rep-1'.hashCode);
    });

    test('3. DirectUdharLoanModel and RepaymentModel DTO conversion toMap, fromMap, toEntity, fromEntity', () {
      final loanEntity = DirectUdharLoan(
        id: 'loan-dto-1',
        contactId: 'c-100',
        direction: LoanDirection.borrowed,
        principalAmount: 50000,
        interestType: InterestType.simple,
        interestRatePercent: 1.5,
        dueDate: DateTime(2026, 6, 1),
        memo: 'Raw material procurement',
        status: LoanStatus.partiallyPaid,
        outstandingBalance: 25000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final dto = DirectUdharLoanModel.fromEntity(loanEntity);
      expect(dto.id, 'loan-dto-1');
      expect(dto.direction, 'borrowed');
      expect(dto.status, 'partially_paid');

      final map = dto.toMap();
      expect(map['principal_amount'], 50000.0);
      expect(map['interest_type'], 'simple');

      final deserializedDto = DirectUdharLoanModel.fromMap(map);
      final reconstructedEntity = deserializedDto.toEntity();

      expect(reconstructedEntity.id, loanEntity.id);
      expect(reconstructedEntity.direction, loanEntity.direction);
      expect(reconstructedEntity.status, loanEntity.status);
      expect(reconstructedEntity.principalAmount, loanEntity.principalAmount);

      final repModel = RepaymentModel(
        id: 'rep-dto-1',
        sourceType: 'direct_udhar',
        sourceId: 'loan-dto-1',
        amount: 25000,
        paymentMode: 'gpay',
        paidAt: DateTime(2026, 2, 1).toIso8601String(),
        createdAt: DateTime(2026, 2, 1).toIso8601String(),
      );

      final repMap = repModel.toMap();
      final deserializedRep = RepaymentModel.fromMap(repMap);
      final repEntity = deserializedRep.toEntity();

      expect(repEntity.id, 'rep-dto-1');
      expect(repEntity.sourceType, RepaymentSourceType.directUdhar);
      expect(repEntity.amount, 25000.0);
    });
  });

  group('DirectUdharHiveRepositoryImpl Lifecycle & Queries', () {
    test('4. Create, findById, and getByContact with active and soft-deleted records', () async {
      final loan1 = DirectUdharLoan(
        id: 'hive-loan-1',
        contactId: 'contact-alpha',
        direction: LoanDirection.lent,
        principalAmount: 20000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 20000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final loan2 = DirectUdharLoan(
        id: 'hive-loan-2',
        contactId: 'contact-alpha',
        direction: LoanDirection.borrowed,
        principalAmount: 8000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0,
        status: LoanStatus.open,
        outstandingBalance: 8000,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      // Create loans
      final createRes1 = await repository.create(loan1);
      final createRes2 = await repository.create(loan2);

      expect(createRes1.isRight(), isTrue);
      expect(createRes2.isRight(), isTrue);

      // Find by ID
      final found = await repository.findById('hive-loan-1');
      expect(found.isRight(), isTrue);
      expect(found.getOrElse((_) => null)?.principalAmount, 20000.0);

      // Non-existent ID returns null
      final notFound = await repository.findById('non-existent-loan');
      expect(notFound.isRight(), isTrue);
      expect(notFound.getOrElse((_) => null), isNull);

      // Get by contact
      final contactLoans = await repository.getByContact('contact-alpha');
      expect(contactLoans.isRight(), isTrue);
      final list = contactLoans.getOrElse((_) => []);
      expect(list.length, 2);

      // Update
      final updatedLoan1 = loan1.copyWith(principalAmount: 22000);
      final updateRes = await repository.update(updatedLoan1);
      expect(updateRes.isRight(), isTrue);
      final verifiedUpdate = await repository.findById('hive-loan-1');
      expect(verifiedUpdate.getOrElse((_) => null)?.principalAmount, 22000.0);

      // Update Status
      final statusRes = await repository.updateStatus('hive-loan-1', LoanStatus.closed);
      expect(statusRes.isRight(), isTrue);
      final verifiedStatus = await repository.findById('hive-loan-1');
      expect(verifiedStatus.getOrElse((_) => null)?.status, LoanStatus.closed);

      // Soft delete
      final deleteRes = await repository.delete('hive-loan-2');
      expect(deleteRes.isRight(), isTrue);
      final checkDeleted = await repository.findById('hive-loan-2');
      expect(checkDeleted.getOrElse((_) => null), isNull);

      final remaining = await repository.getByContact('contact-alpha');
      expect(remaining.getOrElse((_) => []).length, 1);
    });

    test('5. RecordRepayment and getRepayments for loan', () async {
      final loan = DirectUdharLoan(
        id: 'repay-loan-1',
        contactId: 'contact-beta',
        direction: LoanDirection.lent,
        principalAmount: 15000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 15000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await repository.create(loan);

      final repayment = Repayment(
        id: 'rep-hive-1',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: 'repay-loan-1',
        amount: 5000,
        paymentMode: 'cash',
        paidAt: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
      );

      final repayRes = await repository.recordRepayment('repay-loan-1', repayment);
      expect(repayRes.isRight(), isTrue);

      // Verify updated loan balance and status
      final updatedLoan = await repository.findById('repay-loan-1');
      expect(updatedLoan.getOrElse((_) => null)?.outstandingBalance, 10000.0);
      expect(updatedLoan.getOrElse((_) => null)?.status, LoanStatus.partiallyPaid);

      // Fetch repayments
      final repListRes = await repository.getRepayments('repay-loan-1');
      expect(repListRes.isRight(), isTrue);
      final repList = repListRes.getOrElse((_) => []);
      expect(repList.length, 1);
      expect(repList.first.amount, 5000.0);
    });
  });
}
