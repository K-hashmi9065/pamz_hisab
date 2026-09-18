# PAMZ Hisab

**PAMZ Hisab** is an offline-first personal and family finance management and Udhar Khata (credit ledger) application built with Flutter. Designed for high reliability and smooth user experience across devices (with optimized layouts for iPad, tablet, and mobile form factors), PAMZ Hisab functions completely offline using local database storage and hardware-level biometric security.

---

## 1. Project Overview

PAMZ Hisab centralizes customer credit tracking, daily household income/expenses, and budgeting without requiring a cloud connection or recurring subscription.

### Core Modules

* **Dashboard**: Financial overview, key statistics, quick-action shortcuts, and recent transaction logs.
* **Udhar Khata**: Comprehensive customer and supplier credit ledger tracking receivables (Lena) and payables (Dena).
* **Buyers / Suppliers**: Categorized contact profiles with complete transaction histories and net balance calculations.
* **Direct Udhar**: Fast one-off credit/debit entry creation and management.
* **Opening Balance**: Initial balance assignment for legacy migration and accounts setup.
* **Family Finance**: Personal and household income and expense management with category tagging and receipt attachment.
* **Budgets**: Monthly category budget allocations with real-time expenditure progress indicators.
* **Analytics & Reports**: Visual charts, financial health metrics, audit trail logs, and exportable ledger statements.
* **Contacts**: Local contact directory management integrated directly with ledger accounts.
* **Notifications / Templates**: Customizable SMS and WhatsApp payment reminder message templates with smart variable placeholders.
* **Biometric Lock**: App-level Face ID / Touch ID gate ensuring financial privacy upon launch and app backgrounding.
* **Settings**: App preferences, payment modes, category management, currency, and data management.
* **User Guide**: Integrated in-app documentation and user manual.

---

## 2. Tech Stack

### Core
* **Flutter SDK**: `^3.5.0` compatible
* **Dart SDK**: `^3.5.0`

### State Management & Dependency Injection
* **flutter_riverpod** (`^2.5.1`) & **riverpod_annotation** (`^2.3.5`) — Declarative, compile-safe state management with code generation.

### Navigation & Routing
* **go_router** (`^14.2.7`) — Declarative URL-based routing with session lock guards and sub-route nesting.

### Local Storage & Database (Offline-First)
* **sqflite** (`^2.3.3+1`) & **sqflite_common_ffi** — High-performance relational SQLite database for transactions, ledgers, and contacts.
* **hive** (`^2.2.3`) & **hive_flutter** (`^1.1.0`) — Lightweight key-value storage for settings, metadata, and cache.

### UI & Responsiveness
* **flutter_screenutil** (`^5.9.3`) — Adaptive screen sizing and responsive UI scaling across screen dimensions.
* **google_fonts** (`^6.2.1`) — Modern typography.
* **cupertino_icons** (`^1.0.8`) — iOS-style iconography.
* Material 3 Design System with light and dark mode themes.

### Security
* **local_auth** (`^2.3.0`) — Biometric authentication (Face ID & Touch ID / Fingerprint).
* **flutter_secure_storage** (`^9.2.2`) — Encrypted key/credential storage backed by iOS Keychain / Android Keystore.

### Reporting & Document Export
* **pdf** (`^3.11.1`) & **printing** (`^5.13.1`) — PDF ledger statement generation and direct thermal/AirPrint printing.
* **excel** (`^4.0.6`) — Spreadsheet export for accounting and reports.
* **share_plus** (`^9.0.0`) — Native file and message sharing across WhatsApp, Mail, AirDrop, and system sharesheet.

### Media & Device Integration
* **image_picker** (`^1.1.2`) — Receipt photo capture and gallery import.
* **path_provider** (`^2.1.4`) & **path** (`^1.9.0`) — File system paths for receipts, exports, and databases.
* **url_launcher** (`^6.3.0`) — SMS and communication launcher for customer reminders.

