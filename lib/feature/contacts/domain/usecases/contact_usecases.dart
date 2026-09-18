import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/phone_validator.dart';
import '../entities/contact.dart';
import '../repositories/contact_repository.dart';

/// Creates a new contact with duplicate-phone and format validation.
/// Enforces FR-UK-001: unique 10-digit Indian mobile.
class CreateContactUsecase {
  const CreateContactUsecase(this._repository);

  final ContactRepository _repository;

  Future<Either<Failure, Contact>> call(Contact contact) async {
    // 1. Validate phone format first (before any DB call)
    final normalizedPhone = PhoneValidator.normalize(contact.mobileNumber);
    if (!PhoneValidator.isValidIndianMobile(normalizedPhone)) {
      return left(const ValidationFailure(
        message: 'Enter a valid 10-digit Indian mobile number starting with 6-9.',
        field: 'mobileNumber',
      ));
    }

    // 2. Check uniqueness
    final exists = await _repository.existsByMobile(normalizedPhone);
    if (exists) {
      return left(const DuplicatePhoneFailure());
    }

    // 3. Persist
    return _repository.create(contact.copyWith(mobileNumber: normalizedPhone));
  }
}

/// Updates contact; validates phone uniqueness excluding self.
class UpdateContactUsecase {
  const UpdateContactUsecase(this._repository);

  final ContactRepository _repository;

  Future<Either<Failure, Contact>> call(Contact contact) async {
    final normalizedPhone = PhoneValidator.normalize(contact.mobileNumber);
    if (!PhoneValidator.isValidIndianMobile(normalizedPhone)) {
      return left(const ValidationFailure(
        message: 'Enter a valid 10-digit Indian mobile number.',
        field: 'mobileNumber',
      ));
    }

    final exists = await _repository.existsByMobile(
      normalizedPhone,
      excludeId: contact.id,
    );
    if (exists) {
      return left(const DuplicatePhoneFailure());
    }

    return _repository.update(contact.copyWith(mobileNumber: normalizedPhone));
  }
}

/// Soft-deletes a contact.
class DeleteContactUsecase {
  const DeleteContactUsecase(this._repository);

  final ContactRepository _repository;

  Future<Either<Failure, void>> call(String contactId) =>
      _repository.delete(contactId);
}

/// Returns all contacts, optionally filtered by type.
class GetContactsUsecase {
  const GetContactsUsecase(this._repository);

  final ContactRepository _repository;

  Future<Either<Failure, List<Contact>>> call({ContactType? type}) =>
      _repository.getAll(type: type);
}
