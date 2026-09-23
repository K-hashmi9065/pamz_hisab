/// Aggregated totals model for the Reports screen.
class FLReportsTotals {
  const FLReportsTotals({
    required this.totalReceived,
    required this.totalContactUtilized,
    required this.totalFamilyUtilized,
    required this.totalReturned,
  });

  final double totalReceived;
  final double totalContactUtilized;
  final double totalFamilyUtilized;
  final double totalReturned;

  /// Total Utilized = Family Utilize + Contact Utilize
  double get totalUtilized => totalContactUtilized + totalFamilyUtilized;

  /// Available Balance = Total Received - Total Returned - Total Utilized
  double get netAvailable => totalReceived - totalReturned - totalUtilized;

  factory FLReportsTotals.zero() => const FLReportsTotals(
        totalReceived: 0,
        totalContactUtilized: 0,
        totalFamilyUtilized: 0,
        totalReturned: 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FLReportsTotals &&
          runtimeType == other.runtimeType &&
          totalReceived == other.totalReceived &&
          totalContactUtilized == other.totalContactUtilized &&
          totalFamilyUtilized == other.totalFamilyUtilized &&
          totalReturned == other.totalReturned;

  @override
  int get hashCode => Object.hash(
        totalReceived,
        totalContactUtilized,
        totalFamilyUtilized,
        totalReturned,
      );
}
