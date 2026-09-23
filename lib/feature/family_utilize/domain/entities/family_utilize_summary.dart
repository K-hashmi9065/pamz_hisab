/// Financial summary for Family Utilization and global fund balance.
///
/// AUTHORITATIVE FORMULAS:
///   totalUtilized = totalContactUtilized + totalFamilyUtilized
///   availableBeforeFamilyUtilize = totalReceived - totalReturned - totalContactUtilized
///   remainingAvailable = totalReceived - totalReturned - totalUtilized
class FamilyUtilizeSummary {
  const FamilyUtilizeSummary({
    required this.totalReceived,
    required this.totalReturned,
    this.totalContactUtilized = 0.0,
    required this.totalFamilyUtilized,
  });

  final double totalReceived;
  final double totalReturned;
  final double totalContactUtilized;
  final double totalFamilyUtilized;

  /// Total Utilized = Contact Utilized + Family Utilized
  double get totalUtilized => totalContactUtilized + totalFamilyUtilized;

  /// Fund Available Before Family Utilize = Total Received - Total Returned - Total Contact Utilized
  double get availableBeforeFamilyUtilize =>
      totalReceived - totalReturned - totalContactUtilized;

  /// Family Remaining Available = Total Received - Total Returned - Total Utilized
  ///                            = Total Received - Total Returned - Total Contact Utilized - Total Family Utilized
  double get remainingAvailable =>
      totalReceived - totalReturned - totalUtilized;

  factory FamilyUtilizeSummary.zero() => const FamilyUtilizeSummary(
        totalReceived: 0,
        totalReturned: 0,
        totalContactUtilized: 0,
        totalFamilyUtilized: 0,
      );
}
