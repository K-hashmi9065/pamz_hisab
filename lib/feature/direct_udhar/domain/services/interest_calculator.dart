import '../entities/direct_udhar_loan.dart';

/// Financial summary of a Direct Udhar loan reflecting principal, interest, and repayments.
class LoanFinancialSummary {
  const LoanFinancialSummary({
    required this.principalAmount,
    required this.outstandingPrincipal,
    required this.accruedInterest,
    required this.totalInterestPaid,
    required this.totalPrincipalPaid,
    required this.totalOutstanding,
    required this.status,
  });

  /// Original principal amount disbursed/borrowed.
  final double principalAmount;

  /// Current remaining principal after principal repayments.
  final double outstandingPrincipal;

  /// Current unpaid accrued interest up to the evaluation date.
  final double accruedInterest;

  /// Total interest paid across all repayments so far.
  final double totalInterestPaid;

  /// Total principal paid across all repayments so far.
  final double totalPrincipalPaid;

  /// Total outstanding balance = Outstanding Principal + Unpaid Accrued Interest.
  final double totalOutstanding;

  /// Computed loan status (open, partiallyPaid, closed).
  final LoanStatus status;
}

/// Result of processing a single repayment against a loan.
class RepaymentAllocationResult {
  const RepaymentAllocationResult({
    required this.interestPaid,
    required this.principalPaid,
    required this.newOutstandingPrincipal,
    required this.remainingAccruedInterest,
    required this.newTotalOutstanding,
    required this.newStatus,
  });

  /// Amount of this repayment applied to accrued interest.
  final double interestPaid;

  /// Amount of this repayment applied to principal.
  final double principalPaid;

  /// Updated remaining principal after this repayment.
  final double newOutstandingPrincipal;

  /// Remaining unpaid accrued interest immediately after this repayment.
  final double remainingAccruedInterest;

  /// New total outstanding = newOutstandingPrincipal + remainingAccruedInterest.
  final double newTotalOutstanding;

  /// New loan status after this repayment.
  final LoanStatus newStatus;
}

/// Pure domain calculation service for Direct Udhar Simple Interest & Repayment Allocation.
///
/// Formula:
/// Interest = Principal * MonthlyRate * (ElapsedDays / 30) / 100
///
/// Rules:
/// 1. Simple interest calculates on the active remaining principal (reducing balance).
/// 2. Repayments allocate to Accrued Interest first, then Principal second.
/// 3. Interest-free loans always have 0 accrued interest.
/// 4. All currency calculations are rounded to 2 decimal places.
abstract final class InterestCalculator {
  InterestCalculator._();

