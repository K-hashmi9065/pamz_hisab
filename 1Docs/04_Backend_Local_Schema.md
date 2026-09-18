# PAMZ Hisab — Local "Backend" Data Schema (Offline-First: SQLite + Hive)

There is no remote server in v1.1. The **local database is the backend**:
- **SQLite** (`sqflite`/`drift`, SQLCipher-encrypted) — system of record for all financial/ledger data (relational integrity, indexed range queries, 10-yr reporting).
- **Hive** — lightweight KV store for app config, category presets, message templates, and UI/session state.

---

## 1. SQLite Schema (Entity Relationship Overview)

```
contacts ──< direct_udhar_loans ──< repayments
contacts ──< trade_ledger_entries ──< repayments
categories ──< family_transactions
categories ──< budgets
family_transactions >── accounts (cash/bank)
audit_log (append-only, references any entity by type+id)
monthly_summary (pre-aggregated, refreshed on write — perf optimization)
```

### 1.1 `contacts`
Buyers & Suppliers (FR-UK-002 / FR-UK-003).

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `type` | TEXT | `'buyer' \| 'supplier'` |
| `name` | TEXT | NOT NULL |
| `mobile_number` | TEXT | **NOT NULL, UNIQUE** (10-digit Indian mobile, enforces FR-UK-001) |
| `address` | TEXT | nullable |
| `village_tola` | TEXT | nullable (buyer-specific) |
| `shop_location` | TEXT | nullable (supplier-specific) |
| `credit_limit` | REAL | default 0 (buyer-specific) |
| `due_date_alert_enabled` | INTEGER | 0/1 (supplier-specific) |
| `created_at` | TEXT (ISO8601) | NOT NULL |
| `updated_at` | TEXT (ISO8601) | NOT NULL |
| `is_deleted` | INTEGER | 0/1, soft-delete for audit trail |

`CREATE UNIQUE INDEX idx_contacts_mobile ON contacts(mobile_number) WHERE is_deleted = 0;`
`CREATE INDEX idx_contacts_type ON contacts(type);`

### 1.2 `direct_udhar_loans`
Money-only lending/borrowing, not tied to goods (FR-DU-001/002).

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `contact_id` | TEXT | FK → `contacts.id`, NOT NULL |
| `direction` | TEXT | `'lent' \| 'borrowed'` |
| `principal_amount` | REAL | NOT NULL |
| `interest_type` | TEXT | `'simple' \| 'interest_free'` |
| `interest_rate_percent` | REAL | nullable (used if `interest_type = 'simple'`) |
| `due_date` | TEXT (ISO8601) | nullable |
| `memo` | TEXT | nullable |
| `status` | TEXT | `'open' \| 'partially_paid' \| 'closed'` |
| `outstanding_balance` | REAL | NOT NULL, denormalized running balance (updated transactionally on repayment insert) |
| `created_at` / `updated_at` | TEXT | NOT NULL |
| `is_deleted` | INTEGER | soft-delete |

`CREATE INDEX idx_udhar_contact ON direct_udhar_loans(contact_id);`
`CREATE INDEX idx_udhar_due_date ON direct_udhar_loans(due_date);`
`CREATE INDEX idx_udhar_status ON direct_udhar_loans(status);`

### 1.3 `trade_ledger_entries`
General buyer/supplier ledger CRUD lines (FR-UK-004) — covers non-"direct cash" ledger movement referenced against a contact (e.g. goods-based credit, if/when itemized sales are recorded).

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `contact_id` | TEXT | FK → `contacts.id`, NOT NULL |
| `entry_type` | TEXT | `'credit' \| 'debit'` |
| `amount` | REAL | NOT NULL |
| `description` | TEXT | nullable |
| `entry_date` | TEXT (ISO8601) | NOT NULL |
| `created_at` / `updated_at` | TEXT | NOT NULL |
| `is_deleted` | INTEGER | soft-delete |

`CREATE INDEX idx_trade_contact_date ON trade_ledger_entries(contact_id, entry_date);`

### 1.4 `repayments`
"Jama" — partial/full repayments against either a `direct_udhar_loans` row or a `trade_ledger_entries` balance (FR-DU-003).

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `source_type` | TEXT | `'direct_udhar' \| 'trade_ledger'` |
| `source_id` | TEXT | FK → `direct_udhar_loans.id` OR `trade_ledger_entries.id` (polymorphic; enforced in app layer, not FK constraint) |
| `amount` | REAL | NOT NULL |
| `payment_mode` | TEXT | FK → `payment_modes.code` (configurable, e.g. cash/bank/UPI) |
| `paid_at` | TEXT (ISO8601) | NOT NULL |
| `memo` | TEXT | nullable |
| `created_at` | TEXT | NOT NULL |
| `is_deleted` | INTEGER | soft-delete |

`CREATE INDEX idx_repayments_source ON repayments(source_type, source_id);`
`CREATE INDEX idx_repayments_paid_at ON repayments(paid_at);`

### 1.5 `categories`
Fully CRUD-configurable Category Engine (FR-CAT), seeded with Kishanganj presets.

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `domain` | TEXT | `'income' \| 'expense'` |
| `name` | TEXT | NOT NULL |
| `parent_category_id` | TEXT | nullable, FK → `categories.id` (sub-category support) |
| `icon_key` | TEXT | nullable |
| `color_hex` | TEXT | nullable |
| `is_system_preset` | INTEGER | 0/1 (seeded vs user-created — presets still editable/deletable per FR-CAT) |
| `sort_order` | INTEGER | default 0 |
| `is_deleted` | INTEGER | soft-delete |

