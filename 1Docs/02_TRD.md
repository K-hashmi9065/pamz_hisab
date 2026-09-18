# PAMZ Hisab — Technical Requirements Document (TRD)

**Platform:** Flutter (iPad target, iPadOS via native build)
**Version:** 1.1

---

## 1. Technology Stack

| Layer | Choice | Rationale |
|---|---|---|
| Framework | Flutter (latest stable) | Single codebase, native iPad performance via Skia/Impeller |
| Language | Dart (null-safe, latest stable) | — |
| State Management | **Riverpod** (`flutter_riverpod`, `riverpod_generator`) | Compile-safe DI, testable, no `setState` |
| Navigation | **GoRouter** | Declarative routing, deep-link/shell-route support for iPad split view |
| Local Relational DB | **SQLite** via `sqflite` (or `drift` on top of sqflite) | Structured ledger/transaction data with relations, indexing, complex queries (10-yr reporting) |
| Local KV/Object Store | **Hive** (`hive`, `hive_flutter`) | Fast key-value store for app settings, config, category presets, last-sync flags, drafts |
| Fonts | **google_fonts** | Consistent typography without bundling font files manually |
| Responsive Sizing | **flutter_screenutil** | iPad-appropriate scaling across split-view/multitasking sizes |
| Models | `freezed` + `json_serializable` | Immutable models, union types (e.g. `TransactionType`), generated `(de)serialization` |
| Equality | `equatable` (or rely on freezed's built-in) | Value equality for state comparisons |
| PDF Generation | `pdf` + `printing` | Generate Udhar receipts / statements, print/share/export |
| WhatsApp/Share | `share_plus` | System share sheet → WhatsApp, Files, AirDrop, etc. |
| SMS | `url_launcher` (`sms:` scheme) | iOS restricts programmatic SMS sending; use the native compose sheet |
| Biometric Auth | `local_auth` | Face ID / Touch ID app lock |
| Secure Storage | `flutter_secure_storage` (Keychain-backed) | Store DB encryption key / biometric lock flag |
| DB Encryption | `sqlcipher_flutter_libs` + `sqflite_sqlcipher` | Encrypt SQLite at rest (financial data) |
| Excel Export | `excel` (or `syncfusion_flutter_xlsio` if licensed) | `.xlsx` export for custom-range reports |
| Camera/Receipts | `image_picker` / `camera` | Receipt photo capture for expenses |
| Testing | `flutter_test`, `mocktail`, `integration_test` | Unit / widget / integration coverage |
| Localization | `flutter_localizations` + `intl` (or `easy_localization`) | Hindi / Hinglish / English strings |

> **Why both Hive and SQLite:** Hive is used for lightweight, schema-flexible app state (settings, category configs, drafts, UI preferences). SQLite (via sqflite/drift, SQLCipher-encrypted) is the **system of record** for all financial transactions — it needs relational integrity, indexed range queries, and aggregate reporting across 10 years of data, which a pure KV store cannot do efficiently.

## 2. Architecture

**Pattern:** Clean Architecture + MVVM, Feature-First folder structure, Repository Pattern.

```
lib/
 ├── core/
 │    ├── constants/            # app-wide constants (non-hardcoded UI strings live in l10n)
 │    ├── theme/                # AppTheme, AppColors, AppTextStyles (google_fonts based)
 │    ├── extensions/           # context/num/date extensions
 │    ├── error/                # Failure, Result<T>, ErrorMapper
 │    ├── network/               # (n/a for v1.1 — reserved for future sync)
 │    ├── security/              # BiometricService, EncryptionKeyManager
 │    ├── utils/                 # currency formatter (₹ + Lakhs/Crores), date utils
 │    └── db/
 │         ├── sqlite/           # DB instance, migrations, DAO base classes
 │         └── hive/             # Hive box registrar, adapters
 ├── shared/
 │    ├── widgets/               # AppButton, AppCard, AppTextField, AppDialog,
 │    │                          # AppBottomSheet, AppLoader, AppEmptyState, AppErrorView,
 │    │                          # CustomAppBar, AppSnackbar, ConfirmationDialog,
 │    │                          # SectionHeader, LedgerListTile, AmountBadge
 │    └── models/                # shared value objects (Money, PhoneNumber)
 ├── routes/
 │    └── app_router.dart        # GoRouter config incl. ShellRoute for iPad split-view
 ├── feature/
 │    ├── auth_lock/             # biometric app-lock feature
 │    │    ├── data/  domain/  presentation/
 │    ├── contacts/              # Buyer & Supplier profiles (FR-UK)
 │    ├── direct_udhar/          # Direct cash lending/borrowing (FR-DU)
 │    ├── ledger_repayments/     # Repayment ("Jama") logging shared by udhar modules
 │    ├── family_finance/        # Income & Expense (FR-FE)
 │    ├── categories_config/     # Category Engine & system config (FR-CAT)
 │    ├── notifications/         # WhatsApp/SMS dispatch + templates (FR-NT)
 │    ├── analytics_reports/     # Category analytics, 10-yr reporting, exports (FR-AN)
 │    └── settings/              # App settings, backup/export, currency/fiscal-year config
 └── main.dart
```

Each `feature/<x>/` follows:
```
<feature>/
 ├── data/
 │    ├── datasources/     # SqliteDataSource, HiveDataSource
 │    ├── models/          # DTOs (freezed + json_serializable)
 │    └── repositories/    # Impl of domain repository interfaces
 ├── domain/
 │    ├── entities/        # Pure Dart entities
 │    ├── repositories/    # Abstract repository interfaces
 │    └── usecases/        # Single-responsibility use cases
 └── presentation/
      ├── providers/       # Riverpod providers/notifiers (AsyncNotifier/StateNotifier)
      ├── screens/
      └── widgets/
```

## 3. State Management (Riverpod)

- Use **`AsyncNotifier`/`NotifierProvider`** (Riverpod 2.x generator syntax) per feature for CRUD + list state.
- Use **`Provider`** for pure derived/computed values (e.g. `totalOutstandingBalanceProvider`).
- Use **`FutureProvider.family`** for parameterized detail fetches (e.g. `contactLedgerProvider(contactId)`).
- No `setState` in feature widgets; local ephemeral UI state (e.g. form field focus) may use `StatefulWidget` only inside `shared/widgets` leaf components.
- All Riverpod providers are unit-testable via `ProviderContainer` overrides — required for `usecases` coverage.

## 4. Navigation (GoRouter) — iPad Split-View Shell

```dart
final goRouter = GoRouter(
  initialLocation: '/lock',
  routes: [
    GoRoute(path: '/lock', builder: (_, __) => const AppLockScreen()),
    ShellRoute(
      builder: (context, state, child) => AdaptiveShell(child: child), // NavigationRail on iPad
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(
          path: '/udhar',
          builder: (_, __) => const UdharListScreen(),
          routes: [
            GoRoute(path: 'contact/:id', builder: (_, s) => ContactLedgerScreen(id: s.pathParameters['id']!)),
            GoRoute(path: 'direct/new', builder: (_, __) => const DirectUdharFormScreen()),
          ],
        ),
        GoRoute(path: '/family', builder: (_, __) => const FamilyFinanceScreen()),
        GoRoute(path: '/reports', builder: (_, __) => const AnalyticsScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
  redirect: (context, state) => AuthLockGuard.redirect(context, state), // biometric gate
);
```

`AdaptiveShell` renders a persistent `NavigationRail`/sidebar on iPad regular-width, and can host a master-detail (`Row` of list + detail pane) for ledger screens — see UI/UX doc §3.

## 5. Error Handling

Following global error-handling rules:

- **`Failure`** sealed class (freezed union): `DatabaseFailure`, `ValidationFailure`, `DuplicatePhoneFailure`, `BiometricFailure`, `PdfGenerationFailure`, `ShareDispatchFailure`, `UnknownFailure`.
- **`Result<T>`** (`Either<Failure, T>`-style, via `fpdart` or a custom sealed type) returned from all repository/usecase calls — never throw across layers.
- **`ErrorMapper`**: maps `DatabaseException` (sqflite), `HiveError`, `PlatformException` (local_auth/camera), and generic exceptions → `Failure` with a user-friendly, localized message. Technical detail is logged (see §9) but never shown raw to the user.
- UI layer: `AsyncValue.when(data:, error:, loading:)` renders `AppErrorView` (retry action) on failure — never a raw exception string.

## 6. Data & Performance Strategy (10-Year Local History)

- SQLite schema fully **indexed** on `contact_id`, `transaction_date`, `category_id` (see Backend Schema doc).
- Reporting queries use **date-range partition pruning** via indexed `transaction_date` and pre-aggregated **monthly summary tables**, refreshed incrementally on write (avoids full-table scans across 10 years for dashboard widgets).
- Ledger list screens use **paginated queries** (`LIMIT`/`OFFSET` or keyset pagination) + `ListView.builder`/`ListView.separated` — never load full history into memory.
- Hive boxes are **lazy-opened** (`Hive.openLazyBox`) for config data not needed at cold start.

## 7. Security

- **Biometric app lock** (`local_auth`) gating all routes via `AuthLockGuard` in GoRouter `redirect`.
- **SQLite encryption at rest** via SQLCipher; encryption passphrase generated on first launch and stored in iOS **Keychain** via `flutter_secure_storage` (never in Hive/plaintext).
- Sensitive fields (phone numbers) validated client-side (10-digit Indian mobile regex) before persistence; duplicate-phone constraint enforced at the DB layer (`UNIQUE` index) — see Backend Schema.
- No secrets/API keys hardcoded (n/a for v1.1 — fully offline, no external API keys required beyond none).
- Manual **encrypted local export/backup** (to Files app) so device loss doesn't equal total data loss, despite no cloud sync in scope.

## 8. Notifications Engine (WhatsApp/SMS)

- **WhatsApp:** Generate PDF (via `pdf`/`printing`) → invoke `share_plus` → system share sheet → user picks WhatsApp. (iOS sandboxing prevents silent/headless WhatsApp sending — user confirmation via share sheet is the compliant approach.)
- **SMS:** Build `sms:<number>&body=<template>` URI → `url_launcher` opens native Messages compose screen pre-filled (iOS does not allow silent programmatic SMS send from third-party apps).
- **Templates:** Stored in Hive (`templates` box), keyed by `templateId + locale`, fully CRUD-editable in Settings (FR-NT-003).

## 9. Logging

- Structured local logging (`logger` package) at `debug/info/warning/error` levels, technical stack traces logged separately from user-facing `Failure.message`.
- Logs rotate locally (e.g. last 7 days) — no PII beyond what's already in the ledger; logs are not transmitted anywhere (offline-first).

## 10. Testing Strategy

| Type | Scope | Tooling |
|---|---|---|
| Unit | Usecases, repositories (mocked datasources), formatters (₹/Lakhs-Crores), ErrorMapper | `flutter_test`, `mocktail` |
| Widget | `AppButton`, `AppTextField`, `LedgerListTile`, form validation states | `flutter_test` |
| Integration | End-to-end: create buyer → log Udhar → repayment → PDF generated → dashboard balance updates | `integration_test` |
| Edge Cases | Duplicate phone rejected, offline PDF/share fallback, biometric failure → retry/passcode fallback, 10-yr query performance | — |

## 11. Deployment

- Build signed with **Apple Enterprise Distribution** (or Ad-Hoc) provisioning profile.
- Distributed via **Apple Configurator** / **MDM** direct install — no App Store review pipeline; internal release checklist replaces store review (crash-free session rate, DB migration dry-run on sample 10-yr dataset).
- CI: Flutter build + full test suite gate before signing/export of each release `.ipa`.
