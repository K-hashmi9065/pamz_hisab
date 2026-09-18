# PAMZ Hisab — Testing Document

**Scope:** Unit Tests, Widget Tests, Integration Tests
**Tooling:** `flutter_test`, `mocktail`, `integration_test`, `riverpod` test utilities

---

## 1. Testing Philosophy

- Test the **domain layer** (usecases, entities, formatters) exhaustively — pure Dart, no mocking framework overhead beyond mocking repository interfaces.
- Test **repositories** against mocked datasources (`Sqflite`/`Hive` mocked, never a real DB in unit tests).
- Test **widgets** in isolation with fake/overridden Riverpod providers — never a real DB or platform channel.
- Test **critical user flows end-to-end** via `integration_test`, against a real (in-memory or temp-file) SQLite instance — this is the only layer allowed to touch real storage.
- **Every bug fix ships with a regression test.** No PR merges business logic without a corresponding test per global rules (never "just make it work").
- Use **`mocktail`** exclusively for mocking (no `mockito` code-gen) — simpler, no build_runner dependency for test mocks.

## 2. Test Pyramid & Coverage Targets

| Layer | Target Coverage | Why |
|---|---|---|
| Domain (entities, usecases, formatters, `ErrorMapper`) | ≥ 90% | Pure logic, cheapest to test, highest ROI |
| Data (repositories) | ≥ 80% | Business rules like duplicate-phone, balance recompute live here |
| Presentation (Riverpod notifiers, widgets) | ≥ 70% | UI logic and state transitions |
| Integration (critical flows) | 100% of "Critical Flows" list (§6) | End-to-end confidence, not exhaustive |

## 3. Project Test Structure

```
test/
 ├── core/
 │    ├── utils/
 │    │    ├── currency_formatter_test.dart
 │    │    └── phone_validator_test.dart
 │    └── error/
 │         └── error_mapper_test.dart
 ├── feature/
 │    ├── contacts/
 │    │    ├── data/
 │    │    │    └── contact_repository_impl_test.dart
 │    │    ├── domain/
 │    │    │    └── usecases/
 │    │    │         ├── create_contact_usecase_test.dart
 │    │    │         └── enforce_unique_phone_usecase_test.dart
 │    │    └── presentation/
 │    │         ├── providers/contact_list_notifier_test.dart
 │    │         └── widgets/contact_list_tile_test.dart
 │    ├── direct_udhar/
 │    │    ├── data/direct_udhar_repository_impl_test.dart
 │    │    ├── domain/usecases/
 │    │    │    ├── create_direct_loan_usecase_test.dart
 │    │    │    └── log_repayment_usecase_test.dart
 │    │    └── presentation/screens/direct_udhar_form_screen_test.dart
 │    ├── family_finance/ ...
 │    ├── categories_config/ ...
 │    ├── notifications/ ...
 │    └── analytics_reports/ ...
 └── test_helpers/
      ├── fixtures.dart              # sample entities (Contact, DirectUdharLoan, ...)
      ├── mocks.dart                 # mocktail Mock classes + registerFallbackValue setup
      └── pump_app.dart              # helper to pump widgets wrapped in ProviderScope + MaterialApp

integration_test/
 ├── app_test.dart
 ├── flows/
 │    ├── direct_udhar_full_flow_test.dart
 │    ├── buyer_ledger_repayment_flow_test.dart
 │    ├── family_budget_alert_flow_test.dart
 │    └── biometric_lock_flow_test.dart
 └── test_helpers/
      └── db_test_utils.dart         # in-memory sqflite ffi setup for integration tests
```

## 4. Unit Tests (mocktail)

### 4.1 Setup Conventions

`test_helpers/mocks.dart`:

