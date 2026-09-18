import 'contact.dart';

/// Represents a single itemized entry in a party's ledger statement.
class LedgerStatementItem {
  const LedgerStatementItem({
    required this.id,
    required this.date,
    required this.description,
    required this.type,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    this.interestDetails,
  });

  final String id;
  final DateTime date;
  final String description;
  final String type; // 'loan_lent', 'loan_borrowed', 'repayment', 'opening_balance'
  final double debit; // Amount Given / Lent / Debited
  final double credit; // Amount Received / Repaid / Credited
  final double runningBalance;
  final String? interestDetails;
}

/// Represents a full itemized ledger statement for a contact.
class ContactLedgerStatement {
  const ContactLedgerStatement({
    required this.contact,
    required this.statementDate,
    required this.items,
    required this.totalDebit,
    required this.totalCredit,
    required this.totalAccruedInterest,
    required this.netOutstandingBalance,
  });

  final Contact contact;
  final DateTime statementDate;
  final List<LedgerStatementItem> items;
  final double totalDebit;
  final double totalCredit;
  final double totalAccruedInterest;
  final double netOutstandingBalance;

  bool get isReceivable => netOutstandingBalance >= 0;
}
