import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';

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