### 1.6 `accounts`
Cash/bank account mapping referenced by family income (FR-FE-001).

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `name` | TEXT | NOT NULL (e.g. "Cash", "SBI Savings") |
| `type` | TEXT | `'cash' \| 'bank'` |
| `is_deleted` | INTEGER | soft-delete |

### 1.7 `family_transactions`
Unified income & expense log (FR-FE-001/002).

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `type` | TEXT | `'income' \| 'expense'` |
| `amount` | REAL | NOT NULL |
| `category_id` | TEXT | FK → `categories.id`, NOT NULL |
| `account_id` | TEXT | FK → `accounts.id`, nullable |
| `source_tag` | TEXT | nullable (income-specific, e.g. "Agricultural Yield") |
| `receipt_photo_path` | TEXT | nullable (expense-specific, local file path) |
| `transaction_date` | TEXT (ISO8601) | NOT NULL |
| `notes` | TEXT | nullable |
| `created_at` / `updated_at` | TEXT | NOT NULL |
| `is_deleted` | INTEGER | soft-delete |

`CREATE INDEX idx_family_txn_date ON family_transactions(transaction_date);`
`CREATE INDEX idx_family_txn_category ON family_transactions(category_id);`

### 1.8 `budgets`
Monthly category spending limits (FR-FE-003).

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `category_id` | TEXT | FK → `categories.id`, NOT NULL |
| `month` | TEXT | `'YYYY-MM'` |
| `limit_amount` | REAL | NOT NULL |
| `alert_threshold_percent` | INTEGER | default 80 |

`CREATE UNIQUE INDEX idx_budget_category_month ON budgets(category_id, month);`

### 1.9 `payment_modes`
Configurable payment modes (system config, not hardcoded).

| Column | Type | Constraints |
|---|---|---|
| `code` | TEXT | PK (e.g. `cash`, `upi`, `bank_transfer`) |
| `label` | TEXT | NOT NULL |
| `is_active` | INTEGER | default 1 |

### 1.10 `monthly_summary` (Performance: Pre-Aggregated)
Refreshed incrementally on every write to `family_transactions`/`repayments` to avoid full 10-year scans on dashboard load (see TRD §6).

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `month` | TEXT | `'YYYY-MM'` |
| `category_id` | TEXT | FK → `categories.id`, nullable (NULL = overall total row) |
| `total_income` | REAL | default 0 |
| `total_expense` | REAL | default 0 |
| `total_udhar_given` | REAL | default 0 |
| `total_udhar_received` | REAL | default 0 |

`CREATE UNIQUE INDEX idx_summary_month_category ON monthly_summary(month, category_id);`

### 1.11 `audit_log`
Universal CRUD audit trail (FR-UK-004: "every transaction log, entity record, and ledger line item supports full CRUD with full audit logs").

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT (UUID) | PK |
| `entity_type` | TEXT | e.g. `'contact' \| 'direct_udhar_loans' \| 'repayment' \| 'family_transaction' \| 'category'` |
| `entity_id` | TEXT | NOT NULL |
| `action` | TEXT | `'create' \| 'update' \| 'delete'` |
| `changed_fields_json` | TEXT | JSON diff snapshot |
| `performed_at` | TEXT (ISO8601) | NOT NULL |

`CREATE INDEX idx_audit_entity ON audit_log(entity_type, entity_id);`

---

## 2. Hive Boxes (Config / Non-Relational State)

| Box Name | Key → Value | Purpose |
|---|---|---|
| `settings_box` | `currency_symbol`, `use_indian_numbering`, `fiscal_year_start_month`, `gst_enabled`, `gst_rate` | System config (FR-CAT) |
| `templates_box` | `templateId_locale → { subject, body }` | WhatsApp/SMS message templates per locale (FR-NT-003) |
| `app_lock_box` | `biometric_enabled`, `passcode_hash`, `lock_timeout_seconds` | App-lock preferences (encryption key itself lives in Keychain, **not** Hive) |
| `session_box` | `last_opened_at`, `onboarding_complete` | Ephemeral UI/session flags |
| `draft_box` | `draft_<formId> → serialized form state` | Unsaved form drafts (e.g. resume an interrupted Udhar entry) |

> Financial data is **never** stored in Hive — Hive holds only configuration and UI/session state; SQLite (encrypted) is the sole source of truth for money.

---

## 3. Data Integrity Rules (enforced at repository layer, not just DB constraints)

1. `contacts.mobile_number` uniqueness re-validated in the repository before insert (friendly `DuplicatePhoneFailure`, not a raw SQLite constraint error) — FR-UK-001.
2. All monetary writes (`direct_udhar_loans`, `repayments`, `trade_ledger_entries`, `family_transactions`) run inside a **SQLite transaction** together with their corresponding `audit_log` insert and `monthly_summary` update — atomic, no partial writes.
3. Soft-delete (`is_deleted = 1`) everywhere financial history matters — hard `DELETE` is never used on ledger tables, preserving the 10-year audit trail even after a user "deletes" an entry.
4. `outstanding_balance` on `direct_udhar_loans` is a denormalized field, recomputed transactionally on every linked `repayments` insert/update/delete — never trust a stale cached value across app restarts; validate against `SUM(repayments.amount)` in a background integrity check on cold start.

## 4. Migration Strategy

- Schema versioned via `sqflite`'s `onUpgrade` (or `drift`'s schema versioning) — every release ships an explicit, tested migration script.
- Given the 10-year local-history requirement, **migrations must be dry-run tested against a seeded large dataset** before release (TRD §10/§11 CI gate).
