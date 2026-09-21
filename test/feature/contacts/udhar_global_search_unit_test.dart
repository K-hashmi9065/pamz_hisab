import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/presentation/providers/contact_providers.dart';

import '../../test_helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  final testBuyer1 = Contact(
    id: 'c-1',
    type: ContactType.buyer,
    name: 'Kamran Akmal',
    mobileNumber: '9876543210',
    address: 'Shop 12, Market',
    villageTola: 'North Sector',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testBuyer2 = Contact(
    id: 'c-2',
    type: ContactType.buyer,
    name: 'Ramesh Patel',
    mobileNumber: '9123456780',
    address: 'Station Road',
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
  );

  final testSupplier1 = Contact(
    id: 'c-3',
    type: ContactType.supplier,
    name: 'Suresh Wholesalers',
    mobileNumber: '9876112233',
    shopLocation: 'Block C, Wholesale Bazaar',
    createdAt: DateTime(2026, 1, 3),
    updatedAt: DateTime(2026, 1, 3),
  );

  final testDeletedContact = Contact(
    id: 'c-4',
    type: ContactType.buyer,
    name: 'Kamran Old',
    mobileNumber: '9876999999',
    isDeleted: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final allContacts = [testBuyer1, testBuyer2, testSupplier1, testDeletedContact];

  group('searchUdharContacts Pure Filtering Logic Unit Tests', () {
    test('1. Empty query returns all non-deleted contacts', () {
      final results = searchUdharContacts(allContacts, '');
      expect(results.length, 3);
      expect(results.any((c) => c.id == 'c-4'), isFalse);
    });

    test('2. Search by exact name returns exact matching contact', () {
      final results = searchUdharContacts(allContacts, 'Ramesh Patel');
      expect(results.length, 1);
      expect(results.first.name, 'Ramesh Patel');
      expect(results.first.type, ContactType.buyer);
    });

    test('3. Search by partial name (e.g. "kam") returns matching contact', () {
      final results = searchUdharContacts(allContacts, 'kam');
      expect(results.length, 1);
      expect(results.first.name, 'Kamran Akmal');
    });

    test('4. Case-insensitive search ("kAmRaN", "SURESH") matches correctly', () {
      final res1 = searchUdharContacts(allContacts, 'kAmRaN');
      expect(res1.length, 1);
      expect(res1.first.name, 'Kamran Akmal');

      final res2 = searchUdharContacts(allContacts, 'SURESH');
      expect(res2.length, 1);
      expect(res2.first.name, 'Suresh Wholesalers');
    });

    test('5. Search by mobile number ("9876") matches all matching numbers', () {
      final results = searchUdharContacts(allContacts, '9876');
      expect(results.length, 2);
      expect(results.map((c) => c.name), containsAll(['Kamran Akmal', 'Suresh Wholesalers']));
    });

    test('6. Search by type "buyer" or "grahak" returns all buyers', () {
      final resBuyer = searchUdharContacts(allContacts, 'buyer');
      expect(resBuyer.length, 2);
      expect(resBuyer.every((c) => c.type == ContactType.buyer), isTrue);

      final resGrahak = searchUdharContacts(allContacts, 'grahak');
      expect(resGrahak.length, 2);
    });

    test('7. Search by type "supplier" or "bypari" returns all suppliers', () {
      final resSupplier = searchUdharContacts(allContacts, 'supplier');
      expect(resSupplier.length, 1);
      expect(resSupplier.first.name, 'Suresh Wholesalers');

      final resBypari = searchUdharContacts(allContacts, 'bypari');
      expect(resBypari.length, 1);
      expect(resBypari.first.name, 'Suresh Wholesalers');
    });

    test('8. Search by address/location ("Wholesale Bazaar", "North Sector") matches', () {
      final resLoc = searchUdharContacts(allContacts, 'Wholesale Bazaar');
      expect(resLoc.length, 1);
      expect(resLoc.first.name, 'Suresh Wholesalers');

      final resVill = searchUdharContacts(allContacts, 'North Sector');
      expect(resVill.length, 1);
      expect(resVill.first.name, 'Kamran Akmal');
    });

    test('9. No-match query returns empty result list', () {
      final results = searchUdharContacts(allContacts, 'NonExistentXYZ');
      expect(results, isEmpty);
    });

    test('10. Leading/trailing whitespace is ignored ("  kamran  ")', () {
      final results = searchUdharContacts(allContacts, '  kamran  ');
      expect(results.length, 1);
      expect(results.first.name, 'Kamran Akmal');
    });

    test('11. Soft-deleted contact is never returned in search results', () {
      final results = searchUdharContacts(allContacts, 'Old');
      expect(results, isEmpty);
    });

    test('12. Original contact list remains immutable and unchanged after search', () {
      final originalLength = allContacts.length;
      searchUdharContacts(allContacts, 'kam');
      expect(allContacts.length, originalLength);
    });
  });

  group('udharGlobalSearchProvider Riverpod Integration Tests', () {
    late MockContactRepository mockContactRepo;

    setUp(() {
      mockContactRepo = MockContactRepository();
    });

    test('Provider reacts to query changes and filters allContactListProvider', () async {
      when(() => mockContactRepo.getAll(type: any(named: 'type')))
          .thenAnswer((_) async => right([testBuyer1, testBuyer2, testSupplier1]));

      final container = ProviderContainer(
        overrides: [
          contactRepositoryProvider.overrideWithValue(mockContactRepo),
        ],
      );
      addTearDown(container.dispose);

      // Initial empty search returns all contacts
      final initialAsync = await container.read(allContactListProvider.future);
      expect(initialAsync.length, 3);

      final searchResultsEmpty = container.read(udharGlobalSearchProvider).value!;
      expect(searchResultsEmpty.length, 3);

      // Update query to 'suresh'
      container.read(udharGlobalSearchQueryProvider.notifier).state = 'suresh';

      final searchResultsFiltered = container.read(udharGlobalSearchProvider).value!;
      expect(searchResultsFiltered.length, 1);
      expect(searchResultsFiltered.first.name, 'Suresh Wholesalers');

      // Clear query
      container.read(udharGlobalSearchQueryProvider.notifier).state = '';
      final searchResultsCleared = container.read(udharGlobalSearchProvider).value!;
      expect(searchResultsCleared.length, 3);
    });
  });
}
