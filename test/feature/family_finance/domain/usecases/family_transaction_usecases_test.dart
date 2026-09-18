import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/domain/usecases/family_finance_usecases.dart';

import '../../../../test_helpers/mocks.dart';

void main() {
  late MockFamilyFinanceRepository repository;
  late AddFamilyTransactionUsecase addUsecase;
  late UpdateFamilyTransactionUsecase updateUsecase;
  late DeleteFamilyTransactionUsecase deleteUsecase;
  late GetFamilyTransactionsUsecase getUsecase;

  setUpAll(registerFallbacks);

  setUp(() {
    repository = MockFamilyFinanceRepository();
    addUsecase = AddFamilyTransactionUsecase(repository);
    updateUsecase = UpdateFamilyTransactionUsecase(repository);
    deleteUsecase = DeleteFamilyTransactionUsecase(repository);
    getUsecase = GetFamilyTransactionsUsecase(repository);
  });

  group('AddFamilyTransactionUsecase Validation & Execution', () {
    test('rejects transaction when amount is zero', () async {
      final txn = FamilyTransaction(
        id: 'txn-zero',
        type: 'expense',
        amount: 0.0,
        categoryId: 'cat-groceries',
        transactionDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await addUsecase(txn);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'amount');
          expect(failure.message, 'Amount must be greater than zero.');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.addTransaction(any()));
    });

    test('rejects transaction when amount is negative', () async {
      final txn = FamilyTransaction(
        id: 'txn-neg',
        type: 'expense',
        amount: -150.0,
        categoryId: 'cat-groceries',
        transactionDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await addUsecase(txn);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'amount');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.addTransaction(any()));
    });

    test('rejects transaction when categoryId is empty', () async {
      final txn = FamilyTransaction(
        id: 'txn-no-cat',
        type: 'income',
        amount: 5000.0,
        categoryId: '',
        transactionDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await addUsecase(txn);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'categoryId');
          expect(failure.message, 'Category is required.');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.addTransaction(any()));
    });

    test('valid income transaction reaches repository', () async {
      final validIncome = FamilyTransaction(
        id: 'txn-inc-1',
        type: 'income',
        amount: 85000.0,
        categoryId: 'cat-salary',
        accountId: 'acc-bank',
        sourceTag: 'Monthly Salary',
        transactionDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      when(() => repository.addTransaction(any()))
          .thenAnswer((_) async => right(validIncome));

      final result = await addUsecase(validIncome);

      expect(result.isRight(), isTrue);
      result.match(
        (l) => fail('Should have succeeded'),
        (txn) => expect(txn.amount, 85000.0),
      );
      verify(() => repository.addTransaction(validIncome)).called(1);
    });

    test('valid expense transaction reaches repository', () async {
      final validExpense = FamilyTransaction(
        id: 'txn-exp-1',
        type: 'expense',
        amount: 12500.0,
        categoryId: 'cat-groceries',
        accountId: 'acc-cash',
        receiptPhotoPath: '/receipts/receipt_001.jpg',
        notes: 'Monthly ration store',
        transactionDate: DateTime(2026, 3, 5),
        createdAt: DateTime(2026, 3, 5),
        updatedAt: DateTime(2026, 3, 5),
      );

      when(() => repository.addTransaction(any()))
          .thenAnswer((_) async => right(validExpense));

      final result = await addUsecase(validExpense);

      expect(result.isRight(), isTrue);
      verify(() => repository.addTransaction(validExpense)).called(1);
    });
  });

  group('UpdateFamilyTransactionUsecase Validation & Execution', () {
    test('rejects update when amount is zero or negative', () async {
      final invalidTxn = FamilyTransaction(
        id: 'txn-upd-1',
        type: 'expense',
        amount: 0.0,
        categoryId: 'cat-util',
        transactionDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await updateUsecase(invalidTxn);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'amount');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.updateTransaction(any()));
    });

    test('rejects update when categoryId is empty', () async {
      final invalidTxn = FamilyTransaction(
        id: 'txn-upd-2',
        type: 'expense',
        amount: 500.0,
        categoryId: '',
        transactionDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final result = await updateUsecase(invalidTxn);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'categoryId');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.updateTransaction(any()));
    });

    test('valid update reaches repository', () async {
      final updatedTxn = FamilyTransaction(
        id: 'txn-upd-3',
        type: 'expense',
        amount: 3200.0,
        categoryId: 'cat-util',
        notes: 'Updated electricity bill',
        transactionDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 2),
      );

      when(() => repository.updateTransaction(any()))
          .thenAnswer((_) async => right(updatedTxn));

      final result = await updateUsecase(updatedTxn);

      expect(result.isRight(), isTrue);
      verify(() => repository.updateTransaction(updatedTxn)).called(1);
    });
  });

  group('DeleteFamilyTransactionUsecase & GetFamilyTransactionsUsecase', () {
    test('delete calls repository with transaction id', () async {
      when(() => repository.deleteTransaction('txn-del-1'))
          .thenAnswer((_) async => right(null));

      final result = await deleteUsecase('txn-del-1');

      expect(result.isRight(), isTrue);
      verify(() => repository.deleteTransaction('txn-del-1')).called(1);
    });

    test('get calls repository with optional type filter', () async {
      when(() => repository.getTransactions(type: 'income'))
          .thenAnswer((_) async => right([]));

      final result = await getUsecase(type: 'income');

      expect(result.isRight(), isTrue);
      verify(() => repository.getTransactions(type: 'income')).called(1);
    });
  });
}
