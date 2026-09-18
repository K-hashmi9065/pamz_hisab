# PAMZ Hisab — Product Requirements Document (PRD)

**Version:** 1.1
**Platform:** Native iPad Application (iPadOS)
**Distribution:** Direct enterprise / ad-hoc sideload (NOT App Store)
**Target Market:** Kishanganj, Bihar, India
**Owner:** Kamran Hashmi

---

## 1. Executive Summary

PAMZ Hisab is an offline-first iPad application that unifies two workflows for a household/small-trader user base in Kishanganj, Bihar:

1. **Domestic finance management** — family income & expense tracking, budgets.
2. **Commercial credit ledger (Udhar Khata)** — buyer/supplier ledgers and a **dedicated direct cash lending/borrowing engine** that is independent of any itemized goods/services sale.

The app must work fully offline (no server dependency for core operation), support regional-language notifications (Hindi/Hinglish/English), and generate shareable PDF vouchers/statements over WhatsApp and SMS.

## 2. Problem Statement

Small traders and households in this region currently track credit (udhar), income, and expenses on paper registers or spreadsheets. This causes:
- No searchable transaction history, error-prone manual interest/balance tracking
- No reminders for due repayments → cash flow leakage
- No proof-of-transaction sharing with customers (WhatsApp is the dominant channel)
- No offline-safe digital record with biometric protection

## 3. Goals & Success Metrics

| Goal | Success Metric |
|---|---|
| Replace paper Udhar Khata | 90% of a pilot user's daily entries logged digitally within week 1 |
| Reduce repayment default/delay | Due-date alerts sent for 100% of overdue balances |
| Zero data loss offline | 0 data-loss incidents across 10-year local history |
| Fast statement sharing | PDF+WhatsApp dispatch completed in <10s per statement |
| Regional adoption | Support Hindi/Hinglish/English UI & templates from v1 |

## 4. Target Users / Personas

| Persona | Description | Primary Needs |
|---|---|---|
| **Shopkeeper / Trader (Primary)** | Runs a small shop/business, extends credit to regular buyers, buys on credit from suppliers | Fast Udhar entry, due-date alerts, WhatsApp receipts |
| **Head of Household (Secondary)** | Manages family income/expense, seasonal agricultural earnings | Category-wise budgeting, 10-year history, simple UI |
| **Direct Lender/Borrower (Secondary)** | Lends/borrows cash directly (not tied to goods) | Interest tracking, repayment ("Jama") logging |

## 5. Scope

### 5.1 In Scope (v1.1)
- Direct Cash Credit/Loan module (money-only Udhar)
- Buyer & Supplier Udhar Khata with unique-mobile enforcement
- Family Income & Expense module
- Fully configurable Category Engine (no hardcoded values)
- WhatsApp PDF invoicing + SMS notification engine
- Category-wise analytics with 10-year historical reporting
- Offline-first local storage with biometric app lock

### 5.2 Out of Scope (v1.1)
- Cloud sync / multi-device sync
- Multi-user roles/permissions (single-owner app)
- Payment gateway / online payment collection
- App Store distribution
- Android version

## 6. Functional Requirements

### 6.1 Direct Cash Credit/Loan Module (Money-Only Udhar Khata)

| Req ID | Feature | Requirement & Rules | Priority |
|---|---|---|---|
| FR-DU-001 | Direct Cash Lending Entry | Record pure cash loans extended to Buyers/Individuals, not linked to goods/services. Fields: Amount, Interest Type (Simple / Interest-Free), Due Date, Memo. | High |
| FR-DU-002 | Direct Cash Borrowing Entry | Record cash loans borrowed from Suppliers/Lenders. Auto-tracks principal balance, interest accumulation, repayment schedule. | High |
| FR-DU-003 | Cash Repayment Logging | Record partial/full repayments ("Jama") mapped to a specific direct-credit balance. | High |
| FR-DU-004 | Direct Udhar Receipt PDF | Generate instant clean PDF money-receipt / loan-acknowledgment voucher, formatted for sharing. | High |

### 6.2 Buyer & Supplier Udhar Khata (Unique Mobile & Universal CRUD)

| Req ID | Feature | Requirement & Rules | Priority |
|---|---|---|---|
| FR-UK-001 | Unique Phone Enforcement | Mandates unique 10-digit primary Indian phone number per contact. Duplicate numbers blocked. | High |
| FR-UK-002 | Buyer Profile CRUD | Full CRUD for Buyer profiles (Name, Unique Mobile, Address, Village/Tola, Credit Limit). | High |
| FR-UK-003 | Supplier Profile CRUD | Full CRUD for Supplier Profiles (Name, Unique Mobile, Shop Location, Due Date Alerts, Balance Payable). | High |
| FR-UK-004 | Universal System CRUD | Every transaction log, entity record, and ledger line item supports full CRUD with audit logs. | High |

