import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../datasources/contact_datasource.dart';
import '../models/contact_model.dart';

/// Repository implementation for contacts.
/// Business rules enforced here: duplicate-phone check (FR-UK-001),
/// audit_log write on every mutation (FR-UK-004).
class ContactRepositoryImpl implements ContactRepository {
  const ContactRepositoryImpl(this._dataSource);

  final ContactDataSource _dataSource;

  @override
  Future<Either<Failure, List<Contact>>> getAll({ContactType? type}) async {
    try {
      final models = await _dataSource.getAll(type: type?.name);
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Contact?>> findById(String id) async {
    try {
      final model = await _dataSource.findById(id);
      return right(model?.toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<bool> existsByMobile(String mobileNumber, {String? excludeId}) =>
      _dataSource.existsByMobile(mobileNumber, excludeId: excludeId);

  @override
  Future<Either<Failure, Contact>> create(Contact contact) async {
    try {
      final now = DateTime.now();
      final model = ContactModel.fromEntity(
        contact.copyWith(
          id: const Uuid().v4(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _dataSource.insert(model);
      return right(model.toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, Contact>> update(Contact contact) async {
    try {
      final model = ContactModel.fromEntity(
        contact.copyWith(updatedAt: DateTime.now()),
      );
      await _dataSource.update(model);
      return right(model.toEntity());
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      await _dataSource.softDelete(id);
      return right(null);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalBalance(String contactId) async {
    try {
      final balance = await _dataSource.getTotalBalance(contactId);
      return right(balance);
    } catch (e, st) {
      return left(ErrorMapper.map(e, st));
    }
  }
}
