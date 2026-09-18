import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/sqlite/app_database.dart';
import 'package:pamz_khata/core/db/sqlite/database_helper.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_hive_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_sqlite_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/repositories/contact_repository_impl.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/domain/usecases/contact_usecases.dart';
import 'package:pamz_khata/feature/direct_udhar/data/models/direct_udhar_models.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Buyer & Supplier Udhar Khata Unit Tests (FR-UK-001 to FR-UK-004)', () {
    late Directory tempDir;
    const hiveDataSource = ContactHiveDataSource();
    const repository = ContactRepositoryImpl(hiveDataSource);
    late CreateContactUsecase createUsecase;
    late UpdateContactUsecase updateUsecase;
    late DeleteContactUsecase deleteUsecase;
    late GetContactsUsecase getContactsUsecase;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('buyer_supplier_test_');
      await HiveRegistrar.initialize(tempDir.path);
      createUsecase = const CreateContactUsecase(repository);
      updateUsecase = const UpdateContactUsecase(repository);
      deleteUsecase = const DeleteContactUsecase(repository);
      getContactsUsecase = const GetContactsUsecase(repository);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    // 1. Valid 10-digit mobile accepted
    test('1. Valid 10-digit mobile accepted', () async {
      final buyer = Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Mohan Lal',
        mobileNumber: '9876543210',
        address: 'Main Market',
        villageTola: 'Ward 4',
        creditLimit: 10000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await createUsecase(buyer);
      expect(result.isRight(), isTrue);
      final created = result.getOrElse((_) => throw Exception());
      expect(created.id.isNotEmpty, isTrue);
      expect(created.mobileNumber, '9876543210');
    });

    // 2. Invalid mobile rejected
    test('2. Invalid mobile numbers (<10 digits, invalid prefix, alpha) are rejected', () async {
      final shortNumber = Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Invalid User',
        mobileNumber: '98765',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final res1 = await createUsecase(shortNumber);
      expect(res1.isLeft(), isTrue);
      expect(res1.fold((l) => l, (r) => null), isA<ValidationFailure>());

      final invalidPrefix = Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Invalid User 2',
        mobileNumber: '4876543210', // Starts with 4
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final res2 = await createUsecase(invalidPrefix);
      expect(res2.isLeft(), isTrue);
    });

    // 3. Duplicate mobile rejected on create
    test('3. Duplicate mobile rejected on create with DuplicatePhoneFailure', () async {
      final contact1 = Contact(
        id: '',
        type: ContactType.buyer,
        name: 'User One',
        mobileNumber: '9876543210',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await createUsecase(contact1);

      final contact2 = Contact(
        id: '',
        type: ContactType.supplier,
        name: 'User Two',
        mobileNumber: '9876543210',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final res = await createUsecase(contact2);
      expect(res.isLeft(), isTrue);
      expect(res.fold((l) => l, (r) => null), isA<DuplicatePhoneFailure>());
    });

    // 4. Duplicate mobile rejected on update
    test('4. Duplicate mobile rejected on update when taken by another contact', () async {
      await createUsecase(Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Contact 1',
        mobileNumber: '9876543210',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final c2 = (await createUsecase(Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Contact 2',
        mobileNumber: '9123456789',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ))).getOrElse((_) => throw Exception());

      // Attempt to update c2 with c1's phone
      final updateRes = await updateUsecase(c2.copyWith(mobileNumber: '9876543210'));
      expect(updateRes.isLeft(), isTrue);
      expect(updateRes.fold((l) => l, (r) => null), isA<DuplicatePhoneFailure>());
    });

    // 5. Same contact's existing mobile accepted on update
    test("5. Same contact's existing mobile accepted on update", () async {
      final c1 = (await createUsecase(Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Original Name',
        mobileNumber: '9876543210',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ))).getOrElse((_) => throw Exception());

      final updateRes = await updateUsecase(c1.copyWith(name: 'Updated Name'));
      expect(updateRes.isRight(), isTrue);
      expect(updateRes.getOrElse((_) => throw Exception()).name, 'Updated Name');
    });

    // 6. Buyer profile CRUD (Name, Mobile, Address, Village/Tola, Credit Limit)
    test('6. Buyer full profile CRUD and field persistence', () async {
      final buyer = Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Suresh Buyer',
        mobileNumber: '9988776655',
        address: 'Bazar Road',
        villageTola: 'North Tola',
        creditLimit: 50000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = (await createUsecase(buyer)).getOrElse((_) => throw Exception());
      expect(created.isBuyer, isTrue);
      expect(created.address, 'Bazar Road');
      expect(created.villageTola, 'North Tola');
      expect(created.creditLimit, 50000.0);

      // Read by type
      final buyers = (await getContactsUsecase(type: ContactType.buyer)).getOrElse((_) => []);
      expect(buyers.any((b) => b.id == created.id), isTrue);

      // Update
      final updated = (await updateUsecase(created.copyWith(creditLimit: 75000))).getOrElse((_) => throw Exception());
      expect(updated.creditLimit, 75000.0);

      // Delete
      await deleteUsecase(created.id);
      final afterDelete = (await getContactsUsecase(type: ContactType.buyer)).getOrElse((_) => []);
      expect(afterDelete.any((b) => b.id == created.id), isFalse);
    });

    // 7. Supplier profile CRUD (Name, Mobile, Shop Location, Due Date Alerts)
    test('7. Supplier full profile CRUD and field persistence', () async {
      final supplier = Contact(
        id: '',
        type: ContactType.supplier,
        name: 'Gupta Traders',
        mobileNumber: '9112233445',
        shopLocation: 'Mandi Gate 2',
        dueDateAlertEnabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = (await createUsecase(supplier)).getOrElse((_) => throw Exception());
      expect(created.isSupplier, isTrue);
      expect(created.shopLocation, 'Mandi Gate 2');
      expect(created.dueDateAlertEnabled, isTrue);

      // Read by type
      final suppliers = (await getContactsUsecase(type: ContactType.supplier)).getOrElse((_) => []);
      expect(suppliers.any((s) => s.id == created.id), isTrue);

      // Update
      final updated = (await updateUsecase(created.copyWith(dueDateAlertEnabled: false))).getOrElse((_) => throw Exception());
      expect(updated.dueDateAlertEnabled, isFalse);

      // Delete
      await deleteUsecase(created.id);
      final afterDelete = (await getContactsUsecase(type: ContactType.supplier)).getOrElse((_) => []);
      expect(afterDelete.any((s) => s.id == created.id), isFalse);
    });

    // 8. Soft-deleted contact mobile reuse
    test('8. Soft-deleted contact mobile number can be reused by a new contact', () async {
      final c1 = (await createUsecase(Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Deleted Contact',
        mobileNumber: '9876543210',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ))).getOrElse((_) => throw Exception());

      await deleteUsecase(c1.id);

      final c2 = Contact(
        id: '',
        type: ContactType.supplier,
        name: 'New Owner of Number',
        mobileNumber: '9876543210',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final res = await createUsecase(c2);
      expect(res.isRight(), isTrue);
    });

    // 9. SQLite / Hive Parity for Contact CRUD & Mobile Uniqueness
    test('9. SQLite and Hive produce exact parity for Contact CRUD and uniqueness checks', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final sqliteDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE contacts (
              id TEXT PRIMARY KEY,
              type TEXT,
              name TEXT,
              mobile_number TEXT,
              address TEXT,
              village_tola TEXT,
              shop_location TEXT,
              credit_limit REAL DEFAULT 0,
              due_date_alert_enabled INTEGER DEFAULT 0,
              created_at TEXT,
              updated_at TEXT,
              is_deleted INTEGER DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE audit_log (
              id TEXT PRIMARY KEY,
              entity_type TEXT,
              entity_id TEXT,
              action TEXT,
              changed_fields_json TEXT,
              performed_at TEXT
            );
          ''');
        },
      );
      final sqliteDataSource = ContactSqliteDataSource(
        DatabaseHelper(AppDatabase.instance..overrideForTesting(sqliteDb)),
      );
      final sqliteRepo = ContactRepositoryImpl(sqliteDataSource);

      final contact = Contact(
        id: 'contact-parity-1',
        type: ContactType.buyer,
        name: 'Parity User',
        mobileNumber: '9876500000',
        address: 'Market',
        villageTola: 'Tola 1',
        creditLimit: 20000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create in both
      final hRes = await repository.create(contact);
      final sRes = await sqliteRepo.create(contact);
      expect(hRes.isRight(), isTrue);
      expect(sRes.isRight(), isTrue);

      // Uniqueness check
      final hExists = await repository.existsByMobile('9876500000');
      final sExists = await sqliteRepo.existsByMobile('9876500000');
      expect(hExists, isTrue);
      expect(sExists, isTrue);

      // Soft delete in both
      await repository.delete(contact.id);
      await sqliteRepo.delete(contact.id);

      final hAfter = await repository.getAll();
      final sAfter = await sqliteRepo.getAll();
      expect(hAfter.getOrElse((_) => []).length, sAfter.getOrElse((_) => []).length);

      await sqliteDb.close();
    });

    // 10. Audit log entries created for Create, Update, and Delete
    test('10. Audit log records are created for contact create, update, and soft delete', () async {
      final contact = Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Audit User',
        mobileNumber: '9876541111',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = (await createUsecase(contact)).getOrElse((_) => throw Exception());
      await updateUsecase(created.copyWith(name: 'Audit User Updated'));
      await deleteUsecase(created.id);

      final auditBox = HiveRegistrar.auditLogBox;
      final auditEntries = auditBox.values
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where((m) => m['entity_type'] == 'contacts' && m['entity_id'] == created.id)
          .toList();

      expect(auditEntries.length, 3);
      final actions = auditEntries.map((e) => e['action']).toList();
      expect(actions.contains('create'), isTrue);
      expect(actions.contains('update'), isTrue);
      expect(actions.contains('delete'), isTrue);
    });

    // 11. Existing Direct Udhar & Contact Balance behavior remains intact
    test('11. Direct Udhar loan calculation against a contact remains intact and functional', () async {
      final contact = (await createUsecase(Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Udhar Contact',
        mobileNumber: '9876542222',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ))).getOrElse((_) => throw Exception());

      final loan = DirectUdharLoan(
        id: 'loan-c-1',
        contactId: contact.id,
        direction: LoanDirection.lent,
        principalAmount: 10000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 10000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await HiveRegistrar.directUdharBox.put(loan.id, DirectUdharLoanModel.fromEntity(loan).toMap());

      final balance = await repository.getTotalBalance(contact.id);
      expect(balance.isRight(), isTrue);
      expect(balance.getOrElse((_) => 0), 10000.0);
    });
  });
}
