/// Privacy-safe DTO used exclusively for PDF generation and sharing.
///
/// STRICT PRIVACY CONTRACT:
/// This DTO structurally cannot contain utilization data.
/// There is no utilization field — it is impossible for utilization
/// to leak into any PDF generated from this class.
///
/// Contains ONLY:
///   - contactName, mobileNumber, aadhaarNumber
///   - receivedEntries (list of received transactions)
///   - returnedEntries (list of returned transactions)
class FLShareStatement {
  const FLShareStatement({
    required this.contactName,
    required this.mobileNumber,
    this.aadhaarNumber,
    required this.receivedEntries,
    required this.returnedEntries,
  });

  final String contactName;
  final String mobileNumber;

  /// Included when available. Never null-filled.
  final String? aadhaarNumber;

  /// Received transactions — ordered oldest to newest for readability.
  final List<FLShareEntry> receivedEntries;

  /// Returned transactions — ordered oldest to newest for readability.
  final List<FLShareEntry> returnedEntries;

  bool get hasReceivedHistory => receivedEntries.isNotEmpty;
  bool get hasReturnedHistory => returnedEntries.isNotEmpty;
  bool get hasAnyHistory => hasReceivedHistory || hasReturnedHistory;

  double get totalReceived =>
      receivedEntries.fold(0, (total, entry) => total + entry.amount);

  double get totalReturned =>
      returnedEntries.fold(0, (total, entry) => total + entry.amount);

  double get availableBalance => totalReceived - totalReturned;

  FLShareEntry? get latestTodayTransaction {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final entries = [...receivedEntries, ...returnedEntries]
        .where((entry) => entry.date.startsWith(today))
        .toList()
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return entries.isEmpty ? null : entries.first;
  }
}

/// A single line item in the shared PDF.
///
/// Represents one received or returned transaction.
/// Never represents a utilized transaction.
class FLShareEntry {
  const FLShareEntry({
    required this.date,
    required this.amount,
    this.type = 'Transaction',
    this.createdAt,
    this.paymentMode,
    this.paymentReference,
  });

  final String date;
  final double amount;
  final String type;
  final String? createdAt;
  final String? paymentMode;

  /// UTR / Cheque Number / Draft Number as applicable.
  final String? paymentReference;
}
