import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/contacts/domain/usecases/contact_usecases.dart';

import '../../../../test_helpers/fixtures.dart';
import '../../../../test_helpers/mocks.dart';

void main() {
  late MockContactRepository repository;
  late CreateContactUsecase createUsecase;
  late UpdateContactUsecase updateUsecase;

  setUpAll(registerFallbacks);

  setUp(() {
    repository = MockContactRepository();
    createUsecase = CreateContactUsecase(repository);
    updateUsecase = UpdateContactUsecase(repository);
  });

  // ─── CreateContactUsecase ────────────────────────────────────────────

  group('CreateContactUsecase', () {
    test('returns DuplicatePhoneFailure when mobile number already exists', () async {
      when(() => repository.existsByMobile('9876543210'))
          .thenAnswer((_) async => true);

      final result = await createUsecase(
        buyerFixture.copyWith(mobileNumber: '9876543210'),
      );

      expect(result.isLeft(), true);
      result.match(
        (failure) => expect(failure, isA<DuplicatePhoneFailure>()),
        (_) => fail('Expected failure but got success'),
      );

      verify(() => repository.existsByMobile('9876543210')).called(1);
      verifyNever(() => repository.create(any()));
    });

    test('creates contact and returns entity when mobile number is unique', () async {
      when(() => repository.existsByMobile(any()))
          .thenAnswer((_) async => false);
      when(() => repository.create(any()))
          .thenAnswer((_) async => right(buyerFixture));

      final result = await createUsecase(buyerFixture);

      expect(result.isRight(), true);
      verify(() => repository.create(any())).called(1);
    });

    test('rejects invalid 10-digit Indian mobile format before hitting repository', () async {
      final result = await createUsecase(
        buyerFixture.copyWith(mobileNumber: '12345'),
      );

      expect(result.isLeft(), true);
      result.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected ValidationFailure'),
      );

      // Repository should never be called for invalid format
      verifyNever(() => repository.existsByMobile(any()));
      verifyNever(() => repository.create(any()));
    });

    test('rejects mobile number starting with 5', () async {
      final result = await createUsecase(
        buyerFixture.copyWith(mobileNumber: '5876543210'),
      );

      expect(result.isLeft(), true);
      result.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected ValidationFailure'),
      );
    });

    test('normalizes +91 prefix before uniqueness check', () async {
      when(() => repository.existsByMobile('9876543210'))
          .thenAnswer((_) async => false);
      when(() => repository.create(any()))
          .thenAnswer((_) async => right(buyerFixture));

      await createUsecase(
        buyerFixture.copyWith(mobileNumber: '+919876543210'),
      );

      // Must normalize to 10 digits before querying
      verify(() => repository.existsByMobile('9876543210')).called(1);
    });
  });

  // ─── UpdateContactUsecase ─────────────────────────────────────────────

  group('UpdateContactUsecase', () {
    test('succeeds when phone is unique (excluding self)', () async {
      when(() => repository.existsByMobile('9876543210', excludeId: 'contact-001'))
          .thenAnswer((_) async => false);
      when(() => repository.update(any()))
          .thenAnswer((_) async => right(buyerFixture));

      final result = await updateUsecase(buyerFixture);

      expect(result.isRight(), true);
      verify(() => repository.existsByMobile('9876543210', excludeId: 'contact-001'))
          .called(1);
    });

    test('returns DuplicatePhoneFailure when another contact has same mobile', () async {
      when(() => repository.existsByMobile('9876543210', excludeId: 'contact-001'))
          .thenAnswer((_) async => true);

      final result = await updateUsecase(buyerFixture);

      expect(result.isLeft(), true);
      result.match(
        (failure) => expect(failure, isA<DuplicatePhoneFailure>()),
        (_) => fail('Expected failure'),
      );
      verifyNever(() => repository.update(any()));
    });
  });
}
