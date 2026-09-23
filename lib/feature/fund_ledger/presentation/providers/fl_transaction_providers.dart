import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';
import '../../data/datasources/fl_transaction_datasource.dart';
import '../../data/datasources/fl_transaction_hive_datasource.dart';
import '../../data/datasources/fl_transaction_sqlite_datasource.dart';
import '../../data/repositories/fl_transaction_repository_impl.dart';
import '../../data/services/fl_pdf_service.dart';
import '../../data/services/fl_share_service.dart';
import '../../../family_utilize/presentation/providers/family_utilize_providers.dart';
import '../../domain/entities/fl_dashboard_summary.dart';
import '../../domain/entities/fl_reports_totals.dart';
import '../../domain/entities/fl_transaction.dart';
import '../../domain/repositories/fl_transaction_repository.dart';
import '../../domain/usecases/fl_transaction_usecases.dart';
import 'fl_contact_providers.dart';

// ─── Infrastructure Providers ──────────────────────────────────────────────

final flTransactionDataSourceProvider = Provider<FLTransactionDataSource>(
  (ref) => AppStorageConfig.isHive
      ? const FLTransactionHiveDataSource()
      : FLTransactionSqliteDataSource(
          DatabaseHelper(AppDatabase.instance),
        ),
);

final flTransactionRepositoryProvider = Provider<FLTransactionRepository>(
  (ref) => FLTransactionRepositoryImpl(
    ref.watch(flTransactionDataSourceProvider),
  ),
);

final flPdfServiceProvider = Provider<FLPdfService>(
  (_) => const FLPdfService(),
);

final flShareServiceProvider = Provider<FLShareService>(
  (_) => const FLShareService(),
);

// ─── Usecase Providers ─────────────────────────────────────────────────────

final addFLTransactionUsecaseProvider = Provider<AddFLTransactionUsecase>(
  (ref) => AddFLTransactionUsecase(ref.watch(flTransactionRepositoryProvider)),
);

final getFLTransactionsByContactUsecaseProvider =
    Provider<GetFLTransactionsByContactUsecase>(
  (ref) => GetFLTransactionsByContactUsecase(
    ref.watch(flTransactionRepositoryProvider),
  ),
);

final getAllFLTransactionsUsecaseProvider =
    Provider<GetAllFLTransactionsUsecase>(
  (ref) => GetAllFLTransactionsUsecase(
    ref.watch(flTransactionRepositoryProvider),
  ),
);

final deleteFLTransactionUsecaseProvider = Provider<DeleteFLTransactionUsecase>(
  (ref) =>
      DeleteFLTransactionUsecase(ref.watch(flTransactionRepositoryProvider)),
);

// ─── Transaction History Provider (per-contact) ────────────────────────────

final flTransactionHistoryProvider =
    FutureProvider.family<List<FLTransaction>, String>((ref, contactId) async {
  final usecase = ref.watch(getFLTransactionsByContactUsecaseProvider);
  final result = await usecase(contactId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (txns) => txns,
  );
});

// ─── Dashboard Summary Provider ────────────────────────────────────────────

final flDashboardSummaryProvider =
    FutureProvider<FLDashboardSummary>((ref) async {
  final repo = ref.watch(flTransactionRepositoryProvider);
  final familyRepo = ref.watch(familyUtilizeRepositoryProvider);

  // Efficient aggregate query instead of fetching all rows
  final totalsResult = await repo.getGlobalTotals();
  final totals = totalsResult.getOrElse((_) => FLContactTotals.zero());

  // Total Family Utilized
  final familyTotalResult = await familyRepo.getTotalFamilyUtilized();
  final familyTotal = familyTotalResult.getOrElse((_) => 0.0);

  // Recent activity — newest 20 across all contacts
  final allResult = await repo.getAll();
  final recent = allResult
      .getOrElse((_) => <FLTransaction>[])
      .take(20)
      .map((txn) => FLRecentActivity(
            transaction: txn,
            contactName: txn.contactId, // resolved to name in the UI layer
          ))
      .toList();

  return FLDashboardSummary(
    totalReceived: totals.totalReceived,
    totalUtilized: totals.totalUtilized,
    totalReturned: totals.totalReturned,
    totalFamilyUtilized: familyTotal,
    recentTransactions: recent,
  );
});

// ─── Reports Providers ──────────────────────────────────────────────────────

/// Filter state for Fund Ledger reports.
class FLReportsFilter {
  const FLReportsFilter({
    this.type,
    this.contactId,
    this.from,
    this.to,
    this.searchQuery = '',
  });

  final FLTransactionType? type;
  final String? contactId;
  final DateTime? from;
  final DateTime? to;
  final String searchQuery;

