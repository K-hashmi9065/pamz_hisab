import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';
import '../../data/datasources/contact_datasource.dart';
import '../../data/datasources/contact_hive_datasource.dart';
import '../../data/datasources/contact_sqlite_datasource.dart';
import '../../data/repositories/contact_repository_impl.dart';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/usecases/contact_usecases.dart';

// ─── Infrastructure Providers ──────────────────────────────────────────────

final databaseHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper(AppDatabase.instance),
);

final contactDataSourceProvider = Provider<ContactDataSource>(
  (ref) => AppStorageConfig.isHive
      ? const ContactHiveDataSource()
      : ContactSqliteDataSource(ref.watch(databaseHelperProvider)),
);

final contactRepositoryProvider = Provider<ContactRepository>(
  (ref) => ContactRepositoryImpl(ref.watch(contactDataSourceProvider)),
);

// ─── Usecase Providers ─────────────────────────────────────────────────────

final createContactUsecaseProvider = Provider<CreateContactUsecase>(
  (ref) => CreateContactUsecase(ref.watch(contactRepositoryProvider)),
);

final updateContactUsecaseProvider = Provider<UpdateContactUsecase>(
  (ref) => UpdateContactUsecase(ref.watch(contactRepositoryProvider)),
);

final deleteContactUsecaseProvider = Provider<DeleteContactUsecase>(
  (ref) => DeleteContactUsecase(ref.watch(contactRepositoryProvider)),
);

final getContactsUsecaseProvider = Provider<GetContactsUsecase>(
  (ref) => GetContactsUsecase(ref.watch(contactRepositoryProvider)),
);

// ─── List Providers ────────────────────────────────────────────────────────

final buyerListProvider = FutureProvider<List<Contact>>((ref) async {
  final usecase = ref.watch(getContactsUsecaseProvider);
  final result = await usecase(type: ContactType.buyer);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (contacts) => contacts,
  );
});

final supplierListProvider = FutureProvider<List<Contact>>((ref) async {
  final usecase = ref.watch(getContactsUsecaseProvider);
  final result = await usecase(type: ContactType.supplier);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (contacts) => contacts,
  );
});

final allContactListProvider = FutureProvider<List<Contact>>((ref) async {
  final usecase = ref.watch(getContactsUsecaseProvider);
  final result = await usecase();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (contacts) => contacts,
  );
});

final contactByIdProvider =
    FutureProvider.family<Contact?, String>((ref, contactId) async {
  final repo = ref.watch(contactRepositoryProvider);
  final result = await repo.findById(contactId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (contact) => contact,
  );
});

final contactTotalBalanceProvider =
    FutureProvider.family<double, String>((ref, contactId) async {
  final repo = ref.watch(contactRepositoryProvider);
  final result = await repo.getTotalBalance(contactId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (balance) => balance,
  );
});

// ─── Notifier for CRUD operations ──────────────────────────────────────────

class ContactFormNotifier extends StateNotifier<AsyncValue<void>> {
  ContactFormNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> createContact(Contact contact) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(createContactUsecaseProvider);
    final result = await usecase(contact);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(buyerListProvider);
        _ref.invalidate(supplierListProvider);
        _ref.invalidate(allContactListProvider);
        return true;
      },
    );
  }

  Future<bool> updateContact(Contact contact) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(updateContactUsecaseProvider);
    final result = await usecase(contact);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(buyerListProvider);
        _ref.invalidate(supplierListProvider);
        _ref.invalidate(allContactListProvider);
        _ref.invalidate(contactByIdProvider(contact.id));
        _ref.invalidate(contactTotalBalanceProvider(contact.id));
        return true;
      },
    );
  }

  Future<bool> deleteContact(String contactId) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(deleteContactUsecaseProvider);
    final result = await usecase(contactId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(buyerListProvider);
        _ref.invalidate(supplierListProvider);
        _ref.invalidate(allContactListProvider);
        _ref.invalidate(contactByIdProvider(contactId));
        _ref.invalidate(contactTotalBalanceProvider(contactId));
        return true;
      },
    );
  }
}

final contactFormNotifierProvider =
    StateNotifierProvider<ContactFormNotifier, AsyncValue<void>>(
  (ref) => ContactFormNotifier(ref),
);
