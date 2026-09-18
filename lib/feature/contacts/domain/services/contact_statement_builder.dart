import '../entities/contact.dart';
import '../../../direct_udhar/domain/entities/direct_udhar_loan.dart';
import '../../../direct_udhar/domain/services/interest_calculator.dart';
import '../entities/contact_ledger_statement.dart';

/// Helper to build an itemized statement from loans and repayments.
class ContactStatementBuilder {
  const ContactStatementBuilder._();

  static ContactLedgerStatement build({
    required Contact contact,
    required List<DirectUdharLoan> loans,
    Map<String, List<Repayment>> loanRepayments = const {},
    DateTime? asOfDate,
  }) {
    final statementDate = asOfDate ?? DateTime.now();
    final activeLoans = loans.where((l) => !l.isDeleted).toList();

    // Flatten all events into chronological list
    final events = <_StatementEvent>[];

    for (final loan in activeLoans) {
      events.add(_StatementEvent(
        id: loan.id,
        date: loan.createdAt,
        isLoan: true,
        loan: loan,
      ));

      final repayments = loanRepayments[loan.id] ?? [];
      for (final rep in repayments) {
        if (!rep.isDeleted) {
          events.add(_StatementEvent(
            id: rep.id,
            date: rep.paidAt,
            isLoan: false,
            loan: loan,
            repayment: rep,
          ));
        }
      }
    }

    // Sort events by date ascending
    events.sort((a, b) => a.date.compareTo(b.date));

    final items = <LedgerStatementItem>[];
    double running = 0.0;
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    for (final ev in events) {
      if (ev.isLoan) {
        final loan = ev.loan;
        final isOpening = loan.memo != null && loan.memo!.contains('[Opening Balance]');
        final isLent = loan.direction == LoanDirection.lent;
        final debit = isLent ? loan.principalAmount : 0.0;
        final credit = isLent ? 0.0 : loan.principalAmount;

        if (isLent) {
          running += debit;
        } else {
          running -= credit;
        }

        totalDebit += debit;
        totalCredit += credit;

        final interestStr = loan.interestType == InterestType.simple
            ? '${loan.interestRatePercent}%/mo interest'
            : 'Interest-free';

        items.add(LedgerStatementItem(
          id: loan.id,
          date: loan.createdAt,
          description: isOpening
              ? 'Opening Balance (${isLent ? "Lent" : "Borrowed"})'
              : 'Direct Udhar (${isLent ? "Lent" : "Borrowed"})',
          type: isOpening ? 'opening_balance' : (isLent ? 'loan_lent' : 'loan_borrowed'),
          debit: debit,
          credit: credit,
          runningBalance: running,
          interestDetails: interestStr,
        ));
      } else {
        final loan = ev.loan;
        final rep = ev.repayment!;
        final isLent = loan.direction == LoanDirection.lent;

        // For Lent loan, repayment is Received (Credit)
        // For Borrowed loan, repayment is Paid (Debit)
        final debit = isLent ? 0.0 : rep.amount;
        final credit = isLent ? rep.amount : 0.0;

        if (isLent) {
          running -= credit;
        } else {
          running += debit;
        }

        totalDebit += debit;
        totalCredit += credit;

        items.add(LedgerStatementItem(
          id: rep.id,
          date: rep.paidAt,
          description: isLent
              ? 'Repayment Received (${rep.paymentMode?.toUpperCase() ?? "CASH"})'
              : 'Repayment Paid (${rep.paymentMode?.toUpperCase() ?? "CASH"})',
          type: 'repayment',
          debit: debit,
          credit: credit,
          runningBalance: running,
          interestDetails: rep.memo,
        ));
      }
    }

    // Calculate accrued interest & net total outstanding
    double totalAccruedInterest = 0.0;
    double netOutstanding = 0.0;

    for (final loan in activeLoans) {
      if (loan.status != LoanStatus.closed) {
        final repayments = loanRepayments[loan.id] ?? [];
        final summary = InterestCalculator.calculateSummary(
          loan: loan,
          repayments: repayments.where((r) => !r.isDeleted).toList(),
          asOfDate: statementDate,
        );

        totalAccruedInterest += summary.accruedInterest;

        if (loan.direction == LoanDirection.lent) {
          netOutstanding += summary.totalOutstanding;
        } else {
          netOutstanding -= summary.totalOutstanding;
        }
      }
    }

    return ContactLedgerStatement(
      contact: contact,
      statementDate: statementDate,
      items: items,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      totalAccruedInterest: totalAccruedInterest,
      netOutstandingBalance: netOutstanding,
    );
  }
}

class _StatementEvent {
  const _StatementEvent({
    required this.id,
    required this.date,
    required this.isLoan,
    required this.loan,
    this.repayment,
  });

  final String id;
  final DateTime date;
  final bool isLoan;
  final DirectUdharLoan loan;
  final Repayment? repayment;
}
