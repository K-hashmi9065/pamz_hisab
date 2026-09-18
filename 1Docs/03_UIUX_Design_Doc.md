# PAMZ Hisab — UI/UX Design Document (iPad)

**Platform:** iPadOS (native app, split-view/multitasking aware)
**Version:** 1.1

---

## 1. Design Principles

1. **Ledger-first clarity** — money amounts (credit vs debit, owed-to-me vs owed-by-me) must be scannable at a glance, using color + iconography, never color alone (accessibility).
2. **Low-literacy-friendly** — large tap targets, minimal text-entry, iconographic navigation, Hindi/Hinglish support — designed for shopkeepers who may not be power-users.
3. **iPad-native, not a stretched phone UI** — use the extra horizontal space for **master-detail (split view)** patterns, not single-column phone layouts scaled up.
4. **Offline-confidence** — no spinners waiting on network; every action feels instant since all data is local.
5. **Consistency over novelty** — one `AppButton`, one `AppCard`, one spacing scale, one type scale, applied everywhere via `ThemeData` — never hardcoded colors/padding/font sizes (per global UI rules).

## 2. Design System

### 2.1 Typography (google_fonts)
Recommend a highly-legible, Devanagari-compatible pairing since Hindi/Hinglish support is required:

| Token | Font | Usage |
|---|---|---|
| `AppTextStyles.display` | `GoogleFonts.notoSansDisplay` / `Poppins` (28–32sp) | Dashboard headline totals |
| `AppTextStyles.h1` / `h2` | `Poppins` SemiBold (22 / 18sp) | Screen titles, section headers |
| `AppTextStyles.body` | `GoogleFonts.notoSans` Regular (15sp) | Body text — **must** cover Devanagari glyphs for Hindi |
| `AppTextStyles.amount` | `GoogleFonts.robotoMono` / tabular-figure font (18–24sp, bold) | All currency amounts — monospaced digits so columns of numbers align |
| `AppTextStyles.caption` | Regular (12sp) | Timestamps, memo text, helper text |

