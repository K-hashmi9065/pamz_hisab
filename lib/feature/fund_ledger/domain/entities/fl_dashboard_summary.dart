import 'fl_transaction.dart';

/// Global dashboard summary across all Fund Ledger contacts.
///
/// AUTHORITATIVE FORMULAS:
///   totalUtilized = totalContactUtilized + totalFamilyUtilized
///   availableBalance = totalReceived - totalReturned - totalUtilized
class FLDashboardSummary {
  const FLDashboardSummary({
    required this.totalReceived,
    double totalUtilized = 0.0,
    double? totalContactUtilized,
    required this.totalReturned,
    this.totalFamilyUtilized = 0.0,
    required this.recentTransactions,
  }) : totalContactUtilized = totalContactUtilized ?? totalUtilized;

  final double totalReceived;
  final double totalContactUtilized;
  final double totalReturned;
  final double totalFamilyUtilized;

  /// Most recent transactions across all contacts (newest first).
  final List<FLRecentActivity> recentTransactions;

  /// Total Utilized = Contact Utilized + Family Utilized
  double get totalUtilized => totalContactUtilized + totalFamilyUtilized;

  /// Fund Available Before Family Utilize = Total Received - Total Returned - Total Contact Utilized
  double get availableBeforeFamilyUtilize =>
      totalReceived - totalReturned - totalContactUtilized;

  /// Available Balance = Total Received - Total Returned - Total Utilized
  ///                   = Total Received - Total Returned - Total Contact Utilized - Total Family Utilized
  double get availableBalance =>
      totalReceived - totalReturned - totalUtilized;

  /// Alias for availableBalance
  double get availableAmount => availableBalance;

  factory FLDashboardSummary.empty() => const FLDashboardSummary(
        totalReceived: 0,
        totalContactUtilized: 0,
        totalReturned: 0,
        totalFamilyUtilized: 0,
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