  /// Rounds monetary values to 2 decimal places to prevent floating-point accumulation errors.
  static double round(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  /// Calculates simple interest accrued over [days] for a given [principal] and [monthlyRatePercent].
  static double calculateInterestForPeriod({
    required double principal,
    required double monthlyRatePercent,
    required int days,
  }) {
    if (principal <= 0 || monthlyRatePercent <= 0 || days <= 0) {
      return 0.0;
    }
    final rawInterest = (principal * monthlyRatePercent * (days / 30.0)) / 100.0;
    return round(rawInterest);
  }

  /// Computes the complete financial summary of a loan as of [asOfDate] (defaults to now).
  static LoanFinancialSummary calculateSummary({
    required DirectUdharLoan loan,
    required List<Repayment> repayments,
    DateTime? asOfDate,
  }) {
    final evalDate = asOfDate ?? DateTime.now();
    final isSimpleInterest = loan.interestType == InterestType.simple &&
        loan.interestRatePercent != null &&
        loan.interestRatePercent! > 0;
    final monthlyRate = isSimpleInterest ? loan.interestRatePercent! : 0.0;

    // Filter active repayments up to asOfDate and sort chronologically by paidAt
    final sortedRepayments = repayments
        .where(
          (r) =>
              !r.isDeleted &&
              (asOfDate == null || !r.paidAt.isAfter(asOfDate)),
        )
        .toList()
      ..sort((a, b) => a.paidAt.compareTo(b.paidAt));

    double currentPrincipal = loan.principalAmount;
    double accumulatedInterest = 0.0;
    double totalInterestPaid = 0.0;
    double totalPrincipalPaid = 0.0;
    DateTime lastDate = loan.createdAt;

    for (final repayment in sortedRepayments) {
      final days = repayment.paidAt.isAfter(lastDate)
          ? repayment.paidAt.difference(lastDate).inDays
          : 0;

      if (days > 0 && currentPrincipal > 0 && isSimpleInterest) {
        final interest = calculateInterestForPeriod(
          principal: currentPrincipal,
          monthlyRatePercent: monthlyRate,
          days: days,
        );
        accumulatedInterest = round(accumulatedInterest + interest);
      }

      // Allocate repayment: Interest first, Principal second
      final interestPayment = repayment.amount < accumulatedInterest
          ? repayment.amount
          : accumulatedInterest;
      accumulatedInterest = round(accumulatedInterest - interestPayment);
      totalInterestPaid = round(totalInterestPaid + interestPayment);

      final remainingRepayment = round(repayment.amount - interestPayment);
      final principalPayment = remainingRepayment < currentPrincipal
          ? remainingRepayment
          : currentPrincipal;
      currentPrincipal = round(currentPrincipal - principalPayment);
      totalPrincipalPaid = round(totalPrincipalPaid + principalPayment);

      lastDate = repayment.paidAt;
    }

    // Accrue interest from last repayment date up to evaluation date
    final remainingDays = evalDate.isAfter(lastDate)
        ? evalDate.difference(lastDate).inDays
        : 0;

    if (remainingDays > 0 && currentPrincipal > 0 && isSimpleInterest) {
      final additionalInterest = calculateInterestForPeriod(
        principal: currentPrincipal,
        monthlyRatePercent: monthlyRate,
        days: remainingDays,
      );
      accumulatedInterest = round(accumulatedInterest + additionalInterest);
    }

    final totalOutstanding = round(currentPrincipal + accumulatedInterest);

    final LoanStatus computedStatus;
    if (totalOutstanding <= 0) {
      computedStatus = LoanStatus.closed;
    } else if (totalPrincipalPaid > 0 || totalInterestPaid > 0 || currentPrincipal < loan.principalAmount) {
      computedStatus = LoanStatus.partiallyPaid;
    } else {
      computedStatus = LoanStatus.open;
    }

    return LoanFinancialSummary(
      principalAmount: loan.principalAmount,
      outstandingPrincipal: currentPrincipal,
      accruedInterest: accumulatedInterest,
      totalInterestPaid: totalInterestPaid,
      totalPrincipalPaid: totalPrincipalPaid,
      totalOutstanding: totalOutstanding,
      status: computedStatus,
    );
  }

  /// Calculates the allocation of a new repayment (Interest First -> Principal Second)
  /// based on the loan state and all repayments logged prior to [newRepayment].
  static RepaymentAllocationResult allocateRepayment({
    required DirectUdharLoan loan,
    required List<Repayment> existingRepayments,
    required Repayment newRepayment,
  }) {
    // 1. Calculate state right before this new repayment
    final preSummary = calculateSummary(
      loan: loan,
      repayments: existingRepayments,
      asOfDate: newRepayment.paidAt,
    );

    final currentPrincipal = preSummary.outstandingPrincipal;
    final accruedInterest = preSummary.accruedInterest;

    // 2. Allocate: Interest first
    final interestPaid = newRepayment.amount < accruedInterest
        ? newRepayment.amount
        : accruedInterest;
    final remainingAccruedInterest = round(accruedInterest - interestPaid);

    // 3. Allocate: Principal second
    final remainingRepayment = round(newRepayment.amount - interestPaid);
    final principalPaid = remainingRepayment < currentPrincipal
        ? remainingRepayment
        : currentPrincipal;
    final newOutstandingPrincipal = round(currentPrincipal - principalPaid);

    final newTotalOutstanding = round(newOutstandingPrincipal + remainingAccruedInterest);

    final LoanStatus newStatus;
    if (newTotalOutstanding <= 0) {
      newStatus = LoanStatus.closed;
    } else if (newOutstandingPrincipal < loan.principalAmount ||
        (preSummary.totalPrincipalPaid + principalPaid) > 0 ||
        (preSummary.totalInterestPaid + interestPaid) > 0) {
      newStatus = LoanStatus.partiallyPaid;
    } else {
      newStatus = LoanStatus.open;
    }

    return RepaymentAllocationResult(
      interestPaid: round(interestPaid),
      principalPaid: round(principalPaid),
      newOutstandingPrincipal: newOutstandingPrincipal,
      remainingAccruedInterest: remainingAccruedInterest,
      newTotalOutstanding: newTotalOutstanding,
      newStatus: newStatus,
    );
  }
}
