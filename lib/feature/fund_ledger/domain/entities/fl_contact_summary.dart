import 'fl_contact.dart';

/// Per-contact financial summary.
///
/// AUTHORITATIVE FORMULA:
///   availableAmount = totalReceived - totalReturned
///
/// Utilization MUST NOT reduce availableAmount.
class FLContactSummary {
  const FLContactSummary({
    required this.contact,
    required this.totalReceived,
    required this.totalUtilized,
    required this.totalReturned,
  });

  final FLContact contact;
  final double totalReceived;
  final double totalUtilized;
  final double totalReturned;

  /// Available = Received - Returned (utilization does not reduce this).
  double get availableAmount => totalReceived - totalReturned;

  FLContactSummary copyWith({
    FLContact? contact,
    double? totalReceived,
    double? totalUtilized,
    double? totalReturned,
  }) {
    return FLContactSummary(
      contact: contact ?? this.contact,
      totalReceived: totalReceived ?? this.totalReceived,
      totalUtilized: totalUtilized ?? this.totalUtilized,
      totalReturned: totalReturned ?? this.totalReturned,
    );
  }

  /// Zero-value summary for a given contact.
  factory FLContactSummary.empty(FLContact contact) => FLContactSummary(
        contact: contact,
        totalReceived: 0,
        totalUtilized: 0,
        totalReturned: 0,
      );

  @override
  String toString() =>
      'FLContactSummary(received: $totalReceived, utilized: $totalUtilized, '
      'returned: $totalReturned, available: $availableAmount)';
}
