import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_hive_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/repositories/contact_repository_impl.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    await HiveRegistrar.initialize(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Contacts Hive Repository Tests', () {
    test('Create, retrieve, update, and soft delete a contact', () async {
      const dataSource = ContactHiveDataSource();
      const repository = ContactRepositoryImpl(dataSource);

      final newContact = Contact(
        id: '',
        type: ContactType.buyer,
        name: 'Ramesh Kumar',
        mobileNumber: '9876543210',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createRes = await repository.create(newContact);
      expect(createRes.isRight(), isTrue);

      final created = createRes.getOrElse((_) => throw Exception());
      expect(created.id.isNotEmpty, isTrue);
      expect(created.name, 'Ramesh Kumar');

      final listRes = await repository.getAll();
      expect(listRes.isRight(), isTrue);
      final list = listRes.getOrElse((_) => []);
      expect(list.length, 1);
      expect(list.first.name, 'Ramesh Kumar');

      // Update
      final updatedContact = created.copyWith(name: 'Ramesh Shah');
      final updateRes = await repository.update(updatedContact);
      expect(updateRes.isRight(), isTrue);

      final findRes = await repository.findById(created.id);
      expect(findRes.isRight(), isTrue);
      expect(findRes.getOrElse((_) => null)?.name, 'Ramesh Shah');

      // getTotalBalance now returns 0.0 since Direct Udhar is retired
      final balanceRes = await repository.getTotalBalance(created.id);
      expect(balanceRes.isRight(), isTrue);
      expect(balanceRes.getOrElse((_) => -1.0), equals(0.0));

      // Soft delete
      final deleteRes = await repository.delete(created.id);
      expect(deleteRes.isRight(), isTrue);

      final afterDeleteList = (await repository.getAll()).getOrElse((_) => []);
      expect(afterDeleteList.isEmpty, isTrue);
    });
  });
}
