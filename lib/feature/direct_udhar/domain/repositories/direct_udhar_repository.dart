import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/direct_udhar_loan.dart';

/// Repository contract for direct cash loan operations.
abstract class DirectUdharRepository {
  Future<Either<Failure, List<DirectUdharLoan>>> getByContact(String contactId);
  Future<Either<Failure, DirectUdharLoan?>> findById(String id);
  Future<Either<Failure, DirectUdharLoan>> create(DirectUdharLoan loan);
  Future<Either<Failure, DirectUdharLoan>> update(DirectUdharLoan loan);
  Future<Either<Failure, void>> delete(String id);

  /// Records a repayment and transactionally updates outstanding_balance + status.
  Future<Either<Failure, void>> recordRepayment(
    String loanId,
    Repayment repayment,
  );

  /// Updates the loan status explicitly (e.g. to 'closed' on full repayment).
  Future<Either<Failure, void>> updateStatus(String loanId, LoanStatus status);

  /// Returns all repayments for a loan.
  Future<Either<Failure, List<Repayment>>> getRepayments(String loanId);
}