```dart
import 'package:mocktail/mocktail.dart';
import 'package:pamz_hisab/feature/contacts/domain/repositories/contact_repository.dart';
import 'package:pamz_hisab/feature/direct_udhar/domain/repositories/direct_udhar_repository.dart';
import 'package:pamz_hisab/core/security/biometric_service.dart';

class MockContactRepository extends Mock implements ContactRepository {}
class MockDirectUdharRepository extends Mock implements DirectUdharRepository {}
class MockBiometricService extends Mock implements BiometricService {}

/// Register fallback values once, in a `setUpAll`, for any custom type
/// used as an argument matcher (`any()`) in verify()/when() calls.
void registerFallbacks() {
  registerFallbackValue(FakeContact());
  registerFallbackValue(FakeDirectUdharLoan());
}

class FakeContact extends Fake implements Contact {}
class FakeDirectUdharLoan extends Fake implements DirectUdharLoan {}
```

### 4.2 Usecase Test — Duplicate Phone Enforcement (FR-UK-001)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_hisab/core/error/failure.dart';
import 'package:pamz_hisab/feature/contacts/domain/usecases/create_contact_usecase.dart';
import '../../../test_helpers/mocks.dart';
import '../../../test_helpers/fixtures.dart';

void main() {
  late MockContactRepository repository;
  late CreateContactUsecase usecase;

  setUpAll(registerFallbacks);

  setUp(() {
    repository = MockContactRepository();
    usecase = CreateContactUsecase(repository);
  });

  group('CreateContactUsecase', () {
    test('returns DuplicatePhoneFailure when mobile number already exists', () async {
      // Arrange
      when(() => repository.existsByMobile('9876543210'))
          .thenAnswer((_) async => true);

      // Act
      final result = await usecase(buyerFixture.copyWith(mobileNumber: '9876543210'));

      // Assert
      expect(result.isLeft(), true);
      result.match(
        (failure) => expect(failure, isA<DuplicatePhoneFailure>()),
        (_) => fail('expected failure'),
      );
      verify(() => repository.existsByMobile('9876543210')).called(1);
      verifyNever(() => repository.create(any()));
    });

    test('creates contact and returns entity when mobile number is unique', () async {
      when(() => repository.existsByMobile(any())).thenAnswer((_) async => false);
      when(() => repository.create(any())).thenAnswer((_) async => buyerFixture);

      final result = await usecase(buyerFixture);

      expect(result.isRight(), true);
      verify(() => repository.create(any())).called(1);
    });

    test('rejects invalid 10-digit Indian mobile format before hitting repository', () async {
      final result = await usecase(buyerFixture.copyWith(mobileNumber: '12345'));

      expect(result.isLeft(), true);
      result.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('expected failure'),
      );
      verifyNever(() => repository.existsByMobile(any()));
    });
  });
}
```

### 4.3 Usecase Test — Repayment Recomputes Outstanding Balance (FR-DU-003)

```dart
void main() {
  late MockDirectUdharRepository repository;
  late LogRepaymentUsecase usecase;

  setUpAll(registerFallbacks);
  setUp(() {
    repository = MockDirectUdharRepository();
    usecase = LogRepaymentUsecase(repository);
  });

  test('partial repayment reduces outstanding balance and sets status to partially_paid', () async {
    final loan = directUdharLoanFixture.copyWith(
      principalAmount: 10000,
      outstandingBalance: 10000,
      status: LoanStatus.open,
    );
    when(() => repository.findById(loan.id)).thenAnswer((_) async => loan);
    when(() => repository.recordRepayment(any(), any()))
        .thenAnswer((invocation) async {});

    final result = await usecase(loanId: loan.id, amount: 4000, mode: 'cash');

    expect(result.isRight(), true);
    final captured = verify(() => repository.recordRepayment(loan.id, captureAny()))
        .captured
        .single as Repayment;
    expect(captured.amount, 4000);
  });

  test('full repayment sets status to closed', () async {
    final loan = directUdharLoanFixture.copyWith(outstandingBalance: 500, status: LoanStatus.open);
    when(() => repository.findById(loan.id)).thenAnswer((_) async => loan);
    when(() => repository.recordRepayment(any(), any())).thenAnswer((_) async {});
    when(() => repository.updateStatus(loan.id, LoanStatus.closed))
        .thenAnswer((_) async {});

    await usecase(loanId: loan.id, amount: 500, mode: 'cash');

    verify(() => repository.updateStatus(loan.id, LoanStatus.closed)).called(1);
  });

  test('rejects repayment amount greater than outstanding balance', () async {
    final loan = directUdharLoanFixture.copyWith(outstandingBalance: 300);
    when(() => repository.findById(loan.id)).thenAnswer((_) async => loan);

    final result = await usecase(loanId: loan.id, amount: 500, mode: 'cash');

    expect(result.isLeft(), true);
    verifyNever(() => repository.recordRepayment(any(), any()));
  });
}
```

### 4.4 Pure Function Tests — Currency Formatter (₹ / Lakhs-Crores)

```dart
void main() {
  group('CurrencyFormatter.formatIndian', () {
    test('formats below 1 lakh with standard grouping', () {
      expect(CurrencyFormatter.formatIndian(45000), '₹45,000');
    });
    test('formats 1 lakh+ using Lakhs grouping', () {
      expect(CurrencyFormatter.formatIndian(150000), '₹1,50,000');
    });
    test('formats 1 crore+ using Crores grouping', () {
      expect(CurrencyFormatter.formatIndian(12500000), '₹1,25,00,000');
    });
    test('formats negative amounts with a leading minus', () {
      expect(CurrencyFormatter.formatIndian(-2000), '-₹2,000');
    });
  });

  group('PhoneValidator.isValidIndianMobile', () {
    test('accepts valid 10-digit number starting with 6-9', () {
      expect(PhoneValidator.isValidIndianMobile('9876543210'), true);
    });
    test('rejects number with fewer than 10 digits', () {
      expect(PhoneValidator.isValidIndianMobile('98765'), false);
    });
    test('rejects number starting with 0-5', () {
      expect(PhoneValidator.isValidIndianMobile('4876543210'), false);
    });
  });
}
```

### 4.5 `ErrorMapper` Test — Never Leak Raw Exceptions

```dart
void main() {
  test('maps DatabaseException to DatabaseFailure with friendly message', () {
    final failure = ErrorMapper.map(DatabaseException('UNIQUE constraint failed'));
    expect(failure, isA<DatabaseFailure>());
    expect(failure.message, isNot(contains('UNIQUE constraint')));
  });

  test('maps unknown exception to UnknownFailure without exposing stack trace text', () {
    final failure = ErrorMapper.map(Exception('some internal detail'));
    expect(failure, isA<UnknownFailure>());
    expect(failure.message, 'Something went wrong. Please try again.');
  });
}
```

## 5. Widget Tests

### 5.1 Helper — `pump_app.dart`

```dart
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}
```

### 5.2 `AppTextField` — Validation State

```dart
void main() {
  testWidgets('shows error text when validator fails', (tester) async {
    await pumpApp(
      tester,
      AppTextField(
        label: 'Mobile Number',
        validator: (v) => PhoneValidator.isValidIndianMobile(v ?? '')
            ? null
            : 'Enter a valid 10-digit mobile number',
      ),
    );

    await tester.enterText(find.byType(AppTextField), '123');
    await tester.pump();
    // trigger form validation via a wrapping Form + submit, or call validate() directly
    final formFieldState = tester.state<FormFieldState>(find.byType(TextFormField));
    formFieldState.validate();
    await tester.pump();

    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
  });
}
```

### 5.3 `LedgerListTile` — Credit/Debit Color Semantics

```dart
void main() {
  testWidgets('renders credit amount in credit color with + prefix', (tester) async {
    await pumpApp(
      tester,
      LedgerListTile(
        name: 'Ramesh Kumar',
        amount: 2400,
        isCredit: true,
        dueDate: null,
      ),
    );

    expect(find.text('+₹2,400'), findsOneWidget);
    final badge = tester.widget<AmountBadge>(find.byType(AmountBadge));
    expect(badge.color, AppColors.credit);
  });

  testWidgets('shows overdue chip when dueDate is in the past', (tester) async {
    await pumpApp(
      tester,
      LedgerListTile(
        name: 'Suresh Yadav',
        amount: -800,
        isCredit: false,
        dueDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
    );

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
```

### 5.4 Screen Widget Test with Mocked Riverpod Provider

```dart
void main() {
  testWidgets('ContactListScreen shows AppEmptyState when no contacts exist', (tester) async {
    await pumpApp(
      tester,
      const ContactListScreen(),
      overrides: [
        contactListProvider.overrideWith(
          (ref) => Stream.value(<Contact>[]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('No contacts yet'), findsOneWidget);
  });

  testWidgets('ContactListScreen shows AppErrorView on repository failure', (tester) async {
    await pumpApp(
      tester,
      const ContactListScreen(),
      overrides: [
        contactListProvider.overrideWith(
          (ref) => Stream<List<Contact>>.error(DatabaseFailure('db locked')),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text('db locked'), findsNothing); // raw message never shown
  });
}
```

### 5.5 Form Submission with Mocked Usecase via Provider Override

```dart
void main() {
  late MockDirectUdharRepository repository;

  setUpAll(registerFallbacks);
  setUp(() => repository = MockDirectUdharRepository());

  testWidgets('submitting DirectUdharFormScreen calls create usecase with entered values', (tester) async {
    when(() => repository.create(any())).thenAnswer((_) async => directUdharLoanFixture);

    await pumpApp(
      tester,
      const DirectUdharFormScreen(),
      overrides: [directUdharRepositoryProvider.overrideWithValue(repository)],
    );

    await tester.enterText(find.byKey(const Key('amountField')), '5000');
    await tester.tap(find.byKey(const Key('interestFreeRadio')));
    await tester.tap(find.byType(AppButton).last); // submit
    await tester.pumpAndSettle();

    verify(() => repository.create(any(that: predicate<DirectUdharLoan>(
          (loan) => loan.principalAmount == 5000 && loan.interestType == InterestType.interestFree,
        )))).called(1);
  });
}
```

## 6. Integration Tests (`integration_test`)

Run against a **real SQLite instance** (via `sqflite_common_ffi` in-memory DB for speed, or a temp file to also validate migrations) — this is the only test tier permitted to touch actual storage. Platform-only features (`local_auth`, `share_plus`, camera) are mocked via method-channel handlers since simulators/CI can't provide real biometrics/WhatsApp.

### 6.1 Critical Flows Checklist (must reach 100% coverage)

| # | Flow | Assertion |
|---|---|---|
| 1 | Create buyer → attempt duplicate mobile → rejected | `DuplicatePhoneFailure` surfaced in UI, contact count unchanged |
| 2 | Log direct cash Udhar → generate PDF → share sheet invoked | PDF file exists at temp path; `share_plus` mock invoked with correct path |
| 3 | Log full repayment → loan status becomes `closed` → dashboard balance updates | Dashboard "Total Receivable" reflects new total |
| 4 | Log family expense with receipt photo → budget threshold exceeded | Budget alert banner appears; category progress bar reflects new spend |
| 5 | Biometric lock: app backgrounded past timeout → resumed → lock screen shown | `AuthLockGuard` redirects to `/lock`; passcode fallback path also verified |
| 6 | 10-year historical query via custom date range → export `.xlsx`/PDF | Exported file generated; row count matches seeded dataset for range |
| 7 | Offline cold start with pre-seeded 10-yr dataset | App launches and dashboard renders within acceptable time budget (perf smoke test) |
| 8 | Delete (soft-delete) a contact with existing ledger history | Contact hidden from active list; historical ledger entries still queryable via audit/history view |

### 6.2 Example — Full Direct Udhar Flow

```dart
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_hisab/main.dart' as app;
import '../test_helpers/db_test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => setUpInMemoryDatabase());
  tearDown(() async => tearDownTestDatabase());

  testWidgets('end-to-end: create buyer, log Udhar, repay, verify dashboard', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 1. Create buyer
    await tester.tap(find.byKey(const Key('newContactFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Ramesh Kumar');
    await tester.enterText(find.byKey(const Key('mobileField')), '9876543210');
    await tester.tap(find.byKey(const Key('saveContactButton')));
    await tester.pumpAndSettle();

    expect(find.text('Ramesh Kumar'), findsOneWidget);

    // 2. Log Udhar (lending)
    await tester.tap(find.text('Ramesh Kumar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logUdharButton')));
    await tester.enterText(find.byKey(const Key('amountField')), '2000');
    await tester.tap(find.byKey(const Key('saveUdharButton')));
    await tester.pumpAndSettle();

    expect(find.text('₹2,000'), findsWidgets);

    // 3. Log full repayment
    await tester.tap(find.byKey(const Key('logRepaymentButton')));
    await tester.enterText(find.byKey(const Key('repaymentAmountField')), '2000');
    await tester.tap(find.byKey(const Key('saveRepaymentButton')));
    await tester.pumpAndSettle();

    expect(find.text('Closed'), findsOneWidget);

    // 4. Verify dashboard reflects zero outstanding for this contact
    await tester.tap(find.byKey(const Key('dashboardNavItem')));
    await tester.pumpAndSettle();
    expect(find.text('₹0'), findsWidgets);
  });
}
```

### 6.3 `db_test_utils.dart` — In-Memory SQLite for Tests

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> setUpInMemoryDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  // point AppDatabase at inMemoryDatabasePath for the duration of the test
}

Future<void> tearDownTestDatabase() async {
  // close + delete any temp db files created for migration-dry-run tests
}
```

## 7. Edge Case & Failure Case Matrix

| Scenario | Layer | Expected Behavior |
|---|---|---|
| Duplicate mobile number on contact create | Unit + Integration | `DuplicatePhoneFailure`, no partial write |
| Repayment amount > outstanding balance | Unit | `ValidationFailure`, repository never called |
| Repayment amount = exactly outstanding balance | Unit | Status transitions to `closed` |
| SQLite write fails mid-transaction (simulated) | Unit (mocked datasource throwing) | Transaction rolls back, `DatabaseFailure` surfaced, no partial `audit_log`/`monthly_summary` row |
| PDF generation fails (e.g. disk full, simulated) | Unit | `PdfGenerationFailure`, share sheet never invoked |
| WhatsApp not installed → share sheet has no WhatsApp target | Integration (mocked channel) | Falls back gracefully to system share sheet (Files/AirDrop/SMS) — app doesn't crash |
| Biometric hardware unavailable / user cancels | Unit + Integration | Falls back to passcode entry, never silently unlocks |
| Category deleted while transactions reference it | Unit | Soft-delete only; historical `family_transactions.category_id` still resolvable for reports |
| App force-quit mid-write | Integration (simulated) | On relaunch, no orphaned/partial rows — SQLite transaction guarantees atomicity |
| 10-year dataset dashboard load | Integration (perf) | Uses `monthly_summary`, not full scan — assert query plan/timing within budget |

## 8. CI Gate

- `flutter test --coverage` (unit + widget) must pass with coverage thresholds from §2 before merge.
- `flutter test integration_test` runs on a simulator matrix (iPad mini, iPad Pro 12.9") as part of the release pipeline (per TRD §11) before signing/export of each `.ipa`.
- No PR merges with reduced coverage on `domain/` or `data/` layers without an explicit, reviewed justification.
