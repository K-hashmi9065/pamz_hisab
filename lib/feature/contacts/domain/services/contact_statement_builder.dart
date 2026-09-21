import '../entities/contact.dart';
import '../entities/contact_ledger_statement.dart';

/// Helper to build an itemized statement from contact ledger data.
///
/// NOTE: The Direct Udhar loan workflow has been retired. The Contacts feature
/// now shows an empty ledger statement; transaction history is tracked via the
/// Fund Ledger feature instead.
class ContactStatementBuilder {
  const ContactStatementBuilder._();

  static ContactLedgerStatement build({
    required Contact contact,
    DateTime? asOfDate,
  }) {
    final statementDate = asOfDate ?? DateTime.now();
    return ContactLedgerStatement(
      contact: contact,
      statementDate: statementDate,
      items: const [],
      totalDebit: 0.0,
      totalCredit: 0.0,
      totalAccruedInterest: 0.0,
      netOutstandingBalance: 0.0,
    );
  }
}
