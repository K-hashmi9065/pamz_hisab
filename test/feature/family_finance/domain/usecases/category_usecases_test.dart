import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/domain/usecases/family_finance_usecases.dart';

import '../../../../test_helpers/mocks.dart';

void main() {
  late MockFamilyFinanceRepository repository;
  late CreateCategoryUsecase createCategoryUsecase;
  late UpdateCategoryUsecase updateCategoryUsecase;
  late DeleteCategoryUsecase deleteCategoryUsecase;
  late GetCategoriesUsecase getCategoriesUsecase;

  setUpAll(registerFallbacks);

  setUp(() {
    repository = MockFamilyFinanceRepository();
    createCategoryUsecase = CreateCategoryUsecase(repository);
    updateCategoryUsecase = UpdateCategoryUsecase(repository);
    deleteCategoryUsecase = DeleteCategoryUsecase(repository);
    getCategoriesUsecase = GetCategoriesUsecase(repository);
  });

  group('CreateCategoryUsecase Validation & Execution', () {
    test('rejects category with empty or whitespace-only name', () async {
      const category = TransactionCategory(
        id: 'cat-1',
        domain: 'income',
        name: '   ',
        iconKey: '💼',
        colorHex: '#4CAF50',
      );

      final result = await createCategoryUsecase(category);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'name');
          expect(failure.message, 'Category name is required.');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.createCategory(any()));
    });

    test('rejects category with invalid domain (not income or expense)', () async {
      const category = TransactionCategory(
        id: 'cat-2',
        domain: 'investment', // invalid domain
        name: 'Stocks',
        iconKey: '📈',
        colorHex: '#2196F3',
      );

      final result = await createCategoryUsecase(category);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'domain');
          expect(failure.message, 'Category domain must be income or expense.');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.createCategory(any()));
    });

    test('valid income category is passed to repository', () async {
      const validCategory = TransactionCategory(
        id: 'cat-inc-1',
        domain: 'income',
        name: 'Jute Harvest Sales',
        iconKey: '🌾',
        colorHex: '#8BC34A',
      );

      when(() => repository.createCategory(any()))
          .thenAnswer((_) async => right(validCategory));

      final result = await createCategoryUsecase(validCategory);

      expect(result.isRight(), isTrue);
      result.match(
        (l) => fail('Should have succeeded'),
        (cat) => expect(cat.name, 'Jute Harvest Sales'),
      );
      verify(() => repository.createCategory(validCategory)).called(1);
    });

    test('valid expense category is passed to repository', () async {
      const validExpenseCategory = TransactionCategory(
        id: 'cat-exp-1',
        domain: 'expense',
        name: 'Fertilizer & Seeds',
        iconKey: '🌱',
        colorHex: '#4CAF50',
      );

      when(() => repository.createCategory(any()))
          .thenAnswer((_) async => right(validExpenseCategory));

      final result = await createCategoryUsecase(validExpenseCategory);

      expect(result.isRight(), isTrue);
      verify(() => repository.createCategory(validExpenseCategory)).called(1);
    });
  });

  group('UpdateCategoryUsecase Validation & Execution', () {
    test('rejects update when category id is empty', () async {
      const category = TransactionCategory(
        id: '',
        domain: 'expense',
        name: 'Diesel',
      );

      final result = await updateCategoryUsecase(category);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'id');
          expect(failure.message, 'Category id is required for update.');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.updateCategory(any()));
    });

    test('rejects update when category name is empty', () async {
      const category = TransactionCategory(
        id: 'cat-update-1',
        domain: 'expense',
        name: '',
      );

      final result = await updateCategoryUsecase(category);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'name');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.updateCategory(any()));
    });

    test('valid update reaches repository', () async {
      const updatedCategory = TransactionCategory(
        id: 'cat-update-1',
        domain: 'expense',
        name: 'Tractor Fuel & Repair',
        iconKey: '🚜',
        colorHex: '#795548',
      );

      when(() => repository.updateCategory(any()))
          .thenAnswer((_) async => right(updatedCategory));

      final result = await updateCategoryUsecase(updatedCategory);

      expect(result.isRight(), isTrue);
      verify(() => repository.updateCategory(updatedCategory)).called(1);
    });
  });

  group('DeleteCategoryUsecase Validation & Execution', () {
    test('rejects delete when category id is empty', () async {
      final result = await deleteCategoryUsecase('');

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).field, 'id');
        },
        (_) => fail('Expected ValidationFailure'),
      );
      verifyNever(() => repository.deleteCategory(any()));
    });

    test('valid delete calls repository', () async {
      when(() => repository.deleteCategory('cat-del-1'))
          .thenAnswer((_) async => right(null));

      final result = await deleteCategoryUsecase('cat-del-1');

      expect(result.isRight(), isTrue);
      verify(() => repository.deleteCategory('cat-del-1')).called(1);
    });
  });

  group('GetCategoriesUsecase Execution', () {
    test('queries repository with specified domain filter', () async {
      when(() => repository.getCategories(domain: 'income'))
          .thenAnswer((_) async => right([]));

      final result = await getCategoriesUsecase(domain: 'income');

      expect(result.isRight(), isTrue);
      verify(() => repository.getCategories(domain: 'income')).called(1);
    });
  });
}
