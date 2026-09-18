import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';
import '../../../contacts/presentation/providers/contact_providers.dart';
import '../../data/repositories/direct_udhar_hive_repository_impl.dart';
import '../../data/repositories/direct_udhar_repository_impl.dart';
import '../../data/services/direct_udhar_pdf_service.dart';
import '../../data/services/direct_udhar_share_service.dart';
import '../../domain/entities/direct_udhar_loan.dart';
import '../../domain/repositories/direct_udhar_repository.dart';
import '../../domain/usecases/direct_udhar_usecases.dart';

final directUdharPdfServiceProvider = Provider<DirectUdharPdfService>(
  (ref) => const DirectUdharPdfService(),
);

final directUdharShareServiceProvider = Provider<DirectUdharShareService>(
  (ref) => const DirectUdharShareService(),
);

final directUdharDatabaseHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper(AppDatabase.instance),
);

final directUdharRepositoryProvider = Provider<DirectUdharRepository>(
  (ref) => AppStorageConfig.isHive
      ? const DirectUdharHiveRepositoryImpl()
      : DirectUdharRepositoryImpl(
          ref.watch(directUdharDatabaseHelperProvider),
        ),
);

final createDirectLoanUsecaseProvider = Provider<CreateDirectLoanUsecase>(
  (ref) => CreateDirectLoanUsecase(
    ref.watch(directUdharRepositoryProvider),
  ),
);

final logRepaymentUsecaseProvider = Provider<LogRepaymentUsecase>(
  (ref) => LogRepaymentUsecase(
    ref.watch(directUdharRepositoryProvider),
  ),
);

final loansByContactProvider =
    FutureProvider.family<List<DirectUdharLoan>, String>((ref, contactId) async {
  final repo = ref.watch(directUdharRepositoryProvider);
  final result = await repo.getByContact(contactId);
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final repaymentsByLoanProvider =
    FutureProvider.family<List<Repayment>, String>((ref, loanId) async {
  final repo = ref.watch(directUdharRepositoryProvider);
  final result = await repo.getRepayments(loanId);
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

class DirectUdharFormNotifier extends StateNotifier<AsyncValue<void>> {
  DirectUdharFormNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> createLoan(DirectUdharLoan loan) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(createDirectLoanUsecaseProvider);
    final result = await usecase(loan);
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
        _ref.invalidate(contactTotalBalanceProvider(loan.contactId));
        _ref.invalidate(loansByContactProvider(loan.contactId));
        return true;
      },
    );
  }

  Future<bool> recordRepayment({
    required String loanId,
    required String contactId,
    required double amount,
    required String mode,
    DateTime? paidAt,
    String? memo,
  }) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(logRepaymentUsecaseProvider);
    final result = await usecase(
      loanId: loanId,
      amount: amount,
      mode: mode,
      paidAt: paidAt,
      memo: memo,
    );
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
        _ref.invalidate(contactTotalBalanceProvider(contactId));
        _ref.invalidate(loansByContactProvider(contactId));
        _ref.invalidate(repaymentsByLoanProvider(loanId));
        return true;
      },
    );
  }
}

final directUdharFormNotifierProvider =
    StateNotifierProvider<DirectUdharFormNotifier, AsyncValue<void>>(
  (ref) => DirectUdharFormNotifier(ref),
);
