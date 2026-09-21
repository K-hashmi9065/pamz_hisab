import 'fl_transaction.dart';

/// Global dashboard summary across all Fund Ledger contacts.
///
/// AUTHORITATIVE FORMULA:
///   availableAmount = totalReceived - totalReturned
class FLDashboardSummary {
  const FLDashboardSummary({
    required this.totalReceived,
    required this.totalUtilized,
    required this.totalReturned,
    required this.recentTransactions,
  });

  final double totalReceived;
  final double totalUtilized;
  final double totalReturned;

  /// Most recent transactions across all contacts (newest first).
  final List<FLRecentActivity> recentTransactions;

  /// Available = Received - Returned (utilization does not reduce this).
  double get availableAmount => totalReceived - totalReturned;

  factory FLDashboardSummary.empty() => const FLDashboardSummary(
        totalReceived: 0,
        totalUtilized: 0,
        totalReturned: 0,
        recentTransactions: [],
      );
}

/// A recent activity entry shown on the Dashboard.
class FLRecentActivity {
  const FLRecentActivity({
    required this.transaction,
    required this.contactName,
  });

  final FLTransaction transaction;
  final String contactName;
}