### Utilities & Functional Programming
* **freezed_annotation** (`^2.4.4`) & **json_annotation** (`^4.9.0`) — Immutable data models and JSON serialization.
* **fpdart** (`^1.1.0`) — Functional programming abstractions (`Either`, `Option`, `Result`).
* **intl** (`^0.20.2`) — Internationalization, date/time formatting, and currency parsing.
* **uuid** (`^4.5.0`) — Unique identifier generation.
* **logger** (`^2.4.0`) — Structured development logging.

---

## 3. Architecture

PAMZ Hisab is built using a **Feature-First Clean Architecture** approach:

* **Presentation Layer**: Contains Flutter UI widgets, screens, and Riverpod Notifiers/Providers. Keeps presentation logic isolated from data persistence.
* **Domain Layer**: Contains pure business logic, entities, value objects, and repository interfaces. Free of Flutter UI and third-party database dependencies.
* **Data Layer**: Implements repository contracts, managing data sources (SQLite DAO, Hive boxes, Secure Storage), local file storage, and data models with model-entity mapping.
* **Repository Pattern**: Mediates data access between domain use cases and underlying storage engines.

---

## 4. Project Structure

```text
lib/
├── app/
├── core/
│   ├── constants/            # App constants, design sizing, asset paths
│   ├── db/                   # SQLite database helpers, Hive initialization, storage configs
│   ├── error/                # Failure classes and exception handlers
│   ├── security/             # Biometric service and encryption key managers
│   ├── theme/                # Light/Dark themes, colors, typography
│   └── utils/                # Date/number formatters, currency helpers
├── feature/
│   ├── analytics_reports/    # Reports, charts, statement generation (Data/Domain/Presentation)
│   ├── auth_lock/            # Biometric lock screen and app lifecycle guard
│   ├── contacts/             # Contact directory, buyer/supplier profiles, customer ledgers
│   ├── dashboard/            # Overview metrics, recent transactions, quick actions
│   ├── direct_udhar/         # One-off credit/debit transaction workflow
│   ├── family_finance/       # Income, expenses, category budgets, receipts
│   ├── notifications/        # WhatsApp/SMS reminder templates and messaging
│   ├── settings/             # App preferences, audit logs, category setup, payment modes
│   └── user_guide/           # In-app user documentation and guide screens
├── routes/
│   ├── adaptive_shell.dart   # Responsive sidebar/navigation shell
│   ├── app_router.dart       # GoRouter configuration & session guards
│   ├── route_names.dart      # Named route constants
│   └── route_paths.dart      # URL path constants
├── shared/
│   └── widgets/              # Reusable UI components, dialogs, buttons, cards
└── main.dart                 # Application entry point & lifecycle observer
```

---

## 5. Requirements

### General Prerequisites
* **Flutter SDK**: `>= 3.5.0`
* **Dart SDK**: `>= 3.5.0`
* **Git**: `>= 2.x`

### For iOS Development (macOS)
* **Operating System**: macOS (latest stable version recommended)
* **Xcode**: Version 15 or later
* **CocoaPods**: Version 1.12 or later
* **Apple Developer Account**: Required for physical device testing and App Store / TestFlight distribution builds.

---

