import '../entities/fl_transaction.dart';
import '../repositories/fl_transaction_repository.dart';

/// Authoritative domain calculator for Fund Ledger financial summaries.
///
/// SINGLE SOURCE OF TRUTH for all financial calculations.
///
/// CRITICAL FORMULA:
///   availableAmount = totalReceived - totalReturned
///
/// Utilization MUST NOT reduce availableAmount.
/// This is enforced structurally — utilization is excluded from the formula.
abstract final class FLSummaryCalculator {
  FLSummaryCalculator._();

  /// Calculates totals from a list of non-deleted transactions.
  ///
  /// Soft-deleted transactions must be excluded before calling this.
  static FLTotals fromTransactions(List<FLTransaction> transactions) {
    double received = 0;
    double utilized = 0;
    double returned = 0;

    for (final txn in transactions) {
      if (txn.isDeleted) continue; // defensive guard
      switch (txn.type) {
        case FLTransactionType.received:
          received += txn.amount;
        case FLTransactionType.utilized:
          utilized += txn.amount;
        case FLTransactionType.returned:
          returned += txn.amount;
      }
    }

    return FLTotals(
      totalReceived: received,
      totalUtilized: utilized,
      totalReturned: returned,
    );
  }

  /// Calculates available amount from numbers directly.
  static double calculateAvailable({
    required double received,
    required double returned,
  }) =>
      received - returned;

  /// Calculates available amount from pre-aggregated totals.
  ///
  ///   available = totalReceived - totalReturned
  ///
  /// Utilization does NOT reduce available.
  static double availableAmount(FLContactTotals totals) =>
      totals.totalReceived - totals.totalReturned;

  /// Builds a [FLContactSummary] from a contact's transaction list.
  static FLTotals totalsFromList(List<FLTransaction> active) {
    return fromTransactions(active);
  }
}

/// Calculated totals — intermediate value object used before building summaries.
class FLTotals {
  const FLTotals({
    required this.totalReceived,
    required this.totalUtilized,
    required this.totalReturned,
  });

  final double totalReceived;
  final double totalUtilized;
  final double totalReturned;

  /// Available = Received - Returned (utilization excluded).
  double get availableAmount => totalReceived - totalReturned;

  FLTotals operator +(FLTotals other) => FLTotals(
        totalReceived: totalReceived + other.totalReceived,
        totalUtilized: totalUtilized + other.totalUtilized,
        totalReturned: totalReturned + other.totalReturned,
      );

  static FLTotals zero() => const FLTotals(
        totalReceived: 0,
        totalUtilized: 0,
        totalReturned: 0,
      );

  @override
  String toString() =>
      'FLTotals(received: $totalReceived, utilized: $totalUtilized, '
      'returned: $totalReturned, available: $availableAmount)';
}
