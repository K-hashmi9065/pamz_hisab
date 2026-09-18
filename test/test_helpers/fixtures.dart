import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';

// ─── Contact Fixtures ─────────────────────────────────────────────────────

final buyerFixture = Contact(
  id: 'contact-001',
  type: ContactType.buyer,
  name: 'Ramesh Kumar',
  mobileNumber: '9876543210',
  address: 'Main Bazar, Kishanganj',
  villageTola: 'Kishanganj Town',
  creditLimit: 5000,
  dueDateAlertEnabled: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final supplierFixture = Contact(
  id: 'contact-002',
  type: ContactType.supplier,
  name: 'Suresh Yadav',
  mobileNumber: '9123456789',
  shopLocation: 'Grain Market, Kishanganj',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

// ─── Direct Udhar Loan Fixtures ───────────────────────────────────────────

final directUdharLoanFixture = DirectUdharLoan(
  id: 'loan-001',
  contactId: 'contact-001',
  direction: LoanDirection.lent,
  principalAmount: 10000,
  interestType: InterestType.interestFree,
  status: LoanStatus.open,
  outstandingBalance: 10000,
  createdAt: DateTime(2026, 1, 15),
  updatedAt: DateTime(2026, 1, 15),
);

final borrowedLoanFixture = DirectUdharLoan(
  id: 'loan-002',
  contactId: 'contact-002',
  direction: LoanDirection.borrowed,
  principalAmount: 5000,
  interestType: InterestType.simple,
  interestRatePercent: 12.0,
  dueDate: DateTime(2026, 6, 1),
  status: LoanStatus.open,
  outstandingBalance: 5000,
  createdAt: DateTime(2026, 2, 1),
  updatedAt: DateTime(2026, 2, 1),
);

final partiallyPaidLoanFixture = DirectUdharLoan(
  id: 'loan-003',
  contactId: 'contact-001',
  direction: LoanDirection.lent,
  principalAmount: 8000,
  interestType: InterestType.interestFree,
  status: LoanStatus.partiallyPaid,
  outstandingBalance: 3000,
  createdAt: DateTime(2026, 3, 1),
  updatedAt: DateTime(2026, 3, 10),
);