### 6.3 Family Income & Expense Module

| Req ID | Feature | Requirement & Rules | Priority |
|---|---|---|---|
| FR-FE-001 | Family Income Logging | Full CRUD logging of household income across defined categories, with source tags and bank/cash account mapping. | High |
| FR-FE-002 | Family Expense Logging | Full CRUD for daily domestic expenses, with receipt photo attachment via iPad camera and sub-category classification. | High |
| FR-FE-003 | Budget Tracking | Real-time monthly category spending limits with threshold alerts. | Medium |

### 6.4 Category Engine & System Configurability

No values are hardcoded — categories, tax fields, payment modes, and system settings are 100% CRUD-configurable.

**Pre-configured presets (Kishanganj ecosystem defaults):**

| Domain | Presets |
|---|---|
| Income Categories | Salary, Agricultural Yield Sales (Jute, Tea, Rice, Maize), Business/Shop Earnings, Property Rent, Remittances, Direct Loan Interest Income |
| Expense Categories | Groceries & Ration, Agriculture Inputs (Fertilizer, Seeds, Equipment), Education & Tuition, Healthcare, Utilities, Transportation, Direct Cash Debt Repayments |
| System Configurations | Configurable ₹/INR symbol, Indian numbering (Lakhs/Crores), Fiscal Year Start (April 1 vs Jan 1), Tax Rate Enabler (GST) |

### 6.5 Automated WhatsApp PDF Invoicing & SMS Notification Engine

| Req ID | Feature | Requirement & Rules | Priority |
|---|---|---|---|
| FR-NT-001 | WhatsApp PDF Dispatch | Generate itemized PDF ledger statement/invoice, auto-attach via WhatsApp with a personalized textual summary. | High |
| FR-NT-002 | Direct SMS Alerts | Trigger SMS to unique phone numbers for non-WhatsApp users. | High |
| FR-NT-003 | Template Customization | Fully configurable message templates supporting Hindi, Hinglish, English. | Medium |

### 6.6 Category-Wise Analytics & 10-Year Historical Reporting

| Time Horizon | Deliverables |
|---|---|
| Daily & Weekly | Daily cash flow summary, daily Udhar collection logs, weekly category spending breakdown |
| Monthly & Yearly | Monthly P&L statement, YoY budget trend comparison, net savings tracking |
| Quarterly | Q1–Q4 breakdown aligned to regional agricultural harvest cycles |
| 10-Year Lookback | Query/retrieve/compare historical data for any of the previous 10 years |
| Custom Range | Custom start/end date selector with instant PDF and Excel (.xlsx) export |

## 7. Non-Functional Requirements

| Category | Requirement |
|---|---|
| **Offline-first** | 100% of core CRUD, ledger, and analytics functionality works with zero network connectivity |
| **Security** | Biometric (Face ID / Touch ID) app lock; local data encryption at rest |
| **Deployment** | Signed enterprise/ad-hoc `.ipa`, installed via Apple Configurator / MDM / Enterprise Distribution Profile |
| **Data retention** | Minimum 10 years of queryable local historical data |
| **Localization** | Hindi, Hinglish, English for UI text/message templates |
| **Performance** | Ledger/list screens must remain responsive (<200ms interaction latency) with 10 years of transaction history on-device |
| **Reliability** | No data loss on app crash/force-quit; all writes transactional |

## 8. Assumptions & Constraints
- Single-owner/single-device usage per app instance (no multi-device sync in v1.1).
- WhatsApp and native SMS capability must exist on the device/iPad (WhatsApp presence not guaranteed on all iPads — see TRD for fallback).
- iPad-only; no iPhone-optimized layout required in v1.1.
- Enterprise sideload requires a valid Apple Developer Enterprise Program account, which is an external dependency the business must obtain.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Enterprise cert revoked/expired → app stops launching | Track cert expiry; document renewal runbook; consider ad-hoc profile as backup |
| WhatsApp app absent on iPad (WhatsApp Business/iPad support is limited) | Fallback to PDF export + system share sheet + SMS |
| Local-only storage = risk of device loss/damage losing all data | Provide manual encrypted local backup/export (to Files app / AirDrop) even though cloud sync is out of scope |
| 10-year local dataset growth impacting performance | TRD mandates indexed SQLite schema + pagination (see TRD §6) |
