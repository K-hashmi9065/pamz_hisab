import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/feature/family_finance/data/repositories/family_finance_hive_repository_impl.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/domain/usecases/family_finance_usecases.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';
import 'package:pamz_khata/feature/settings/presentation/providers/app_settings_providers.dart';

import '../../test_helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  group('Category Engine UseCase Validation Tests', () {
    late MockFamilyFinanceRepository mockRepo;
    late CreateCategoryUsecase createUsecase;
    late UpdateCategoryUsecase updateUsecase;
    late DeleteCategoryUsecase deleteUsecase;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      createUsecase = CreateCategoryUsecase(mockRepo);
      updateUsecase = UpdateCategoryUsecase(mockRepo);
      deleteUsecase = DeleteCategoryUsecase(mockRepo);
    });

    test('Create category fails if name is empty', () async {
      const invalidCat = TransactionCategory(
        id: '',
        domain: 'income',
        name: '   ',
      );
      final result = await createUsecase(invalidCat);
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f.message, contains('Category name is required')),
        (_) => fail('Should have failed validation'),
      );
      verifyNever(() => mockRepo.createCategory(any()));
    });

    test('Create category fails if domain is invalid', () async {
      const invalidCat = TransactionCategory(
        id: '',
        domain: 'other',
        name: 'Bonus',
      );
      final result = await createUsecase(invalidCat);
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f.message, contains('must be income or expense')),
        (_) => fail('Should have failed validation'),
      );
    });

    test('Create category succeeds with valid parameters', () async {
      const validCat = TransactionCategory(
        id: '',
        domain: 'income',
        name: 'Consultancy',
        iconKey: '💼',
      );
      when(() => mockRepo.createCategory(any()))
          .thenAnswer((_) async => right(validCat.copyWith(id: 'cat_custom_1')));

      final result = await createUsecase(validCat);
      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).id, 'cat_custom_1');
      verify(() => mockRepo.createCategory(validCat)).called(1);
    });

    test('Update category fails if id or name is empty', () async {
      const emptyId = TransactionCategory(
        id: '',
        domain: 'expense',
        name: 'Fuel',
      );
      final res1 = await updateUsecase(emptyId);
      expect(res1.isLeft(), isTrue);

      const emptyName = TransactionCategory(
        id: 'cat-123',
        domain: 'expense',
        name: '',
      );
      final res2 = await updateUsecase(emptyName);
      expect(res2.isLeft(), isTrue);
    });

    test('Delete category fails if id is empty', () async {
      final res = await deleteUsecase('');
      expect(res.isLeft(), isTrue);
    });
  });

  group('Category Engine Hive Persistence, Duplicate Prevention & Parity Tests', () {
    late Directory tempDir;
    late FamilyFinanceHiveRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_cat_test_');
      await HiveRegistrar.initialize(tempDir.path);
      repository = const FamilyFinanceHiveRepositoryImpl();
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Preset categories are preserved and domain-separated', () async {
      final incomeCats = (await repository.getCategories(domain: 'income')).getOrElse((_) => []);
      final expenseCats = (await repository.getCategories(domain: 'expense')).getOrElse((_) => []);

      expect(incomeCats.isNotEmpty, isTrue);
      expect(expenseCats.isNotEmpty, isTrue);

      // Verify preset flags
      expect(incomeCats.any((c) => c.isSystemPreset && c.name == 'Salary'), isTrue);
      expect(expenseCats.any((c) => c.isSystemPreset && c.name == 'Groceries & Ration'), isTrue);
    });

    test('Create custom category and block duplicate names in same domain', () async {
      const customCat = TransactionCategory(
        id: '',
        domain: 'income',
        name: 'Freelancing',
        iconKey: '💻',
      );

      final createRes = await repository.createCategory(customCat);
      expect(createRes.isRight(), isTrue);
      final created = createRes.getOrElse((_) => throw Exception());
      expect(created.id.isNotEmpty, isTrue);
      expect(created.name, 'Freelancing');

      // Attempt duplicate name in same domain (case-insensitive)
      const duplicateCat = TransactionCategory(
        id: '',
        domain: 'income',
        name: 'freelancing',
      );
      final dupRes = await repository.createCategory(duplicateCat);
      expect(dupRes.isLeft(), isTrue);
      dupRes.fold(
        (f) => expect(f.message, contains('already exists')),
        (_) => fail('Duplicate should be blocked'),
      );

      // Duplicate name in DIFFERENT domain is ALLOWED
      const crossDomainCat = TransactionCategory(
        id: '',
        domain: 'expense',
        name: 'Freelancing',
      );
      final crossRes = await repository.createCategory(crossDomainCat);
      expect(crossRes.isRight(), isTrue);
    });

    test('Update category and prevent renaming to existing category name in same domain', () async {
      const catA = TransactionCategory(id: '', domain: 'expense', name: 'Repairs & Maintenance');
      const catB = TransactionCategory(id: '', domain: 'expense', name: 'Office Stationery');

      await repository.createCategory(catA);
      final createdB = (await repository.createCategory(catB)).getOrElse((_) => throw Exception());

      // Attempt to rename B to A
      final conflictUpdate = createdB.copyWith(name: 'Repairs & Maintenance');
      final updateConflictRes = await repository.updateCategory(conflictUpdate);
      expect(updateConflictRes.isLeft(), isTrue);

      // Valid rename
      final validUpdate = createdB.copyWith(name: 'Office Supplies & Stationery');
      final validUpdateRes = await repository.updateCategory(validUpdate);
      expect(validUpdateRes.isRight(), isTrue);
      expect(validUpdateRes.getOrElse((_) => throw Exception()).name, 'Office Supplies & Stationery');
    });

    test('Soft delete category hides category from list and logs audit entry', () async {
      const cat = TransactionCategory(id: '', domain: 'income', name: 'Temporary Rental');
      final created = (await repository.createCategory(cat)).getOrElse((_) => throw Exception());

      final deleteRes = await repository.deleteCategory(created.id);
      expect(deleteRes.isRight(), isTrue);

      // Verify category is excluded from list
      final list = (await repository.getCategories(domain: 'income')).getOrElse((_) => []);
      expect(list.any((c) => c.id == created.id), isFalse);

      // Verify audit log
      final auditLogBox = HiveRegistrar.auditLogBox;
      final auditEntry = auditLogBox.values.firstWhere(
        (e) => e['entity_id'] == created.id && e['action'] == 'delete',
      );
      expect(auditEntry, isNotNull);
      expect(auditEntry['entity_type'], 'categories');
    });
  });

  group('CategoryNotifier & AppSettings State Tests', () {
    test('CategoryNotifier create, update, delete executes and refreshes state', () async {
      final mockRepo = MockFamilyFinanceRepository();
      when(() => mockRepo.createCategory(any()))
          .thenAnswer((inv) async => right(inv.positionalArguments.first as TransactionCategory));
      when(() => mockRepo.updateCategory(any()))
          .thenAnswer((inv) async => right(inv.positionalArguments.first as TransactionCategory));
      when(() => mockRepo.deleteCategory(any()))
          .thenAnswer((_) async => right(null));
      when(() => mockRepo.getCategories(domain: any(named: 'domain')))
          .thenAnswer((_) async => right([]));

      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(categoryNotifierProvider.notifier);

      const testCat = TransactionCategory(id: 'cat_test_1', domain: 'income', name: 'Dividends');
      expect(await notifier.createCategory(testCat), isTrue);
      expect(await notifier.updateCategory(testCat.copyWith(name: 'Stock Dividends')), isTrue);
      expect(await notifier.deleteCategory('cat_test_1'), isTrue);
    });

    test('AppSettingsNotifier updates currency, numbering, fiscal month and GST settings', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);

      await notifier.setCurrencySymbol('\$');
      expect(container.read(appSettingsProvider).currencySymbol, '\$');

      await notifier.setNumberingFormat('Standard (Millions & Billions)');
      expect(container.read(appSettingsProvider).numberingFormat, 'Standard (Millions & Billions)');

      await notifier.setFiscalYearStartMonth(1);
      expect(container.read(appSettingsProvider).fiscalYearStartMonth, 1);
      expect(container.read(appSettingsProvider).fiscalYearLabel, contains('January 1'));

      await notifier.setGstEnabled(true);
      await notifier.setGstRate(12.0);
      expect(container.read(appSettingsProvider).gstEnabled, isTrue);
      expect(container.read(appSettingsProvider).gstRate, 12.0);
    });
  });
}