## 6. Initial Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd pamz_khata_ios
   ```

2. **Verify system dependencies:**
   ```bash
   flutter doctor
   ```

3. **Install Flutter packages:**
   ```bash
   flutter pub get
   ```

4. **Install iOS CocoaPods dependencies (macOS only):**
   ```bash
   cd ios
   pod install
   cd ..
   ```

   *If CocoaPods is not installed on macOS, install it using:*
   ```bash
   sudo gem install cocoapods
   ```
   *or via Homebrew:*
   ```bash
   brew install cocoapods
   ```

---

## 7. Run the App

### Web (Development & Quick Testing)
```bash
flutter run -d chrome
```

> **Note on Web Behavior:** For rapid browser testing and UI verification, biometric lock verification is bypassed when running on Web (`kIsWeb`).

### Android
1. Connect an Android device with USB debugging enabled or launch an Android emulator.
2. List available devices:
   ```bash
   flutter devices
   ```
3. Run on the target device:
   ```bash
   flutter run -d <android-device-id>
   ```

---

## 8. Run on iOS Simulator

### Step 1 — Verify Flutter & Xcode Setup
```bash
flutter doctor
```
Ensure that Xcode and CocoaPods are marked with green checkmarks.

### Step 2 — Install iOS Dependencies
From the project root:
```bash
flutter pub get
cd ios
pod install
cd ..
```

### Step 3 — Open the iOS Simulator
Launch the simulator directly via terminal:
```bash
open -a Simulator
```
Or open via Xcode:
`Xcode > Open Developer Tool > Simulator`

### Step 4 — Check Available Devices
```bash
flutter devices
```
Locate your simulator device identifier from the output (e.g., `iPhone 15 Pro`, `iPad Pro 11-inch`).

### Step 5 — Run on Simulator
```bash
flutter run -d <ios-simulator-device-id>
```
*Example:*
```bash
flutter run -d "iPhone 16"
```

### Step 6 — Run in Profile Mode (Performance Testing)
```bash
flutter run --profile -d <ios-simulator-device-id>
```
*(Note: Release mode on iOS simulator is not supported by Flutter; use Debug or Profile mode for simulator testing.)*

---

## 9. Run on Physical iPhone / iPad

1. Connect your iPhone or iPad to your Mac via USB cable.
2. Unlock the device and tap **Trust This Computer** when prompted.
3. Open the Xcode workspace:
   ```bash
   open ios/Runner.xcworkspace
   ```
4. In Xcode:
   * In the project navigator, select the root **Runner** project.
   * Under the **Targets** list, select **Runner**.
   * Open the **Signing & Capabilities** tab.
   * Select your **Team** (Apple Developer Account).
   * Verify the **Bundle Identifier**.
   * Ensure **Automatically manage signing** is checked.
5. Select your physical iOS device from the Xcode device destination menu or run via CLI:
   ```bash
   flutter devices
   flutter run -d <ios-device-id>
   ```

> **Testing Biometrics:** Real Face ID / Touch ID hardware behavior can be fully verified on physical devices. On the iOS Simulator, biometric authentication can be simulated via the simulator menu: `Features > Face ID > Enrolled` and `Features > Face ID > Matching / Non-matching Face`.

---

## 10. Build iOS

### Debug Build
```bash
flutter build ios --debug
```

### Release Build
```bash
flutter build ios --release
```

> **Requirements for Release Builds:**
> * macOS with Xcode installed.
> * A configured Apple Developer Account with a valid Development Team and provisioning profile.
> * `flutter build ios --release` prepares the compiled iOS binaries (`Runner.app`). To generate an export package for distribution, build an IPA.

---

## 11. Build IPA

To generate an `.ipa` distribution bundle for TestFlight, App Store submission, or Ad Hoc distribution:

```bash
flutter build ipa --release
```

### Output Location
Upon completion, the generated archive and IPA file will be available under:
```text
build/ios/ipa/
```

### Distribution Channels
The output IPA can be uploaded/distributed via:
* **TestFlight / App Store Connect** (via Xcode Organizer or `xcrun altool` / `transporter`)
* **Ad Hoc Distribution** (for registered test devices)
* **Enterprise / Internal MDM Deployment**

---

## 12. Open Project in Xcode

When working with native iOS configurations, always open the `.xcworkspace` file created by CocoaPods:

```bash
open ios/Runner.xcworkspace
```

> **Important:** Do not open `ios/Runner.xcodeproj` directly, as it does not include the CocoaPods pod targets required to compile plugin dependencies.

---

## 13. iOS Signing Notes

If you encounter code signing errors during iOS build or deployment:

1. **Missing Development Team:**
   * Open `ios/Runner.xcworkspace` in Xcode.
   * Navigate to `Runner > Signing & Capabilities` and select a valid Team under the dropdown.
2. **Invalid / Conflicting Bundle Identifier:**
   * Ensure the Bundle Identifier is unique and properly registered under your Apple Developer account.
3. **Provisioning Profiles & Certificates:**
   * If using automatic signing, Xcode will create and download development certificates automatically.
   * For manual signing, ensure valid Distribution/Development Provisioning Profiles are selected.
4. **Untrusted Developer on Device:**
   * On iOS devices running iOS 15+: Navigate to `Settings > General > VPN & Device Management`, select your developer certificate, and tap **Trust**.
   * On iOS 16+: Ensure Developer Mode is enabled under `Settings > Privacy & Security > Developer Mode`.

---

## 14. iOS Biometric Requirements

PAMZ Hisab integrates biometric authentication using `local_auth`. The following privacy permissions are declared in `ios/Runner/Info.plist`:

* **`NSFaceIDUsageDescription`**:
  `PAMZ Hisab uses Face ID to securely authenticate and lock your financial data.`
* **`NSCameraUsageDescription`**:
  `PAMZ Hisab requires access to your camera to capture expense receipt photos.`
* **`NSPhotoLibraryUsageDescription`**:
  `PAMZ Hisab requires access to your photo library to attach expense receipt photos.`

### Biometric Notes:
* **Physical Hardware:** Face ID / Touch ID availability depends on the device hardware capabilities and user enrollment in iOS Settings.
* **Simulator:** Hardware biometrics do not exist on simulators, but enrollment and match states can be simulated via `Features > Face ID / Touch ID` in the Simulator toolbar.

---

## 15. Testing

### Run All Unit and Widget Tests
```bash
flutter test
```

### Run Specific Test Files
```bash
flutter test test/feature/contacts/
flutter test test/core/security/
```

### Run Tests with Code Coverage
```bash
flutter test --coverage
```
Coverage data will be written to `coverage/lcov.info`.

---

## 16. Code Analysis & Linting

Verify code quality and check for static analysis issues:

```bash
flutter analyze
```

---

## 17. Build Web

Generate production-ready web assets:

```bash
flutter build web
```
Output assets will be located in `build/web/`.

---

## 18. Useful Commands

| Command | Description |
|---|---|
| `flutter pub get` | Fetch all project dependencies |
| `flutter doctor` | Check system environment, SDKs, and tooling health |
| `flutter devices` | List all connected physical devices, emulators, and simulators |
| `flutter run` | Run app on default connected device |
| `flutter run -d chrome` | Run app in Google Chrome (Web development mode) |
| `flutter test` | Run test suite |
| `flutter test --coverage` | Run test suite and generate LCOV coverage report |
| `flutter analyze` | Run Dart static analyzer across the codebase |
| `flutter build web` | Build production bundle for Web |
| `flutter build ios --release` | Build release version of the iOS application |
| `flutter build ipa --release` | Build release `.ipa` package for App Store / TestFlight distribution |

---

## 19. Troubleshooting

### CocoaPods Dependency Issues
If iOS pod dependencies fail to resolve or sync:
```bash
cd ios
pod repo update
pod install
cd ..
```

### Complete Clean Build
If experiencing stale build cache or plugin linkage issues:
```bash
flutter clean
flutter pub get
cd ios
pod deintegrate
pod install
cd ..
```

### Xcode Derived Data Issue
If Xcode fails with cached build artifacts:
1. Open Xcode.
2. Select `Product > Clean Build Folder` (`Cmd + Shift + K`).
3. Or manually clear derived data from terminal:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

### Simulator Not Listed in Flutter Devices
If a booted iOS simulator is not recognized by Flutter:
```bash
flutter devices
xcrun simctl list devices
```
If necessary, restart the simulator app or restart the simulator service daemon:
```bash
killall Simulator
open -a Simulator
```
