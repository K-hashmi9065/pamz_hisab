import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/fl_contact.dart';

/// Abstract repository contract for Fund Ledger contacts.
abstract interface class FLContactRepository {
  /// Returns all non-deleted contacts, ordered by name.
  Future<Either<Failure, List<FLContact>>> getAll();

  /// Returns a single contact by ID, or null if not found/deleted.
  Future<Either<Failure, FLContact?>> findById(String id);

  /// Returns true if a contact with [mobile] exists (excluding [excludeId]).
  Future<Either<Failure, bool>> existsByMobile(
    String mobile, {
    String? excludeId,
  });

  /// Inserts a new contact. Fails if ID already exists.
  Future<Either<Failure, void>> insert(FLContact contact);

  /// Updates an existing contact.
  Future<Either<Failure, void>> update(FLContact contact);

  /// Soft-deletes a contact.
  Future<Either<Failure, void>> softDelete(String id);
}
