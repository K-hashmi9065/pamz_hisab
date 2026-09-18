import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/feature/family_finance/data/repositories/family_finance_hive_repository_impl.dart';
import 'package:pamz_khata/feature/family_finance/data/services/receipt_storage_service.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/domain/usecases/family_finance_usecases.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';

import '../../test_helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  group('Family Finance UseCase Validation Tests (FR-FE-001, FR-FE-002)', () {
    late MockFamilyFinanceRepository mockRepo;
    late AddFamilyTransactionUsecase addUsecase;
    late UpdateFamilyTransactionUsecase updateUsecase;
    late DeleteFamilyTransactionUsecase deleteUsecase;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      addUsecase = AddFamilyTransactionUsecase(mockRepo);
      updateUsecase = UpdateFamilyTransactionUsecase(mockRepo);
      deleteUsecase = DeleteFamilyTransactionUsecase(mockRepo);
    });

    test('Add transaction fails if amount is <= 0', () async {
      final invalidTxn = FamilyTransaction(
        id: '',
        type: 'income',
        amount: 0,
        categoryId: 'cat_sal',
        transactionDate: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );

      final result = await addUsecase(invalidTxn);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('greater than zero')),
        (_) => fail('Should have failed validation'),
      );
      verifyNever(() => mockRepo.addTransaction(any()));
    });

    test('Add transaction fails if categoryId is empty', () async {
      final invalidTxn = FamilyTransaction(
        id: '',
        type: 'expense',
        amount: 500,
        categoryId: '',
        transactionDate: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );

      final result = await addUsecase(invalidTxn);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('Category is required')),
        (_) => fail('Should have failed validation'),
      );
      verifyNever(() => mockRepo.addTransaction(any()));
    });

    test('Add transaction succeeds with valid data', () async {
      final validTxn = FamilyTransaction(
        id: '',
        type: 'income',
        amount: 40000,
        categoryId: 'cat_sal',
        transactionDate: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );

      when(() => mockRepo.addTransaction(any()))
          .thenAnswer((_) async => right(validTxn.copyWith(id: 'txn-101')));

      final result = await addUsecase(validTxn);
      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).id, 'txn-101');
      verify(() => mockRepo.addTransaction(validTxn)).called(1);
    });

    test('Update transaction fails if amount is invalid or category empty', () async {
      final invalidAmount = FamilyTransaction(
        id: 'txn-1',
        type: 'expense',
        amount: -50,
        categoryId: 'cat_groc',
        transactionDate: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );
      final res1 = await updateUsecase(invalidAmount);
      expect(res1.isLeft(), isTrue);

      final invalidCategory = FamilyTransaction(
        id: 'txn-1',
        type: 'expense',
        amount: 500,
        categoryId: '',
        transactionDate: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );
      final res2 = await updateUsecase(invalidCategory);
      expect(res2.isLeft(), isTrue);
    });

    test('Delete transaction delegates to repository (soft delete FR-FE-003)', () async {
      when(() => mockRepo.deleteTransaction(any()))
          .thenAnswer((_) async => right(null));

      final result = await deleteUsecase('txn-123');
      expect(result.isRight(), isTrue);
      verify(() => mockRepo.deleteTransaction('txn-123')).called(1);
    });
  });

  group('Family Finance Hive Persistence & Parity Tests (FR-FE-001 -> FR-FE-003)', () {
    late Directory tempDir;
    late FamilyFinanceHiveRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_ff_test_');
      await HiveRegistrar.initialize(tempDir.path);
      repository = const FamilyFinanceHiveRepositoryImpl();
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Full CRUD Flow: Create, Read, Update, and Soft Delete transaction with audit log', () async {
      // 1. Create Income
      final incomeTxn = FamilyTransaction(
        id: '',
        type: 'income',
        amount: 50000,
        categoryId: 'cat_sal',
        accountId: 'acc_bank',
        transactionDate: DateTime(2026, 3, 1),
        notes: 'March Salary',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final createRes = await repository.addTransaction(incomeTxn);
      expect(createRes.isRight(), isTrue);
      final createdIncome = createRes.getOrElse((_) => throw Exception());
      expect(createdIncome.id.isNotEmpty, isTrue);
      expect(createdIncome.amount, 50000);
      expect(createdIncome.categoryName, isNotNull);

      // Verify Audit Log for create
      final auditLogBox = HiveRegistrar.auditLogBox;
      final createAudit = auditLogBox.values.firstWhere(
        (entry) =>
            entry['entity_id'] == createdIncome.id &&
            entry['action'] == 'create',
      );
      expect(createAudit, isNotNull);
      expect(createAudit['entity_type'], 'family_transactions');

      // 2. Read
      final listRes = await repository.getTransactions(type: 'income');
      expect(listRes.isRight(), isTrue);
      final list = listRes.getOrElse((_) => []);
      expect(list.length, 1);
      expect(list.first.id, createdIncome.id);
      expect(list.first.amount, 50000);

      // 3. Update (FR-FE-001/002 edit support)
      final updatedTxn = createdIncome.copyWith(
        amount: 55000,
        notes: 'March Salary + Bonus',
      );
      final updateRes = await repository.updateTransaction(updatedTxn);
      expect(updateRes.isRight(), isTrue);
      final updated = updateRes.getOrElse((_) => throw Exception());
      expect(updated.amount, 55000);
      expect(updated.notes, 'March Salary + Bonus');

      // Verify Audit Log for update
      final updateAudit = auditLogBox.values.firstWhere(
        (entry) =>
            entry['entity_id'] == createdIncome.id &&
            entry['action'] == 'update',
      );
      expect(updateAudit, isNotNull);

      // 4. Soft Delete (FR-FE-003)
      final deleteRes = await repository.deleteTransaction(createdIncome.id);
      expect(deleteRes.isRight(), isTrue);

      // Verify transaction is hidden from getTransactions
      final listAfterDelete =
          (await repository.getTransactions()).getOrElse((_) => []);
      expect(listAfterDelete.isEmpty, isTrue);

      // Verify raw entry in box has is_deleted = 1
      final rawData = HiveRegistrar.familyTransactionsBox.get(createdIncome.id);
      expect(rawData, isNotNull);
      expect(rawData['is_deleted'], 1);

      // Verify Audit Log for delete
      final deleteAudit = auditLogBox.values.firstWhere(
        (entry) =>
            entry['entity_id'] == createdIncome.id &&
            entry['action'] == 'delete',
      );
      expect(deleteAudit, isNotNull);
    });

    test('Monthly Summaries & Category Domain Isolation (FR-FE-003)', () async {
      final marchDate = DateTime(2026, 3, 10);
      final aprilDate = DateTime(2026, 4, 5);

      // Add March Income
      await repository.addTransaction(FamilyTransaction(
        id: '',
        type: 'income',
        amount: 30000,
        categoryId: 'cat_sal',
        transactionDate: marchDate,
        createdAt: marchDate,
        updatedAt: marchDate,
      ));

      // Add March Expense
      await repository.addTransaction(FamilyTransaction(
        id: '',
        type: 'expense',
        amount: 12000,
        categoryId: 'cat_rent',
        transactionDate: marchDate,
        createdAt: marchDate,
        updatedAt: marchDate,
      ));

      // Add April Expense
      await repository.addTransaction(FamilyTransaction(
        id: '',
        type: 'expense',
        amount: 5000,
        categoryId: 'cat_groc',
        transactionDate: aprilDate,
        createdAt: aprilDate,
        updatedAt: aprilDate,
      ));

      // March totals
      final marchIncome =
          (await repository.getTotalIncomeForMonth(marchDate)).getOrElse((_) => 0);
      final marchExpense =
          (await repository.getTotalExpenseForMonth(marchDate)).getOrElse((_) => 0);
      expect(marchIncome, 30000);
      expect(marchExpense, 12000);

      // April totals
      final aprilIncome =
          (await repository.getTotalIncomeForMonth(aprilDate)).getOrElse((_) => 0);
      final aprilExpense =
          (await repository.getTotalExpenseForMonth(aprilDate)).getOrElse((_) => 0);
      expect(aprilIncome, 0);
      expect(aprilExpense, 5000);

      // Configurable categories test: check income vs expense categories
      final incomeCats =
          (await repository.getCategories(domain: 'income')).getOrElse((_) => []);
      final expenseCats =
          (await repository.getCategories(domain: 'expense')).getOrElse((_) => []);
      expect(incomeCats.every((c) => c.domain == 'income'), isTrue);
      expect(expenseCats.every((c) => c.domain == 'expense'), isTrue);
      expect(incomeCats.isNotEmpty, isTrue);
      expect(expenseCats.isNotEmpty, isTrue);
    });

    test('Family Expense Receipt Photo persistence, replacement, and removal (FR-FE-002)', () async {
      const initialPath = '/var/mobile/Containers/Data/Application/receipt_101.jpg';
      const replacedPath = '/var/mobile/Containers/Data/Application/receipt_102.jpg';

      // 1. Create expense with receipt photo
      final expense = FamilyTransaction(
        id: '',
        type: 'expense',
        amount: 3450,
        categoryId: 'cat_groc',
        receiptPhotoPath: initialPath,
        transactionDate: DateTime(2026, 3, 5),
        notes: 'Monthly groceries with bill',
        createdAt: DateTime(2026, 3, 5),
        updatedAt: DateTime(2026, 3, 5),
      );

      final addResult = await repository.addTransaction(expense);
      expect(addResult.isRight(), isTrue);
      final created = addResult.getOrElse((_) => throw Exception());
      expect(created.receiptPhotoPath, initialPath);

      // Verify retrieved from box
      final fetchResult = await repository.getTransactions(type: 'expense');
      expect(fetchResult.isRight(), isTrue);
      final list = fetchResult.getOrElse((_) => []);
      final found = list.firstWhere((t) => t.id == created.id);
      expect(found.receiptPhotoPath, initialPath);

      // 2. Replace receipt photo with a new photo path
      final updatedWithReplacedPhoto = found.copyWith(receiptPhotoPath: replacedPath);
      final updateResult = await repository.updateTransaction(updatedWithReplacedPhoto);
      expect(updateResult.isRight(), isTrue);
      expect(updateResult.getOrElse((_) => throw Exception()).receiptPhotoPath, replacedPath);

      final listAfterReplace = (await repository.getTransactions(type: 'expense')).getOrElse((_) => []);
      expect(listAfterReplace.firstWhere((t) => t.id == created.id).receiptPhotoPath, replacedPath);

      // 3. Remove receipt photo (set to null)
      final clearedTxn = FamilyTransaction(
        id: found.id,
        type: found.type,
        amount: found.amount,
        categoryId: found.categoryId,
        receiptPhotoPath: null,
        transactionDate: found.transactionDate,
        notes: found.notes,
        createdAt: found.createdAt,
        updatedAt: DateTime.now(),
      );
      final clearResult = await repository.updateTransaction(clearedTxn);
      expect(clearResult.isRight(), isTrue);
      expect(clearResult.getOrElse((_) => throw Exception()).receiptPhotoPath, isNull);

      final listAfterClear = (await repository.getTransactions(type: 'expense')).getOrElse((_) => []);
      expect(listAfterClear.firstWhere((t) => t.id == created.id).receiptPhotoPath, isNull);
    });
  });

  group('FamilyFinanceNotifier State Management Tests', () {
    test('addTransaction, updateTransaction, and deleteTransaction update state and return boolean', () async {
      final mockRepo = MockFamilyFinanceRepository();
      when(() => mockRepo.addTransaction(any()))
          .thenAnswer((invocation) async => right(invocation.positionalArguments.first as FamilyTransaction));
      when(() => mockRepo.updateTransaction(any()))
          .thenAnswer((invocation) async => right(invocation.positionalArguments.first as FamilyTransaction));
      when(() => mockRepo.deleteTransaction(any()))
          .thenAnswer((_) async => right(null));
      when(() => mockRepo.getTransactions(type: any(named: 'type')))
          .thenAnswer((_) async => right([]));
      when(() => mockRepo.getTotalIncomeForMonth(any()))
          .thenAnswer((_) async => right(0.0));
      when(() => mockRepo.getTotalExpenseForMonth(any()))
          .thenAnswer((_) async => right(0.0));

      final container = ProviderContainer(
        overrides: [
          familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(familyFinanceNotifierProvider.notifier);

      final txn = FamilyTransaction(
        id: 'txn-50',
        type: 'expense',
        amount: 1500,
        categoryId: 'cat_groc',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add
      final addSuccess = await notifier.addTransaction(txn);
      expect(addSuccess, isTrue);
      expect(container.read(familyFinanceNotifierProvider), const AsyncData<void>(null));

      // Update
      final updateSuccess = await notifier.updateTransaction(txn.copyWith(amount: 1800));
      expect(updateSuccess, isTrue);

      // Delete
      final deleteSuccess = await notifier.deleteTransaction('txn-50');
      expect(deleteSuccess, isTrue);
    });
  });

  group('ReceiptStorageService Tests (FR-FE-002 Hardened Storage)', () {
    late Directory tempDir;
    late ReceiptStorageService storageService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('receipt_service_test_');
      storageService = ReceiptStorageService(
        baseDirectoryProvider: () async => tempDir,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Persisting receipt image copies source file to persistent receipts directory with unique name', () async {
      // Create dummy temporary source file (simulating ImagePicker cache)
      final sourceFile = File('${tempDir.path}/temp_cache_picker.jpg');
      await sourceFile.writeAsString('mock-image-binary-data');
      expect(sourceFile.existsSync(), isTrue);

      final persistedPath = await storageService.persistReceiptImage(sourceFile.path);

      expect(persistedPath, contains('receipts'));
      expect(persistedPath, endsWith('.jpg'));
      expect(persistedPath, isNot(equals(sourceFile.path)));

      final persistedFile = File(persistedPath);
      expect(persistedFile.existsSync(), isTrue);
      expect(await persistedFile.readAsString(), 'mock-image-binary-data');
    });

    test('Replacing receipt image creates new persistent file and deletes old file safely', () async {
      // 1. Initial persistent file
      final initialSource = File('${tempDir.path}/initial_temp.png');
      await initialSource.writeAsString('initial-image-data');
      final firstPersistedPath = await storageService.persistReceiptImage(initialSource.path);
      expect(File(firstPersistedPath).existsSync(), isTrue);

      // 2. New source file
      final newSource = File('${tempDir.path}/new_temp.png');
      await newSource.writeAsString('new-image-data');

      // 3. Replace
      final secondPersistedPath = await storageService.replaceReceiptImage(
        newSourcePath: newSource.path,
        oldPersistentPath: firstPersistedPath,
      );

      expect(secondPersistedPath, isNot(equals(firstPersistedPath)));
      expect(File(secondPersistedPath).existsSync(), isTrue);
      expect(await File(secondPersistedPath).readAsString(), 'new-image-data');

      // Verify old file was deleted
      expect(File(firstPersistedPath).existsSync(), isFalse);
    });

    test('Deleting receipt image removes persisted file from disk safely', () async {
      final source = File('${tempDir.path}/to_delete_temp.jpg');
      await source.writeAsString('delete-me-data');
      final persistedPath = await storageService.persistReceiptImage(source.path);
      expect(File(persistedPath).existsSync(), isTrue);

      await storageService.deleteReceiptImage(persistedPath);
      expect(File(persistedPath).existsSync(), isFalse);
    });

    test('Handling non-existent source file throws FileSystemException', () async {
      final fakePath = '${tempDir.path}/non_existent_file_12345.jpg';
      expect(
        () async => await storageService.persistReceiptImage(fakePath),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('Deleting null or non-existent file path completes silently without error', () async {
      await storageService.deleteReceiptImage(null);
      await storageService.deleteReceiptImage('');
      await storageService.deleteReceiptImage('${tempDir.path}/already_gone.jpg');
    });
  });
}
