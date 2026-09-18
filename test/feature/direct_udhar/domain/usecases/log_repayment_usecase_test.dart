import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/services/interest_calculator.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/usecases/direct_udhar_usecases.dart';

import '../../../../test_helpers/fixtures.dart';
import '../../../../test_helpers/mocks.dart';

void main() {
  late MockDirectUdharRepository repository;
  late LogRepaymentUsecase usecase;

  setUpAll(registerFallbacks);

  setUp(() {
    repository = MockDirectUdharRepository();
    usecase = LogRepaymentUsecase(repository);
    when(() => repository.getRepayments(any()))
        .thenAnswer((_) async => right([]));
  });

  group('LogRepaymentUsecase', () {
    test('partial repayment reduces outstanding balance (via recordRepayment)', () async {
      final loan = directUdharLoanFixture.copyWith(
        principalAmount: 10000,
        outstandingBalance: 10000,
        status: LoanStatus.open,
      );

      when(() => repository.findById(loan.id))
          .thenAnswer((_) async => right(loan));
      when(() => repository.recordRepayment(any(), any()))
          .thenAnswer((_) async => right(null));

      final result = await usecase(
        loanId: loan.id,
        amount: 4000,
        mode: 'cash',
      );

      expect(result.isRight(), true);
      verify(() => repository.recordRepayment(loan.id, any())).called(1);
      // Status management is delegated to recordRepayment / allocateRepayment
      verifyNever(() => repository.updateStatus(any(), any()));
    });

    test('full repayment records repayment successfully (delegates status to recordRepayment)', () async {
      final loan = directUdharLoanFixture.copyWith(
        outstandingBalance: 500,
        status: LoanStatus.open,
      );

      when(() => repository.findById(loan.id))
          .thenAnswer((_) async => right(loan));
      when(() => repository.recordRepayment(any(), any()))
          .thenAnswer((_) async => right(null));

      final result = await usecase(
        loanId: loan.id,
        amount: 500,
        mode: 'cash',
      );

      expect(result.isRight(), true);
      verify(() => repository.recordRepayment(loan.id, any())).called(1);
      verifyNever(() => repository.updateStatus(any(), any()));
    });

    test('repayment exactly equal to total outstanding succeeds via recordRepayment', () async {
      final loan = directUdharLoanFixture.copyWith(outstandingBalance: 2000);

      when(() => repository.findById(loan.id))
          .thenAnswer((_) async => right(loan));
      when(() => repository.recordRepayment(any(), any()))
          .thenAnswer((_) async => right(null));

      final result = await usecase(loanId: loan.id, amount: 2000, mode: 'upi');

      expect(result.isRight(), true);
      verify(() => repository.recordRepayment(loan.id, any())).called(1);
      verifyNever(() => repository.updateStatus(any(), any()));
    });

    test('simple interest loan repayment can cover accrued interest + principal', () async {
      final startDate = DateTime(2026, 1, 1);
      final paymentDate = DateTime(2026, 1, 31); // 30 days elapsed

      final loan = DirectUdharLoan(
        id: 'loan-interest',
        contactId: 'contact-1',
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 2.0, // 2% per month
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: startDate,
        updatedAt: startDate,
      );

      when(() => repository.findById(loan.id))
          .thenAnswer((_) async => right(loan));
      when(() => repository.getRepayments(loan.id))
          .thenAnswer((_) async => right([]));
      when(() => repository.recordRepayment(any(), any()))
          .thenAnswer((_) async => right(null));

      // Outstanding total = 10,000 + 200 (accrued interest) = 10,200
      final result = await usecase(
        loanId: loan.id,
        amount: 10200,
        mode: 'bank',
        paidAt: paymentDate,
      );

      expect(result.isRight(), true);
      verify(() => repository.recordRepayment(
            loan.id,
            any(
              that: isA<Repayment>()
                  .having((r) => r.amount, 'amount', 10200)
                  .having((r) => r.paidAt, 'paidAt', paymentDate),
            ),
          )).called(1);
    });

    test('rejects repayment amount greater than total outstanding balance (including interest)', () async {
      final loan = directUdharLoanFixture.copyWith(
        principalAmount: 300,
        outstandingBalance: 300,
        interestType: InterestType.interestFree,
      );

      when(() => repository.findById(loan.id))
          .thenAnswer((_) async => right(loan));

      final result = await usecase(
        loanId: loan.id,
        amount: 500,
        mode: 'cash',
      );

      expect(result.isLeft(), true);
      result.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.recordRepayment(any(), any()));
    });

    test('rejects repayment when loan is already closed / zero balance', () async {
      final loan = directUdharLoanFixture.copyWith(
        principalAmount: 1000,
        outstandingBalance: 0,
        status: LoanStatus.closed,
        interestType: InterestType.interestFree,
      );

      when(() => repository.findById(loan.id))
          .thenAnswer((_) async => right(loan));
      // Full repayment history that settled the loan to zero balance
      when(() => repository.getRepayments(loan.id)).thenAnswer(
        (_) async => right([
          Repayment(
            id: 'rep-settle',
            sourceType: RepaymentSourceType.directUdhar,
            sourceId: loan.id,
            amount: 1000,
            paidAt: loan.createdAt,
            createdAt: loan.createdAt,
          ),
        ]),
      );

      final result = await usecase(
        loanId: loan.id,
        amount: 100,
        mode: 'cash',
      );

      expect(result.isLeft(), true);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).message, 'Repayment amount exceeds the outstanding balance.');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.recordRepayment(any(), any()));
      verifyNever(() => repository.updateStatus(any(), any()));
    });

    test('rejects zero repayment amount', () async {
      final loan = directUdharLoanFixture;

      when(() => repository.findById(loan.id))
          .thenAnswer((_) async => right(loan));

      final result = await usecase(
        loanId: loan.id,
        amount: 0,
        mode: 'cash',
      );

      expect(result.isLeft(), true);
      result.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected ValidationFailure'),
      );
    });

    test('rejects negative repayment amount', () async {
      final loan = directUdharLoanFixture;

      when(() => repository.findById(loan.id))
          .thenAnswer((_) async => right(loan));

      final result = await usecase(
        loanId: loan.id,
        amount: -100,
        mode: 'cash',
      );

      expect(result.isLeft(), true);
    });

    test('passes custom paidAt and memo to repayment record', () async {
      final loan = directUdharLoanFixture.copyWith(outstandingBalance: 5000);
      final customDate = DateTime(2026, 3, 15);

      when(() => repository.findById(loan.id))
          .thenAnswer((_) async => right(loan));
      when(() => repository.recordRepayment(any(), any()))
          .thenAnswer((_) async => right(null));

      final result = await usecase(
        loanId: loan.id,
        amount: 2500,
        mode: 'bank',
        paidAt: customDate,
        memo: 'Part payment via RTGS',
      );

      expect(result.isRight(), true);
      verify(() => repository.recordRepayment(
            loan.id,
            any(
              that: isA<Repayment>()
                  .having((r) => r.amount, 'amount', 2500)
                  .having((r) => r.paymentMode, 'mode', 'bank')
                  .having((r) => r.paidAt, 'paidAt', customDate)
                  .having((r) => r.memo, 'memo', 'Part payment via RTGS'),
            ),
          )).called(1);
    });
  });

  group('InterestCalculator Domain Allocations (3+ Sequential Repayments)', () {
    test('allocates interest-first then principal-second across 3 sequential repayments', () {
      final loan = DirectUdharLoan(
        id: 'loan-seq',
        contactId: 'c1',
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.simple,
        interestRatePercent: 3.0, // 3% per month
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // Repayment 1 on Day 30: Accrued interest = 300. Paid = 1000.
      // Allocation: 300 interest, 700 principal -> Remaining principal = 9300.
      final rep1 = Repayment(
        id: 'r1',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: loan.id,
        amount: 1000,
        paidAt: DateTime(2026, 1, 31),
        createdAt: DateTime(2026, 1, 31),
      );
      final alloc1 = InterestCalculator.allocateRepayment(
        loan: loan,
        existingRepayments: [],
        newRepayment: rep1,
      );
      expect(alloc1.interestPaid, 300.0);
      expect(alloc1.principalPaid, 700.0);
      expect(alloc1.newOutstandingPrincipal, 9300.0);
      expect(alloc1.newStatus, LoanStatus.partiallyPaid);

      // Repayment 2 on Day 60 (30 days later): Accrued interest on 9300 = 9300 * 3% = 279. Paid = 5000.
      // Allocation: 279 interest, 4721 principal -> Remaining principal = 4579.
      final rep2 = Repayment(
        id: 'r2',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: loan.id,
        amount: 5000,
        paidAt: DateTime(2026, 3, 2),
        createdAt: DateTime(2026, 3, 2),
      );
      final alloc2 = InterestCalculator.allocateRepayment(
        loan: loan,
        existingRepayments: [rep1],
        newRepayment: rep2,
      );
      expect(alloc2.interestPaid, 279.0);
      expect(alloc2.principalPaid, 4721.0);
      expect(alloc2.newOutstandingPrincipal, 4579.0);
      expect(alloc2.newStatus, LoanStatus.partiallyPaid);

      // Repayment 3 on Day 90 (30 days later): Accrued interest on 4579 = 4579 * 3% = 137.37.
      // Total Outstanding = 4579 + 137.37 = 4716.37. Paid = 4716.37 (Full settlement).
      final rep3 = Repayment(
        id: 'r3',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: loan.id,
        amount: 4716.37,
        paidAt: DateTime(2026, 4, 1),
        createdAt: DateTime(2026, 4, 1),
      );
      final alloc3 = InterestCalculator.allocateRepayment(
        loan: loan,
        existingRepayments: [rep1, rep2],
        newRepayment: rep3,
      );
      expect(alloc3.interestPaid, 137.37);
      expect(alloc3.principalPaid, 4579.0);
      expect(alloc3.newOutstandingPrincipal, 0.0);
      expect(alloc3.newTotalOutstanding, 0.0);
      expect(alloc3.newStatus, LoanStatus.closed);
    });
  });
}
