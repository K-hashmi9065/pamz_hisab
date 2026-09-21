import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/phone_validator.dart';
import '../entities/fl_contact.dart';
import '../repositories/fl_contact_repository.dart';

// ─── Create Contact ────────────────────────────────────────────────────────

class CreateFLContactUsecase {
  const CreateFLContactUsecase(this._repository);
  final FLContactRepository _repository;

  Future<Either<Failure, void>> call(FLContact contact) async {
    final name = contact.name.trim();
    if (name.isEmpty) {
      return const Left(ValidationFailure(
        message: 'Name is required.',
        field: 'name',
      ));
    }

    final mobile = contact.mobileNumber.trim();
    final mobileError = PhoneValidator.validate(mobile);
    if (mobileError != null) {
      return Left(ValidationFailure(message: mobileError, field: 'mobile'));
    }

    // Check duplicate mobile
    final dupResult = await _repository.existsByMobile(mobile);
    final isDuplicate = dupResult.getOrElse((_) => false);
    if (isDuplicate) {
      return const Left(DuplicatePhoneFailure());
    }

    final now = DateTime.now();
    final created = contact.copyWith(
      id: contact.id.isEmpty ? const Uuid().v4() : contact.id,
      name: name,
      mobileNumber: PhoneValidator.normalize(mobile),
      createdAt: now,
      updatedAt: now,
    );

    return _repository.insert(created);
  }
}

// ─── Update Contact ────────────────────────────────────────────────────────

class UpdateFLContactUsecase {
  const UpdateFLContactUsecase(this._repository);
  final FLContactRepository _repository;

  Future<Either<Failure, void>> call(FLContact contact) async {
    final name = contact.name.trim();
    if (name.isEmpty) {
      return const Left(ValidationFailure(
        message: 'Name is required.',
        field: 'name',
      ));
    }

    final mobile = contact.mobileNumber.trim();
    final mobileError = PhoneValidator.validate(mobile);
    if (mobileError != null) {
      return Left(ValidationFailure(message: mobileError, field: 'mobile'));
    }

    // Check duplicate mobile (excluding self)
    final dupResult = await _repository.existsByMobile(
      mobile,
      excludeId: contact.id,
    );
    final isDuplicate = dupResult.getOrElse((_) => false);
    if (isDuplicate) {
      return const Left(DuplicatePhoneFailure());
    }

    final updated = contact.copyWith(
      name: name,
      mobileNumber: PhoneValidator.normalize(mobile),
      updatedAt: DateTime.now(),
    );

    return _repository.update(updated);
  }
}

// ─── Delete Contact ────────────────────────────────────────────────────────

class DeleteFLContactUsecase {
  const DeleteFLContactUsecase(this._repository);
  final FLContactRepository _repository;

  Future<Either<Failure, void>> call(String contactId) =>
      _repository.softDelete(contactId);
}

// ─── Get Contacts ──────────────────────────────────────────────────────────

class GetFLContactsUsecase {
  const GetFLContactsUsecase(this._repository);
  final FLContactRepository _repository;

  Future<Either<Failure, List<FLContact>>> call() =>
      _repository.getAll();
}

// ─── Get Contact By ID ──────────────────────────────────────────────────────

class GetFLContactByIdUsecase {
  const GetFLContactByIdUsecase(this._repository);
  final FLContactRepository _repository;

  Future<Either<Failure, FLContact?>> call(String id) =>
      _repository.findById(id);
}

// ─── Aadhaar validation helper ──────────────────────────────────────────────

/// Validates Aadhaar string format: 12 digits (stored as String).
String? validateAadhaar(String? value) {
  if (value == null || value.trim().isEmpty) return null; // optional field
  final cleaned = value.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{12}$').hasMatch(cleaned)) {
    return 'Aadhaar must be exactly 12 digits.';
  }
  return null;
}
