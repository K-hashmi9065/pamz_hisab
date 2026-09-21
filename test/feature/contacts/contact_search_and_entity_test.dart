import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';

void main() {
  // ─── Helper ────────────────────────────────────────────────────────────────

  Contact makeContact({
    required String id,
    required String name,
    required String mobile,
    ContactType type = ContactType.buyer,
    String? address,
    String? villageTola,
    String? shopLocation,
    bool isDeleted = false,
  }) {
    return Contact(
      id: id,
      type: type,
      name: name,
      mobileNumber: mobile,
      address: address,
      villageTola: villageTola,
      shopLocation: shopLocation,
      isDeleted: isDeleted,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  final buyer1 = makeContact(
    id: 'b1',
    name: 'Ramesh Kumar',
    mobile: '9876543210',
    type: ContactType.buyer,
    address: 'Main Bazar',
    villageTola: 'Kishanganj Town',
  );

  final buyer2 = makeContact(
    id: 'b2',
    name: 'Amar Singh',
    mobile: '9111111111',
    type: ContactType.buyer,
  );

  final supplier1 = makeContact(
    id: 's1',
    name: 'Suresh Yadav',
    mobile: '9999999999',
    type: ContactType.supplier,
    shopLocation: 'Grain Market',
  );

  final deletedBuyer = makeContact(
    id: 'del1',
    name: 'Old Contact',
    mobile: '9000000000',
    isDeleted: true,
  );

  final allContacts = [buyer1, buyer2, supplier1, deletedBuyer];

  // ─── Contact Entity Tests ──────────────────────────────────────────────────

  group('Contact entity computed properties', () {
    test('isBuyer returns true for buyer, false for supplier', () {
      expect(buyer1.isBuyer, isTrue);
      expect(buyer1.isSupplier, isFalse);
      expect(supplier1.isBuyer, isFalse);
      expect(supplier1.isSupplier, isTrue);
    });

    test('copyWith correctly overrides selected fields', () {
      final updated = buyer1.copyWith(
        name: 'New Name',
        creditLimit: 50000,
        dueDateAlertEnabled: true,
        address: 'New Address',
        villageTola: 'New Village',
        shopLocation: 'New Shop',
        isDeleted: true,
        type: ContactType.supplier,
        mobileNumber: '9000000001',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(updated.name, 'New Name');
      expect(updated.creditLimit, 50000);
      expect(updated.dueDateAlertEnabled, isTrue);
      expect(updated.address, 'New Address');
      expect(updated.villageTola, 'New Village');
      expect(updated.shopLocation, 'New Shop');
      expect(updated.isDeleted, isTrue);
      expect(updated.type, ContactType.supplier);
      expect(updated.mobileNumber, '9000000001');
      expect(updated.isBuyer, isFalse);
      expect(updated.isSupplier, isTrue);
    });

    test('copyWith preserves unspecified fields', () {
      final same = buyer1.copyWith();
      expect(same.id, buyer1.id);
      expect(same.name, buyer1.name);
      expect(same.mobileNumber, buyer1.mobileNumber);
      expect(same.type, buyer1.type);
      expect(same.address, buyer1.address);
      expect(same.villageTola, buyer1.villageTola);
      expect(same.creditLimit, buyer1.creditLimit);
      expect(same.isDeleted, buyer1.isDeleted);
    });
  });

  // ─── searchUdharContacts Tests ─────────────────────────────────────────────

  group('searchUdharContacts — empty / whitespace query', () {
    test('empty query returns all non-deleted contacts', () {
      final result = searchUdharContacts(allContacts, '');
      expect(result.length, 3);
      expect(result.any((c) => c.id == 'del1'), isFalse);
    });

    test('whitespace-only query returns all non-deleted contacts', () {
      final result = searchUdharContacts(allContacts, '   ');
      expect(result.length, 3);
    });
  });

  group('searchUdharContacts — name matching', () {
    test('matches by exact name substring (case-insensitive)', () {
      final result = searchUdharContacts(allContacts, 'ramesh');
      expect(result.length, 1);
      expect(result.first.id, 'b1');
    });

    test('matches partial name with uppercase input', () {
      final result = searchUdharContacts(allContacts, 'AMAR');
      expect(result.length, 1);
      expect(result.first.id, 'b2');
    });

    test('returns multiple contacts matching common substring', () {
      final result = searchUdharContacts(allContacts, 'a');
      // Ramesh Kumar has 'a', Amar Singh has 'a', Suresh Yadav has 'a'
      expect(result.length, greaterThanOrEqualTo(2));
    });
  });

  group('searchUdharContacts — mobile number matching', () {
    test('matches by full mobile number', () {
      final result = searchUdharContacts(allContacts, '9876543210');
      expect(result.length, 1);
      expect(result.first.id, 'b1');
    });

    test('matches by mobile prefix', () {
      final result = searchUdharContacts(allContacts, '9111');
      expect(result.length, 1);
      expect(result.first.id, 'b2');
    });
  });

  group('searchUdharContacts — type keyword matching', () {
    test('buyer keyword matches only buyers', () {
      final result = searchUdharContacts(allContacts, 'buyer');
      expect(result.every((c) => c.isBuyer), isTrue);
      expect(result.length, 2); // buyer1 and buyer2
    });

    test('grahak keyword matches only buyers', () {
      final result = searchUdharContacts(allContacts, 'grahak');
      expect(result.every((c) => c.isBuyer), isTrue);
      expect(result.length, 2);
    });

    test('customer keyword matches only buyers', () {
      final result = searchUdharContacts(allContacts, 'customer');
      expect(result.every((c) => c.isBuyer), isTrue);
    });

    test('supplier keyword matches only suppliers', () {
      final result = searchUdharContacts(allContacts, 'supplier');
      expect(result.every((c) => c.isSupplier), isTrue);
      expect(result.length, 1);
    });

    test('bypari keyword matches only suppliers', () {
      final result = searchUdharContacts(allContacts, 'bypari');
      expect(result.every((c) => c.isSupplier), isTrue);
      expect(result.length, 1);
    });

    test('vendor keyword matches only suppliers', () {
      final result = searchUdharContacts(allContacts, 'vendor');
      expect(result.every((c) => c.isSupplier), isTrue);
      expect(result.length, 1);
    });
  });

  group('searchUdharContacts — address / location matching', () {
    test('matches by address field', () {
      final result = searchUdharContacts(allContacts, 'bazar');
      expect(result.length, 1);
      expect(result.first.id, 'b1');
    });

    test('matches by villageTola field', () {
      final result = searchUdharContacts(allContacts, 'kishanganj');
      expect(result.length, 1);
      expect(result.first.id, 'b1');
    });

    test('matches by shopLocation field', () {
      final result = searchUdharContacts(allContacts, 'grain');
      expect(result.length, 1);
      expect(result.first.id, 's1');
    });
  });

  group('searchUdharContacts — deleted contacts excluded', () {
    test('deleted contact is never returned even if name matches', () {
      final result = searchUdharContacts(allContacts, 'old');
      expect(result.any((c) => c.id == 'del1'), isFalse);
    });

    test('deleted contact excluded from empty query', () {
      final result = searchUdharContacts(allContacts, '');
      expect(result.any((c) => c.isDeleted), isFalse);
    });
  });

  group('searchUdharContacts — no-match returns empty list', () {
    test('returns empty list for query with no match', () {
      final result = searchUdharContacts(allContacts, 'zzzzzzz');
      expect(result, isEmpty);
    });

    test('returns empty list for all contacts list with empty input list', () {
      final result = searchUdharContacts([], 'ramesh');
      expect(result, isEmpty);
    });
  });
}
