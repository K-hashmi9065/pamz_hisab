import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/usecases/direct_udhar_usecases.dart';

import '../../../../test_helpers/fixtures.dart';
import '../../../../test_helpers/mocks.dart';

void main() {
  late MockDirectUdharRepository repository;
  late CreateDirectLoanUsecase usecase;

  setUpAll(registerFallbacks);

  setUp(() {
    repository = MockDirectUdharRepository();
    usecase = CreateDirectLoanUsecase(repository);
  });

  group('CreateDirectLoanUsecase Validation & Initialization', () {
    test('rejects loan when principalAmount is zero', () async {
      final loan = directUdharLoanFixture.copyWith(principalAmount: 0);

      final result = await usecase(loan);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'principalAmount');
          expect(failure.message, 'Amount must be greater than zero.');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.create(any()));
    });

    test('rejects loan when principalAmount is negative', () async {
      final loan = directUdharLoanFixture.copyWith(principalAmount: -500);

      final result = await usecase(loan);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'principalAmount');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.create(any()));
    });

    test('rejects simple-interest loan when interestRatePercent is null', () async {
      final loan = DirectUdharLoan(
        id: 'loan-simple-no-rate',
        contactId: 'contact-001',
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: null,
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final result = await usecase(loan);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'interestRatePercent');
          expect(failure.message, 'Interest rate is required for simple interest loans.');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.create(any()));
    });

    test('rejects simple-interest loan when interestRatePercent is zero or negative', () async {
      final loan = DirectUdharLoan(
        id: 'loan-simple-zero-rate',
        contactId: 'contact-001',
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 0.0,
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final result = await usecase(loan);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'interestRatePercent');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.create(any()));
    });

    test('valid interest-free loan initializes outstandingBalance and open status and reaches repository', () async {
      final inputLoan = DirectUdharLoan(
        id: 'loan-valid-1',
        contactId: 'contact-001',
        direction: LoanDirection.lent,
        principalAmount: 25000,
        interestType: InterestType.interestFree,
        memo: 'Cash loan for shop stock',
        status: LoanStatus.closed, // initially different status to verify usecase forces open
        outstandingBalance: 0, // initially 0 to verify usecase sets principalAmount
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 1, 10),
      );

      when(() => repository.create(any())).thenAnswer(
        (invocation) async => right(invocation.positionalArguments[0] as DirectUdharLoan),
      );

      final result = await usecase(inputLoan);

      expect(result.isRight(), isTrue);
      result.match(
        (l) => fail('Should have succeeded: ${l.message}'),
        (createdLoan) {
          expect(createdLoan.id, 'loan-valid-1');
          expect(createdLoan.principalAmount, 25000);
          expect(createdLoan.outstandingBalance, 25000);
          expect(createdLoan.status, LoanStatus.open);
          expect(createdLoan.direction, LoanDirection.lent);
          expect(createdLoan.interestType, InterestType.interestFree);
        },
      );

      verify(() => repository.create(any(
            that: isA<DirectUdharLoan>()
                .having((l) => l.principalAmount, 'principalAmount', 25000)
                .having((l) => l.outstandingBalance, 'outstandingBalance', 25000)
                .having((l) => l.status, 'status', LoanStatus.open),
          ))).called(1);
    });

    test('valid simple-interest borrowed loan preserves rate, dueDate and initializes correctly', () async {
      final dueDate = DateTime(2026, 6, 30);
      final inputLoan = DirectUdharLoan(
        id: 'loan-borrowed-1',
        contactId: 'contact-002',
        direction: LoanDirection.borrowed,
        principalAmount: 50000,
        interestType: InterestType.simple,
        interestRatePercent: 2.5,
        dueDate: dueDate,
        memo: 'Agricultural loan',
        status: LoanStatus.closed,
        outstandingBalance: 0,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      when(() => repository.create(any())).thenAnswer(
        (invocation) async => right(invocation.positionalArguments[0] as DirectUdharLoan),
      );

      final result = await usecase(inputLoan);

      expect(result.isRight(), isTrue);
      result.match(
        (l) => fail('Should have succeeded: ${l.message}'),
        (createdLoan) {
          expect(createdLoan.principalAmount, 50000);
          expect(createdLoan.outstandingBalance, 50000);
          expect(createdLoan.status, LoanStatus.open);
          expect(createdLoan.direction, LoanDirection.borrowed);
          expect(createdLoan.interestType, InterestType.simple);
          expect(createdLoan.interestRatePercent, 2.5);
          expect(createdLoan.dueDate, dueDate);
        },
      );

      verify(() => repository.create(any(
            that: isA<DirectUdharLoan>()
                .having((l) => l.direction, 'direction', LoanDirection.borrowed)
                .having((l) => l.interestRatePercent, 'interestRatePercent', 2.5)
                .having((l) => l.outstandingBalance, 'outstandingBalance', 50000)
                .having((l) => l.status, 'status', LoanStatus.open),
          ))).called(1);
    });
  });
}
