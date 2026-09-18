import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contact.dart';

/// Repository contract for contact CRUD operations.
abstract class ContactRepository {
  /// Returns all non-deleted contacts, optionally filtered by [type].
  Future<Either<Failure, List<Contact>>> getAll({ContactType? type});

  /// Returns a single contact by [id], or null if not found.
  Future<Either<Failure, Contact?>> findById(String id);

  /// Returns true if a non-deleted contact with [mobileNumber] exists.
  Future<bool> existsByMobile(String mobileNumber, {String? excludeId});

  /// Creates a new contact. Caller must pre-validate uniqueness.
  Future<Either<Failure, Contact>> create(Contact contact);

  /// Updates an existing contact.
  Future<Either<Failure, Contact>> update(Contact contact);

  /// Soft-deletes a contact (sets is_deleted = 1).
  Future<Either<Failure, void>> delete(String id);

  /// Returns the total outstanding balance for a contact across all ledger types.
  Future<Either<Failure, double>> getTotalBalance(String contactId);
}
