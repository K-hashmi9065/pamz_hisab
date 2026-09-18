import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/direct_udhar_loan.dart';
import '../repositories/direct_udhar_repository.dart';
import '../services/interest_calculator.dart';

/// Creates a new direct cash loan (FR-DU-001 / FR-DU-002).
class CreateDirectLoanUsecase {
  const CreateDirectLoanUsecase(this._repository);
  final DirectUdharRepository _repository;

  Future<Either<Failure, DirectUdharLoan>> call(DirectUdharLoan loan) async {
    // Validate amount
    if (loan.principalAmount <= 0) {
      return left(const ValidationFailure(
        message: 'Amount must be greater than zero.',
        field: 'principalAmount',
      ));
    }

    // If simple interest, rate must be set
    if (loan.interestType == InterestType.simple &&
        (loan.interestRatePercent == null || loan.interestRatePercent! <= 0)) {
      return left(const ValidationFailure(
        message: 'Interest rate is required for simple interest loans.',
        field: 'interestRatePercent',
      ));
    }

    return _repository.create(loan.copyWith(
      outstandingBalance: loan.principalAmount,
      status: LoanStatus.open,
    ));
  }
}

/// Records a repayment (Jama) against a direct loan (FR-DU-003).
/// Validates repayment amount, updates outstanding balance, transitions status.
class LogRepaymentUsecase {
  const LogRepaymentUsecase(this._repository);
  final DirectUdharRepository _repository;

  Future<Either<Failure, void>> call({
    required String loanId,
    required double amount,
    required String mode,
    DateTime? paidAt,
    String? memo,
  }) async {
    // Fetch current loan state
    final loanResult = await _repository.findById(loanId);
    final loan = loanResult.fold((_) => null, (l) => l);

    if (loan == null) {
      return left(const DatabaseFailure(
        message: 'Loan record not found.',
      ));
    }

    // Validate amount
    if (amount <= 0) {
      return left(const ValidationFailure(
        message: 'Repayment amount must be greater than zero.',
        field: 'amount',
      ));
    }

    // Fetch existing repayments and calculate total outstanding balance (principal + accrued interest)
    final existingRepaymentsRes = await _repository.getRepayments(loanId);
    final existingRepayments = existingRepaymentsRes.getOrElse((_) => []);
    final now = DateTime.now();
    final paymentDate = paidAt ?? now;

    final summary = InterestCalculator.calculateSummary(
      loan: loan,
      repayments: existingRepayments,
      asOfDate: paymentDate,
    );

    if (amount > summary.totalOutstanding) {
      return left(const ValidationFailure(
        message: 'Repayment amount exceeds the outstanding balance.',
        field: 'amount',
      ));
    }

    // Build repayment entity
    final repayment = Repayment(
      id: '',
      sourceType: RepaymentSourceType.directUdhar,
      sourceId: loanId,
      amount: amount,
      paymentMode: mode,
      paidAt: paymentDate,
      memo: memo,
      createdAt: now,
    );

    // Persist + update balance + status transactionally
    return _repository.recordRepayment(loanId, repayment);
  }
}