> All sizes are `.sp` via `flutter_screenutil`, using an iPad design-size baseline (e.g. `ScreenUtilInit(designSize: Size(1194, 834))` — 11" iPad landscape) so layouts scale correctly across iPad Mini → Pro 12.9" and in Split View/Slide Over multitasking widths.

### 2.2 Color System (semantic, theme-driven — never hardcoded)

| Token | Purpose |
|---|---|
| `AppColors.primary` | Brand color — app bar, primary actions |
| `AppColors.credit` (green) | Money owed **to** the user / income |
| `AppColors.debit` (red) | Money owed **by** the user / expense |
| `AppColors.warning` (amber) | Approaching due date / near budget threshold |
| `AppColors.surface` / `surfaceVariant` | Card backgrounds, list rows |
| `AppColors.outline` | Dividers, input borders |
| Dark mode | Full `ThemeData.dark()` variant — iPad users commonly use system dark mode |

### 2.3 Spacing & Layout Scale
`4 / 8 / 12 / 16 / 24 / 32 / 48` (all via `.w`/`.h`/`.r` from `flutter_screenutil`) — applied through shared widgets, never inline magic numbers.

### 2.4 Core Reusable Components
`AppButton` (primary/secondary/destructive), `AppCard`, `AppTextField` (with currency/phone input variants), `AppDialog`, `AppBottomSheet` (used for quick-entry on compact widths), `AppLoader`, `AppEmptyState`, `AppErrorView`, `CustomAppBar`, `SectionHeader`, `LedgerListTile` (contact name, avatar-initials, balance badge, due-date chip), `AmountBadge` (colored credit/debit pill), `ConfirmationDialog`, `AppSnackbar`.

## 3. iPad Navigation Model — Master-Detail Split View

Given iPad's horizontal real estate, the app uses a **persistent sidebar + master-detail** layout rather than a phone-style bottom nav bar:

```
┌───────────────┬─────────────────────────┬───────────────────────────┐
│  Sidebar Nav   │   Master List Pane       │   Detail Pane              │
│  (NavigationRail) │  (e.g. Buyer list)    │  (Selected buyer ledger)   │
│                │                          │                            │
│  ▸ Dashboard   │  🔍 Search               │  Ramesh Kumar               │
│  ▸ Udhar Khata │  Ramesh Kumar   ₹2,400   │  📞 98xxxxxxx1  Village: X  │
│  ▸ Family      │  Suresh Yadav   -₹800    │  ─────────────────────────  │
│  ▸ Reports     │  Anita Devi     ₹0       │  Transaction timeline       │
│  ▸ Settings    │  ...                     │  [+ New Entry] [Share PDF]  │
└───────────────┴─────────────────────────┴───────────────────────────┘
```

- **Regular width (iPad landscape / most Split View states):** 3-pane (sidebar + master + detail) using `NavigationRail` + `Row` of two `Expanded` panes, wired through GoRouter nested routes (`/udhar/contact/:id` renders detail pane in place, list pane persists).
- **Compact width (Slide Over / narrow Split View):** collapses to sidebar-as-drawer + single pane (master list), tapping a row pushes the detail screen (standard `GoRoute` push) — same routes, `AdaptiveShell` decides layout by `MediaQuery` width breakpoint (e.g. `>= 840` → 3-pane, `< 840` → collapsed).
- Sidebar items map 1:1 to GoRouter `ShellRoute` children: Dashboard, Udhar Khata, Family Finance, Reports, Settings.

## 4. Key Screens

### 4.1 Dashboard
- Top summary cards (via `AppCard` + `AmountBadge`): **Total Receivable** (credit color), **Total Payable** (debit color), **This Month Net Savings**, **Overdue Count** (warning color, tappable → filtered list).
- Quick-action row: `+ New Udhar`, `+ Family Expense`, `+ Family Income`.
- Recent activity feed (last 10 transactions, `LedgerListTile`).

### 4.2 Udhar Khata (Buyer/Supplier List — Master Pane)
- Segmented control: **Buyers | Suppliers | Direct Cash**.
- Search bar (name/mobile), sort (balance / recent / name).
- Each row: name, mobile, `AmountBadge` (green=they owe you, red=you owe them), due-date chip if overdue.
- FAB / `AppButton`: `+ New Contact`.

### 4.3 Contact Ledger (Detail Pane)
- Header: contact info, credit limit, edit/delete (CRUD).
- Running balance timeline: each transaction row (date, type icon, amount, memo), tappable for edit (universal CRUD, FR-UK-004).
- Actions: `+ Log Udhar`, `+ Log Repayment (Jama)`, `Share PDF Statement` (→ WhatsApp/SMS), `Export`.

### 4.4 Direct Cash Udhar (Money-Only Loan)
- Form (`AppTextField` amount w/ ₹ prefix, interest type toggle Simple/Interest-Free, due-date picker, memo).
- On save → auto-generates PDF acknowledgment voucher (FR-DU-004), prompts share sheet.

### 4.5 Family Finance (Income & Expense)
- Tab: **Income | Expense**.
- Expense entry includes camera capture (`image_picker`) for receipt photo, category picker (from configurable Category Engine), sub-category.
- Budget progress bars per category (real-time threshold alerts, FR-FE-003) using `AppColors.warning` as the threshold nears.

### 4.6 Category & System Configuration
- CRUD list of categories (income/expense), reorderable, with icon + color picker.
- System settings: currency symbol, Indian numbering toggle, fiscal year start, GST tax rate enabler.
- Notification template editor (Hindi/Hinglish/English variants) — FR-NT-003.

### 4.7 Analytics & Reports
- Time-horizon filter chips: Daily / Weekly / Monthly / Yearly / Quarterly / 10-Year / Custom Range.
- Charts (category-wise breakdown, bar/line trend) — should use a themed charting lib respecting `AppColors`.
- Export buttons: `PDF` and `.xlsx`, both accessible from the same toolbar.

### 4.8 App Lock (Entry Point)
- Face ID/Touch ID prompt on launch and on backgrounding-then-resuming beyond a timeout; passcode/PIN fallback if biometrics fail or are unavailable.

## 5. Accessibility & Regional-Language Considerations

- All interactive targets ≥ 44×44pt (iPad HIG minimum).
- Never encode meaning by color alone — pair `AmountBadge` colors with `+`/`-` prefix and icon.
- Full Hindi/Hinglish string support via `flutter_localizations`/`intl`; Devanagari-safe font (`GoogleFonts.notoSans`) as fallback wherever `Poppins` lacks glyph coverage.
- Support Dynamic Type / iOS text-scaling alongside `flutter_screenutil` scaling (test at largest accessibility text sizes to ensure `LedgerListTile` doesn't truncate amounts).
- VoiceOver labels on all icon-only buttons (share, edit, delete).

## 6. Multitasking & Orientation

- Fully support iPad **Split View**, **Slide Over**, and **Stage Manager** resizing — layout breakpoints (regular ≥840pt / compact <840pt) must reflow live, not just at launch.
- Support both landscape and portrait; master-detail collapses to single-pane-with-push-navigation in portrait on smaller iPads.
