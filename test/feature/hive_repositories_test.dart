import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/feature/contacts/data/datasources/contact_hive_datasource.dart';
import 'package:pamz_khata/feature/contacts/data/repositories/contact_repository_impl.dart';
import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/direct_udhar/data/repositories/direct_udhar_hive_repository_impl.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/family_finance/data/repositories/family_finance_hive_repository_impl.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';

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

      // Soft delete
      final deleteRes = await repository.delete(created.id);
      expect(deleteRes.isRight(), isTrue);

      final afterDeleteList = (await repository.getAll()).getOrElse((_) => []);
      expect(afterDeleteList.isEmpty, isTrue);
    });
  });

  group('Direct Udhar Hive Repository Tests', () {
    test('Create loan, record repayment, update balance and status', () async {
      const repository = DirectUdharHiveRepositoryImpl();

      final loan = DirectUdharLoan(
        id: '',
        contactId: 'contact_123',
        direction: LoanDirection.lent,
        principalAmount: 5000,
        interestType: InterestType.interestFree,
        status: LoanStatus.open,
        outstandingBalance: 5000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createRes = await repository.create(loan);
      expect(createRes.isRight(), isTrue);
      final created = createRes.getOrElse((_) => throw Exception());
      expect(created.id.isNotEmpty, isTrue);
      expect(created.outstandingBalance, 5000);

      // Record partial repayment
      final repayment = Repayment(
        id: '',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: created.id,
        amount: 2000,
        paymentMode: 'cash',
        paidAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final repayRes = await repository.recordRepayment(created.id, repayment);
      expect(repayRes.isRight(), isTrue);

      final updatedLoan = (await repository.findById(created.id)).getOrElse((_) => null);
      expect(updatedLoan, isNotNull);
      expect(updatedLoan!.outstandingBalance, 3000);
      expect(updatedLoan.status, LoanStatus.partiallyPaid);

      // Record remaining repayment
      final finalRepayment = Repayment(
        id: '',
        sourceType: RepaymentSourceType.directUdhar,
        sourceId: created.id,
        amount: 3000,
        paymentMode: 'upi',
        paidAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await repository.recordRepayment(created.id, finalRepayment);

      final closedLoan = (await repository.findById(created.id)).getOrElse((_) => null);
      expect(closedLoan!.outstandingBalance, 0);
      expect(closedLoan.status, LoanStatus.closed);

      // Repayments history
      final historyRes = await repository.getRepayments(created.id);
      expect(historyRes.isRight(), isTrue);
      final history = historyRes.getOrElse((_) => []);
      expect(history.length, 2);
    });
  });

  group('Family Finance Hive Repository Tests', () {
    test('Add income/expense, retrieve list, verify categories and monthly totals', () async {
      const repository = FamilyFinanceHiveRepositoryImpl();

      // Check default seeded categories
      final categoriesRes = await repository.getCategories();
      expect(categoriesRes.isRight(), isTrue);
      final categories = categoriesRes.getOrElse((_) => []);
      expect(categories.isNotEmpty, isTrue);

      // Add income
      final incomeTxn = FamilyTransaction(
        id: '',
        type: 'income',
        amount: 25000,
        categoryId: 'cat_sal',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final addIncomeRes = await repository.addTransaction(incomeTxn);
      expect(addIncomeRes.isRight(), isTrue);

      // Add expense
      final expenseTxn = FamilyTransaction(
        id: '',
        type: 'expense',
        amount: 4500,
        categoryId: 'cat_groc',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final addExpenseRes = await repository.addTransaction(expenseTxn);
      expect(addExpenseRes.isRight(), isTrue);

      // Verify list
      final allTxns = (await repository.getTransactions()).getOrElse((_) => []);
      expect(allTxns.length, 2);

      // Verify monthly totals
      final now = DateTime.now();
      final totalIncome = (await repository.getTotalIncomeForMonth(now)).getOrElse((_) => 0);
      final totalExpense = (await repository.getTotalExpenseForMonth(now)).getOrElse((_) => 0);

      expect(totalIncome, 25000);
      expect(totalExpense, 4500);

      // Update transaction
      final createdIncome = addIncomeRes.getOrElse((_) => throw Exception());
      final updatedIncome = createdIncome.copyWith(amount: 28000, notes: 'Bonus included');
      final updateRes = await repository.updateTransaction(updatedIncome);
      expect(updateRes.isRight(), isTrue);
      expect(updateRes.getOrElse((_) => throw Exception()).amount, 28000);

      // Delete transaction (soft-delete)
      final deleteRes = await repository.deleteTransaction(createdIncome.id);
      expect(deleteRes.isRight(), isTrue);

      final listAfterDelete = (await repository.getTransactions(type: 'income')).getOrElse((_) => []);
      expect(listAfterDelete.isEmpty, isTrue);
    });

    test('Monthly summary adjustments on update, month move, type switch, and soft-delete in Hive', () async {
      const repository = FamilyFinanceHiveRepositoryImpl();
      final dateMay = DateTime(2026, 5, 10);
      final dateJune = DateTime(2026, 6, 10);

      // 1. Add Expense: 1000 in May
      final expTxn = FamilyTransaction(
        id: '',
        type: 'expense',
        amount: 1000,
        categoryId: 'cat_groc',
        transactionDate: dateMay,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final addExpRes = await repository.addTransaction(expTxn);
      final createdExp = addExpRes.getOrElse((_) => throw Exception());

      var mayExpense = (await repository.getTotalExpenseForMonth(dateMay)).getOrElse((_) => 0);
      expect(mayExpense, 1000.0);

      // 2. Update amount in same month: 1000 -> 1500
      await repository.updateTransaction(createdExp.copyWith(amount: 1500));
      mayExpense = (await repository.getTotalExpenseForMonth(dateMay)).getOrElse((_) => 0);
      expect(mayExpense, 1500.0);

      // 3. Move from May to June
      await repository.updateTransaction(createdExp.copyWith(amount: 1500, transactionDate: dateJune));
      mayExpense = (await repository.getTotalExpenseForMonth(dateMay)).getOrElse((_) => 0);
      var juneExpense = (await repository.getTotalExpenseForMonth(dateJune)).getOrElse((_) => 0);
      expect(mayExpense, 0.0);
      expect(juneExpense, 1500.0);

      // 4. Switch from Expense to Income (5000) in June
      await repository.updateTransaction(createdExp.copyWith(
        type: 'income',
        categoryId: 'cat_sal',
        amount: 5000,
        transactionDate: dateJune,
      ));
      juneExpense = (await repository.getTotalExpenseForMonth(dateJune)).getOrElse((_) => 0);
      var juneIncome = (await repository.getTotalIncomeForMonth(dateJune)).getOrElse((_) => 0);
      expect(juneExpense, 0.0);
      expect(juneIncome, 5000.0);

      // 5. Soft delete returns income to 0.0 without negative balance
      await repository.deleteTransaction(createdExp.id);
      juneIncome = (await repository.getTotalIncomeForMonth(dateJune)).getOrElse((_) => 0);
      expect(juneIncome, 0.0);
    });
  });
}
