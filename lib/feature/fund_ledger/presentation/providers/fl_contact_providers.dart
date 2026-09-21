import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';
import '../../data/datasources/fl_contact_datasource.dart';
import '../../data/datasources/fl_contact_hive_datasource.dart';
import '../../data/datasources/fl_contact_sqlite_datasource.dart';
import '../../data/repositories/fl_contact_repository_impl.dart';
import '../../domain/entities/fl_contact.dart';
import '../../domain/repositories/fl_contact_repository.dart';
import '../../domain/repositories/fl_transaction_repository.dart';
import '../../domain/usecases/fl_contact_usecases.dart';
import 'fl_transaction_providers.dart';

// ─── Infrastructure Providers ──────────────────────────────────────────────

final flDbHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper(AppDatabase.instance),
);

final flContactDataSourceProvider = Provider<FLContactDataSource>(
  (ref) => AppStorageConfig.isHive
      ? const FLContactHiveDataSource()
      : FLContactSqliteDataSource(ref.watch(flDbHelperProvider)),
);

final flContactRepositoryProvider = Provider<FLContactRepository>(
  (ref) => FLContactRepositoryImpl(ref.watch(flContactDataSourceProvider)),
);

// ─── Usecase Providers ─────────────────────────────────────────────────────

final createFLContactUsecaseProvider = Provider<CreateFLContactUsecase>(
  (ref) => CreateFLContactUsecase(ref.watch(flContactRepositoryProvider)),
);

final updateFLContactUsecaseProvider = Provider<UpdateFLContactUsecase>(
  (ref) => UpdateFLContactUsecase(ref.watch(flContactRepositoryProvider)),
);

final deleteFLContactUsecaseProvider = Provider<DeleteFLContactUsecase>(
  (ref) => DeleteFLContactUsecase(ref.watch(flContactRepositoryProvider)),
);

final getFLContactsUsecaseProvider = Provider<GetFLContactsUsecase>(
  (ref) => GetFLContactsUsecase(ref.watch(flContactRepositoryProvider)),
);

final getFLContactByIdUsecaseProvider = Provider<GetFLContactByIdUsecase>(
  (ref) => GetFLContactByIdUsecase(ref.watch(flContactRepositoryProvider)),
);

// ─── List Provider ─────────────────────────────────────────────────────────

/// All non-deleted Fund Ledger contacts, sorted by name.
final flContactListProvider = FutureProvider<List<FLContact>>((ref) async {
  final usecase = ref.watch(getFLContactsUsecaseProvider);
  final result = await usecase();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (contacts) => contacts,
  );
});

// ─── Search Providers ─────────────────────────────────────────────────────

final flContactSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered contact list based on the current search query.
final flFilteredContactListProvider =
    Provider<AsyncValue<List<FLContact>>>((ref) {
  final query = ref.watch(flContactSearchQueryProvider).trim().toLowerCase();
  final contactsAsync = ref.watch(flContactListProvider);

  return contactsAsync.whenData((contacts) {
    if (query.isEmpty) return contacts;
    return contacts.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.mobileNumber.contains(query) ||
          (c.project?.toLowerCase().contains(query) ?? false);
    }).toList();
  });
});

// ─── Detail Provider ────────────────────────────────────────────────────────

final flContactByIdProvider =
    FutureProvider.family<FLContact?, String>((ref, contactId) async {
  final usecase = ref.watch(getFLContactByIdUsecaseProvider);
  final result = await usecase(contactId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (contact) => contact,
  );
});

// ─── Summary Provider (per-contact) ────────────────────────────────────────

/// Per-contact summary with available = received - returned.
final flContactSummaryProvider =
    FutureProvider.family<FLContactSummaryData?, String>((ref, contactId) async {
  final contact = await ref.watch(flContactByIdProvider(contactId).future);
  if (contact == null) return null;

  final repo = ref.watch(flTransactionRepositoryProvider);
  final totalsResult = await repo.getTotals(contactId);
  final totals = totalsResult.getOrElse((_) => FLContactTotals.zero());

  return FLContactSummaryData(
    contact: contact,
    totalReceived: totals.totalReceived,
    totalUtilized: totals.totalUtilized,
    totalReturned: totals.totalReturned,
  );
});

/// Serializable per-contact summary value object.
class FLContactSummaryData {
  const FLContactSummaryData({
    required this.contact,
    required this.totalReceived,
    required this.totalUtilized,
    required this.totalReturned,
  });

  final FLContact contact;
  final double totalReceived;
  final double totalUtilized;
  final double totalReturned;

  /// Available = Received - Returned (utilization excluded by design).
  double get availableAmount => totalReceived - totalReturned;
}

// ─── CRUD Notifier ─────────────────────────────────────────────────────────

class FLContactFormNotifier extends StateNotifier<AsyncValue<void>> {
  FLContactFormNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> createContact(FLContact contact) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(createFLContactUsecaseProvider);
    final result = await usecase(contact);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(flContactListProvider);
        _ref.invalidate(flDashboardSummaryProvider);
        return true;
      },
    );
  }

  Future<bool> updateContact(FLContact contact) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(updateFLContactUsecaseProvider);
    final result = await usecase(contact);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(flContactListProvider);
        _ref.invalidate(flContactByIdProvider(contact.id));
        _ref.invalidate(flContactSummaryProvider(contact.id));
        return true;
      },
    );
  }

  Future<bool> deleteContact(String contactId) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(deleteFLContactUsecaseProvider);
    final result = await usecase(contactId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(flContactListProvider);
        _ref.invalidate(flContactByIdProvider(contactId));
        _ref.invalidate(flContactSummaryProvider(contactId));
        _ref.invalidate(flDashboardSummaryProvider);
        return true;
      },
    );
  }
}

final flContactFormNotifierProvider =
    StateNotifierProvider<FLContactFormNotifier, AsyncValue<void>>(
  (ref) => FLContactFormNotifier(ref),
);