  FLReportsFilter copyWith({
    FLTransactionType? type,
    bool clearType = false,
    String? contactId,
    bool clearContactId = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    String? searchQuery,
  }) {
    return FLReportsFilter(
      type: clearType ? null : type ?? this.type,
      contactId: clearContactId ? null : contactId ?? this.contactId,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final flReportsFilterProvider =
    StateProvider<FLReportsFilter>((ref) => const FLReportsFilter());

final flReportsListProvider = FutureProvider<List<FLTransaction>>((ref) async {
  final filter = ref.watch(flReportsFilterProvider);
  final usecase = ref.watch(getAllFLTransactionsUsecaseProvider);
  final result = await usecase(
    type: filter.type,
    contactId: filter.contactId,
    from: filter.from,
    to: filter.to,
  );
  final all = result.getOrElse((_) => <FLTransaction>[]);

  if (filter.searchQuery.trim().isEmpty) return all;
  final q = filter.searchQuery.trim().toLowerCase();
  return all.where((txn) {
    return (txn.title?.toLowerCase().contains(q) ?? false) ||
        (txn.note?.toLowerCase().contains(q) ?? false) ||
        (txn.description?.toLowerCase().contains(q) ?? false) ||
        txn.amount.toString().contains(q) ||
        txn.txnDate.contains(q);
  }).toList();
});

/// Report totals intentionally ignore the type filter so summary cards remain
/// stable while the transaction list is filtered by type.
/// Total Utilized = Family Utilize + Contact Utilize
/// Net Available = Total Received - Total Returned - Total Utilized
final flReportsTotalsProvider = FutureProvider<FLReportsTotals>((ref) async {
  final filter = ref.watch(flReportsFilterProvider);
  final usecase = ref.watch(getAllFLTransactionsUsecaseProvider);
  final result = await usecase(
    contactId: filter.contactId,
    from: filter.from,
    to: filter.to,
  );
  final transactions = result.getOrElse((_) => <FLTransaction>[]);
  var totalReceived = 0.0;
  var totalContactUtilized = 0.0;
  var totalReturned = 0.0;

  for (final transaction in transactions) {
    switch (transaction.type) {
      case FLTransactionType.received:
        totalReceived += transaction.amount;
      case FLTransactionType.utilized:
        totalContactUtilized += transaction.amount;
      case FLTransactionType.returned:
        totalReturned += transaction.amount;
    }
  }

  var totalFamilyUtilized = 0.0;
  if (filter.contactId == null) {
    final familyRepo = ref.watch(familyUtilizeRepositoryProvider);
    final familyResult = await familyRepo.getTotalFamilyUtilized(
      from: filter.from,
      to: filter.to,
    );
    totalFamilyUtilized = familyResult.getOrElse((_) => 0.0);
  }

  return FLReportsTotals(
    totalReceived: totalReceived,
    totalContactUtilized: totalContactUtilized,
    totalFamilyUtilized: totalFamilyUtilized,
    totalReturned: totalReturned,
  );
});

// ─── Transaction Form Notifier ──────────────────────────────────────────────

class FLTransactionFormNotifier extends StateNotifier<AsyncValue<void>> {
  FLTransactionFormNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> add({
    required String contactId,
    required FLTransactionType type,
    required double amount,
    required String txnDate,
    String? txnTime,
    String? paymentMode,
    String? paymentReference,
    String? title,
    String? description,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(addFLTransactionUsecaseProvider);

    final txn = FLTransaction(
      id: const Uuid().v4(),
      contactId: contactId,
      type: type,
      amount: amount,
      txnDate: txnDate,
      txnTime: txnTime,
      paymentMode: paymentMode,
      paymentReference: paymentReference,
      title: title,
      description: description,
      note: note,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await usecase(txn);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(flTransactionHistoryProvider(contactId));
        _ref.invalidate(flContactSummaryProvider(contactId));
        _ref.invalidate(flDashboardSummaryProvider);
        _ref.invalidate(flReportsListProvider);
        _ref.invalidate(flReportsTotalsProvider);
        return true;
      },
    );
  }

  Future<bool> delete(String txnId, String contactId) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(deleteFLTransactionUsecaseProvider);
    final result = await usecase(txnId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(flTransactionHistoryProvider(contactId));
        _ref.invalidate(flContactSummaryProvider(contactId));
        _ref.invalidate(flDashboardSummaryProvider);
        _ref.invalidate(flReportsListProvider);
        _ref.invalidate(flReportsTotalsProvider);
        return true;
      },
    );
  }

  Future<bool> update(FLTransaction transaction) async {
    state = const AsyncValue.loading();
    final result =
        await _ref.read(flTransactionRepositoryProvider).update(transaction);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(flTransactionHistoryProvider(transaction.contactId));
        _ref.invalidate(flContactSummaryProvider(transaction.contactId));
        _ref.invalidate(flDashboardSummaryProvider);
        _ref.invalidate(flReportsListProvider);
        _ref.invalidate(flReportsTotalsProvider);
        return true;
      },
    );
  }
}

final flTransactionFormNotifierProvider =
    StateNotifierProvider<FLTransactionFormNotifier, AsyncValue<void>>(
  (ref) => FLTransactionFormNotifier(ref),
);
