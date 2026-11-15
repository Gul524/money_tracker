# Money Tracker — Project Context (single source of truth)

> **Purpose:** Full working context of this codebase so an AI/dev can act without re-reading source.
> **Snapshot of:** commit `3caed13` on `main` + uncommitted work (2026-11-15): full UI/UX redesign (design system, NavigationBar + single "Add" flow) **and feature completion**: tax recorded with income/expense (schema v4), account detail page, edit/delete for transfers and tax, History filters (type/account/category-tree/date/amount search), Reports for month / 6 months / year / custom dates with trend, tax, category roll-up and account flows.
> **Maintenance rule:** Whenever code changes, update the matching section here in the same change. If this file and code disagree, code wins — fix this file.

---

## 1. What the app is

Local-first, offline personal finance tracker (Flutter, Material 3, SQLite via `sqflite`). No network, no auth, no backend. Records:
- **Income / Expense** transactions (always tied to an account)
- **Owe In** ("owed to me") / **Owe Out** ("I owe") — pending until completed against an account
- **Tax payments** (separate table, reduce an account balance) — either standalone, or recorded *with* an income/expense entry (linked via `transaction_id`)
- **Transfers** between accounts
- **Accounts** (cash / bank) with computed balances
- **Assets** (things owned; purchase cost + current value; don't affect balances)
- **Categories** (hierarchical, typed income/expense/both) with a user-chosen **icon** and **tag color** (any color, stored as `#RRGGBB`)
- **Settings**: display currency (label only, no conversion), theme mode, and **defaults for new entries** (category + wallet per entry type, wallet per category, transfer From/To)
- **Import / export** of entries as Excel `.xlsx` (Settings › Data), via the separate `packages/transaction_io` module

Package name `money_tracker`, version `0.1.0+1`, Dart SDK `^3.13.3`. Android applicationId `com.example.money_tracker`. Platforms folders: `android/`, `linux/` (desktop sqflite not configured — tests use `sqflite_common_ffi`).

### Dependencies (pubspec.yaml)
- runtime: `flutter`, `json_annotation ^4.12.0`, `path ^1.9.1`, `sqflite ^2.4.4`, `file_picker` (13.x; static API `FilePicker.pickFiles/saveFile`), `transaction_io` (path: `packages/transaction_io`, which depends on `excel ^4.0.6`)
- dev: `flutter_test`, `flutter_lints ^6.0.0`, `build_runner ^2.16.1`, `json_serializable ^6.14.1`, `sqflite_common_ffi ^2.4.3`
- **No state-management package** (plain `ChangeNotifier` + `AnimatedBuilder`). **No router package** (`Navigator.push` + `MaterialPageRoute`). No intl package (dates/money formatted by hand).

### Commands
```sh
flutter pub get
dart run build_runner build     # regenerate *.g.dart after model changes
flutter analyze                 # analysis_options: flutter_lints; excludes build/, android/, linux/
flutter test
(cd packages/transaction_io && flutter test)   # module tests
```

---

## 2. Architecture (layers & data flow)

```
main.dart
  └─ MoneyTrackerApp (AnimatedBuilder on AppServices → MaterialApp themeMode)
       └─ SplashScreen → (services.initialize()) → pushReplacement AppShell

Screen (StatefulWidget)  ──owns──▶  Controller (BaseController : ChangeNotifier)
   │ AnimatedBuilder(controller)          │ calls
   ▼                                      ▼
 widgets/app_widgets.dart        AppServices (ChangeNotifier, DI container)
                                          │ holds
                         ┌────────────────┼──────────────────────┐
                    Repositories (CrudRepository<T>)      Services (Dashboard, Activity, Report, Settings)
                         └────────────────┬──────────────────────┘
                                   LocalDatabase (single sqflite connection, schema v5)
```

**Refresh mechanism (important):**
- `AppServices` is a `ChangeNotifier`. Every `BaseController` constructor does `services.addListener(refresh)`.
- After any write, controllers call `services.changed()` → `notifyListeners()` → **every live controller re-runs `refresh()`** (reloads its data from DB). Also `MoneyTrackerApp` rebuilds (theme).
- So cross-screen sync is automatic; no manual invalidation needed. Controllers remove the listener in `dispose()`.

**Error mechanism:** `BaseController.run(action)` sets `busy=true`, `error=null`, notifies; catches any exception and maps it into `error`:
- contains `FOREIGN KEY constraint failed` → "This item is in use and cannot be deleted."
- contains `UNIQUE constraint failed` → "This record is already linked to another item."
- otherwise `e.toString()` with `"Invalid argument(s): "` stripped (so `ArgumentError('X')` shows "X").
- returns `null` on error. Write methods use the pattern `await run(() async {...; return true;}) == true` → `Future<bool>` success flag. Screens pop the sheet/page only when it returns `true`.
- `_disposed` guard avoids notifying after dispose.

**Money:** all amounts are `int` **minor units** (×100). Parsing: `MoneyAmount.parse`. Formatting: `money(minor, currency, {signed})` in `lib/app/formatters.dart` → `Rs 12,345.50`, `$1,200.00`, `−Rs 5.00`, signed `+£25.00`. Symbols: PKR→`Rs`, USD→`$`, EUR→`€`, GBP→`£` (multi-letter symbols get a space). `amountInputText(minor)` → editable text (`1200`, `1250.5`).

**Dates:** stored as `DateTime.toIso8601String()` (local time, no TZ) TEXT columns; range queries compare ISO strings lexicographically. UI formats via `formatters.dart`: `formatDate` (`15 Nov 2026`), `formatMonthYear` (`November 2026`), `formatLongDate` (`Sunday, 15 November`), `relativeDay` (`Today`/`Yesterday`/`Tomorrow`/`Tue, 10 Nov`/`2 Mar 2025`), `dateOnly`.

---

## 3. File map

```
lib/
  main.dart                         App entry; MoneyTrackerApp
  app/
    app_services.dart               DI container + global app state (currency, themeMode)
    app_sizes.dart                  Design tokens on 4dp grid (TextSize, CardSize, IconSize, RadiusSize, SpaceSize, ComponentSize)
    app_theme.dart                  Light/dark ThemeData + AppColors ThemeExtension (income/expense/transfer/warning)
    formatters.dart                 money(), amountInputText(), currency symbols/names, date formatters, formatRange/shortMonth
    date_range.dart                 DateRange(start, end-exclusive): month/months/year/days factories, contains, label
    controllers/
      base_controller.dart          BaseController (run/error/busy/listener plumbing, clearError)
      money_amount.dart             MoneyAmount.parse (string → minor int)
      category_path.dart            categoryPath(): "Parent / Child / Leaf"
      splash_controller.dart        App init state
      home_controller.dart          Dashboard summary + 5 recent activity
      history_controller.dart       Activity + filters: type, account, category tree, DateRange/DatePreset, text/amount search, totals
      reports_controller.dart       ReportPeriod (month/6 months/year/custom), PeriodReport, category roll-up, position
      transaction_controller.dart   Add/edit/delete transaction (+ linked tax) and standalone tax (EntryKind, initialKind, existingTax)
      transfer_controller.dart      Create/edit/delete transfer (+balances, swap)
      account_controller.dart       Account CRUD + balances
      asset_controller.dart         Asset CRUD
      category_controller.dart      Category CRUD
      owe_controller.dart           Pending owes (split owedToMe/iOwe + totals) + complete
      settings_controller.dart      Currency + theme
      import_export_controller.dart Period/range for export, entry count, calls transaction_io export/import/template
      defaults_controller.dart      Settings › Defaults state (active wallets, categories, EntryDefaults)
    screens/
      splash_screen.dart            Brand mark, init, retry; fades to AppShell
      app_shell.dart                NavigationBar (4 tabs, IndexedStack) + "Add" FAB on Home/History
      add_entry_sheet.dart          openAddFlow(): "What would you like to add?" menu → form → "Saved" snackbar
      home_screen.dart              Dashboard ("Overview")
      history_screen.dart           Tab or pushed pre-filtered; search, type chips, Filters sheet, active-filter chips, result totals
      activity_list.dart            ActivityDayGroups (day headers + tiles) and openActivity() (routes any row to its editor)
      account_detail_screen.dart    One account: balance, this month in/out, its activity, edit/delete
      reports_screen.dart           Period segments, range bar, summary, month-by-month chart, categories, tax, accounts, position
      settings_screen.dart          Preferences (incl. Defaults tile) + Manage hub + About
      defaults_screen.dart          Settings › Defaults: per entry type, transfer, and per-category wallet pickers
      import_export_screen.dart     Settings › Data › Import and export (ExcelFiles abstraction over file_picker)
      transaction_screen.dart       Transaction/tax form (big amount, form rows, pinned Save)
      transfer_screen.dart          Transfer form (From/To + swap); edit/delete when `existing`
      account_screen.dart           Accounts (active/archived) → AccountDetailScreen; showAccountEditor() sheet
      asset_screen.dart             Assets + editor sheet
      category_screen.dart          Category tree by type + editor sheet
      owe_screen.dart               Money owed sections + settle sheet
    widgets/
      app_widgets.dart              Design-system components (exports formatters.dart + category_icons.dart)
      category_icons.dart           Icon catalog `categoryIconGroups` (key → IconData), categoryIcon(), hex helpers, categoryColor(), readableCategoryColor(), CategoryBadge
      category_pickers.dart         showIconPickerSheet() (grouped grid) and showColorPickerSheet() (SV panel + hue slider + hex + swatches)
  data/
    models/                         Immutable entities (@JsonSerializable, copyWith) + *.g.dart (generated)
      model_types.dart              Enums + `omitted` sentinel
      account.dart, account_transfer.dart, asset.dart, category.dart, money_transaction.dart, tax_payment.dart
    repo/
      crud_repository.dart          Generic CRUD base
      account_repository.dart, asset_repository.dart, category_repository.dart,
      tax_repository.dart, transaction_repository.dart, transfer_repository.dart
    services/
      local_database.dart           Connection, schema, migrations, seeding
      dashboard_service.dart        DashboardSummary for current month; categoryTotals(Between)
      report_service.dart           PeriodReport for any date range (totals, tax, owes settled, categories, AccountFlow, MonthBucket)
      activity_service.dart         Merged activity feed (transactions + tax + transfers)
      settings_service.dart         app_settings key/value
      defaults_service.dart         EntryDefaults (category/wallet per entry type, wallet per category) stored in app_settings
      transaction_io_store.dart     AppTransactionIoStore: the ONLY bridge between the app DB and the transaction_io module
packages/
  transaction_io/                   Self-contained Excel import/export module (own pubspec, tests, analysis_options)
    lib/transaction_io.dart         Public API (exports below)
    lib/src/tx_row.dart             TxType, OwedStatus, TxRow, RowIssue, transferArrow, categorySeparator
    lib/src/columns.dart            TxColumn: fixed column layout + header aliases
    lib/src/xlsx_codec.dart         encodeXlsx / decodeXlsx (pure, sync; run inside isolates)
    lib/src/duplicates.dart         duplicateKey, splitDuplicates (one-for-one)
    lib/src/store.dart              TransactionIoStore interface the host implements
    lib/src/api.dart                exportTransactions, importTransactions, transactionTemplate, exportFileName, ExportResult, ImportSummary
    test/transaction_io_test.dart   Round trip (times + due dates), period filter, duplicates, flexible parsing, text/serial date-times, row errors, bad files
test/
  data_layer_test.dart              Repo/service tests (in-memory FFI DB)
  app_smoke_test.dart               Widget tests (shell/add menu/tabs, end-to-end expense, theme switching)
  formatters_test.dart              money/date formatter unit tests
  features_test.dart                Linked tax, v3→v4 upgrade, period reports, report periods, history filters, range labels, defaults, category look
  import_export_test.dart           AppTransactionIoStore round trip into a fresh DB, rejected rows, ImportExportScreen with fake ExcelFiles
README.md                           Product/UI plan + data rules (human doc)
ui_ux.json                          Editable UI spec v2 (NOT loaded at runtime) — principles, tokens, nav, components, screens
```

---

## 4. Data layer

### 4.1 Enums (`lib/data/models/model_types.dart`)
```dart
enum CategoryType { income, expense, both }
enum AccountType { cash, bank }               // 'microfinance' was removed (commit 165f2cf)
enum TransactionType { income, expense, oweIn, oweOut }
enum OweStatus { pending, completed }
const omitted = Object();                     // copyWith sentinel: lets you pass null explicitly to clear nullable fields
```
Enums are stored in DB by `.name` and read with `values.byName`.

### 4.2 Models (`lib/data/models/*.dart`)
All immutable, `const` constructors, `id` is `int?` (null = not yet saved), `copyWith` where nullable fields use `Object? x = omitted`. `fromJson/toJson` are generated (`*.g.dart`) but **repositories do NOT use them** — repos map rows manually with snake_case columns. JSON is effectively unused at runtime.

| Model | Fields |
|---|---|
| `Account` | id, name, type: AccountType, openingBalanceMinor (default 0, may be negative), isArchived (default false) |
| `Category` | id, name, type: CategoryType, parentId?, icon? (catalog key; null = automatic from name), color? (`#RRGGBB`; null = automatic swatch) |
| `MoneyTransaction` | id, type: TransactionType, amountMinor, categoryId, accountId?, occurredAt, note?, party?, dueAt?, oweStatus?, completedAt? |
| `TaxPayment` | id, amountMinor, paidAt, accountId, note?, transactionId? (set = tax paid with that income/expense) |
| `AccountTransfer` | id, fromAccountId, toAccountId, amountMinor, occurredAt, note? |
| `Asset` | id, name, acquiredOn, purchaseAmountMinor, currentValueMinor, purchaseTransactionId?, notes? |

### 4.3 SQLite schema (`lib/data/services/local_database.dart`)
- DB file: `<getDatabasesPath()>/money_tracker.db` (or `path` ctor arg; tests use `inMemoryDatabasePath`). `LocalDatabase({DatabaseFactory? factory, String? path})`.
- **Version 5.** `onConfigure`: `PRAGMA foreign_keys = ON`. Connection opened lazily via `await storage.database` and cached.
- All FKs are `ON DELETE RESTRICT` (deleting a referenced row fails → "This item is in use…").

| Table | Columns / constraints |
|---|---|
| `categories` | id PK AI, name NOT NULL (trimmed non-empty), type CHECK income/expense/both, parent_id → categories, icon TEXT (v5), color TEXT CHECK NULL or `#` + 6 upper-case hex via GLOB (v5). Index `categories_parent_idx`. |
| `accounts` | id, name (non-empty), type CHECK cash/bank, opening_balance_minor INT default 0, is_archived 0/1 |
| `transactions` | id, type CHECK income/expense/oweIn/oweOut, amount_minor > 0, category_id NOT NULL → categories, account_id → accounts (nullable), occurred_at TEXT, note, party, due_at, owe_status CHECK pending/completed, completed_at. **Table CHECK:** income/expense ⇒ account_id NOT NULL and owe_status/due_at/completed_at NULL; oweIn/oweOut ⇒ owe_status NOT NULL and (pending ⇒ completed_at NULL; completed ⇒ completed_at & account_id NOT NULL). Indexes on occurred_at, category_id, account_id, (owe_status, due_at). |
| `assets` | id, name (non-empty), acquired_on, purchase_amount_minor ≥0, current_value_minor ≥0, purchase_transaction_id UNIQUE → transactions, notes |
| `tax_payments` | id, amount_minor > 0, paid_at, account_id NOT NULL → accounts, note, transaction_id → transactions **ON DELETE CASCADE** (added v4). Index on paid_at; partial UNIQUE index `tax_payments_transaction_idx` (one tax per transaction). |
| `transfers` (added v2) | id, from_account_id, to_account_id (→ accounts, NOT NULL), amount_minor > 0, occurred_at, note, CHECK from ≠ to. Index on occurred_at. |
| `app_settings` (added v2) | key TEXT PK, value TEXT. Seeded `currency=PKR`. `theme_mode` row inserted on first set. Defaults rows: `default_category:<kind>`, `default_account:<kind>` (kind = income/expense/oweIn/oweOut/tax/transferFrom/transferTo), `default_account_for_category:<categoryId>`; value = id as text. |

**Migrations (`_upgradeSchema`):** `<2` → create transfers + app_settings; `<3` → `_seedDefaults`; `<4` → `ALTER TABLE tax_payments ADD COLUMN transaction_id` + unique index (skipped if the table is missing or already has the column); `<5` → `ALTER TABLE categories ADD COLUMN icon` / `color` (each skipped if present or table missing).
**Seeding (`_seedDefaults`, on create and v3 upgrade), idempotent via `INSERT … WHERE NOT EXISTS` (case-insensitive name, root level):**
- income categories: Salary, Business, Bonus
- expense categories: Food, Shopping, Phone, Donation, Gifts, Education
- account: `Cash` (cash, opening 0)
These are normal editable/deletable rows.

**Adding a migration:** bump `version`, add `if (oldVersion < N)` block in `_upgradeSchema`, and make `_createSchema` produce the same final shape; add a test like "version 2 upgrade adds only missing defaults".

### 4.4 Repositories (`lib/data/repo/`)
`CrudRepository<T>(LocalDatabase storage)` — subclasses implement `table`, `fromRow`, `toRow`, `withId`, optional `validate(value, {updatingId})`.
- `create(v)`: throws if id ≠ null; `validate`; insert; returns copy with id.
- `getById(id)` → `T?`; `getAll()` ordered `id DESC` (newest first).
- `update(v)`: requires id; `validate(updatingId:)`; throws `StateError` if 0 rows.
- `delete(id)`: throws `StateError` if 0 rows. (FK violations throw from sqflite.)
- `toRow` trims `name` for accounts/categories/assets.

| Repo | Table | Validation | Extra methods |
|---|---|---|---|
| `AccountRepository` | accounts | name non-empty | `balanceMinor(accountId)` (see §5.1) |
| `CategoryRepository` | categories | name non-empty; color null or `^#[0-9a-fA-F]{6}$` (stored upper-cased by `toRow`); parent must exist; on update: no cycle (walks parent chain), and new type must stay compatible with existing transactions' directions | `childrenOf(int? parentId)` (sorted name NOCASE; currently unused by UI) |
| `TransactionRepository` | transactions | amount > 0; category exists & direction-compatible (income/oweIn need income|both; expense/oweOut need expense|both); income/expense need account & no owe fields; owe needs status; pending ⇒ no completedAt; completed ⇒ completedAt + account | `completeOwe(id, accountId, {at})` (only pending → completed, sets account & completedAt=now), `pendingOwes({through})` (ordered due_at nulls last; `through` = due before date), `history({limit})` (occurred_at DESC, id DESC), **`saveWithTax(tx, {taxMinor})`** (validate, then one DB transaction: insert/update tx + upsert/delete its linked tax with the tx's account & date; owes can't carry tax), **`delete` override** (also deletes linked tax). Internally owns its own `CategoryRepository`. |
| `TaxRepository` | tax_payments | amount > 0 | `paidInMonth(year, month)`, `history({limit})`, `forTransaction(id)` |
| `TransferRepository` | transfers | amount > 0; from ≠ to | `history({limit})` |
| `AssetRepository` | assets | name non-empty; values ≥ 0; if purchaseTransactionId set it must reference an **expense** transaction | — |

Note: repos and services each construct their own repository instances over the shared `LocalDatabase` (cheap; same connection).

### 4.5 Services (`lib/data/services/`)
- **`DashboardService.currentMonth({now})` → `DashboardSummary`**
  - `incomeMinor`/`expenseMinor`: sum of `income`/`expense` transactions with `occurred_at` in current calendar month.
  - `oweInMinor`/`oweOutMinor`: sum of **all pending** owes (not month-limited).
  - `taxPaidMinor`: tax with `paid_at` in current month.
  - `assetValueMinor`: sum of all `current_value_minor`.
  - `accounts`: `List<AccountOverview(account, balanceMinor)>` for **all** accounts (incl. archived), one balance query per account.
  - getter `totalBalanceMinor` = sum of account balances.
- **`DashboardService.categoryTotals(DateTime month)` → `List<CategoryTotal{categoryId, name, isIncome, totalMinor, parentId, icon, color}>`** — income/expense (not owes) grouped by category+type for that calendar month, `ORDER BY total DESC`. Used by Reports.
- `DashboardService.currentMonth(now: someMonth)` also works for past months (Reports passes the selected month).
- **`ActivityService.history({limit})` → `List<ActivityItem>`** — merges transactions, **standalone** taxes, transfers; sorted by date DESC; `limit` applied per source then to merged list. Linked tax is not a row; it rides on its transaction as `taxMinor`.
  - `ActivityItem { title, subtitle, amountMinor (signed), date, kind: ActivityKind{transaction,tax,transfer}, isPending, transaction?, tax?, transfer?, taxMinor, accountIds: Set<int>, accountName?, categoryId?, categoryIcon?, categoryColor? }`; getters `note`, `party`, `netEffectMinor` (0 for transfers/pending, else amount − taxMinor), `effectOn(accountId)` (transfer ± by direction).
  - Transaction: title = category name; subtitle Income / Expense / "Owed to you" / "Received owe" / "You owe" / "Repaid owe"; amount + for income/oweIn, − for expense/oweOut; `isPending` if owe pending.
  - Tax: title "Tax payment", subtitle note or "Paid tax", amount negative, `tax` set.
  - Transfer: title "Transfer", subtitle & accountName "FromName → ToName", amount positive (shown neutral), `transfer` set.
- **`ReportService.build(start, end)` → `PeriodReport`** (`start <= date < end`): `incomeMinor`, `expenseMinor`, `taxMinor` (all tax_payments incl. linked), `oweReceivedMinor`/`oweRepaidMinor` (completed owes by `completed_at`), `entryCount` (income/expense + standalone tax), `categories: List<CategoryTotal>` (with `parentId`), `accounts: List<AccountFlow{account, inMinor, outMinor, taxMinor, balanceMinor(today)}>` (in = income, received owes, transfers in; out = expense, repaid owes, tax, transfers out; archived accounts only if active in period; sorted by name), `months: List<MonthBucket{month, income, expense, tax}>` (every calendar month in range, grouped by `substr(date,1,7)`); getters `netMinor` (income − expense − tax), `outflowMinor`.
- **`DefaultsService`** (`services.defaults`): `load()` → `EntryDefaults{categoryByKind, accountByKind, accountByCategory}`; `setCategoryForKind(kind, id?)`, `setAccountForKind(kind, id?)`, `setAccountForCategory(categoryId, accountId?)` (null deletes the row); `forgetCategory(id)` / `forgetAccount(id)` (called by Category/AccountController.remove). `DefaultKind` string constants. No FKs: readers ignore ids that are missing/archived/type-incompatible.
- **`AppTransactionIoStore(LocalDatabase)`** (implements the module's `TransactionIoStore`): `readRows({from, to})` → transactions (category as full path "Food / Groceries", account name, party, `dueAt`→`dueDate`, owe status/completedAt, linked tax as `taxMinor`), standalone tax (`TxType.tax`), transfers (account "From → To"), sorted by date. `writeRows(rows)` → per row: find wallet by name (case-insensitive) or create it (bank if the name contains "bank", else cash); walk the category path creating missing levels with the row's direction; reject if the final category's type conflicts; save via `saveWithTax` / `taxes.create` / `transfers.create`; collects `RowIssue(sourceRow, message)` per failed row (other rows still saved; not one DB transaction).
- **`SettingsService`**: `currency()` (default PKR), `setCurrency(code)` allowed `PKR, USD, EUR, GBP` (uses UPDATE on seeded row), `themeMode()` returns `light|dark|system` (default `system`), `setThemeMode(mode)` (INSERT OR REPLACE).

---

## 5. Business rules

### 5.1 Account balance (`AccountRepository.balanceMinor`)
```
balance = opening_balance_minor
        + Σ transactions on account where (type in income/expense OR owe_status='completed')
              (+amount for income/oweIn, −amount for expense/oweOut)
        − Σ tax_payments on account
        + Σ transfers (+ if to_account, − if from_account)
```
Pending owes never affect balances. Assets never affect balances (link to a purchase expense instead to avoid double-debit).

### 5.2 Other rules
- Category direction must match transaction direction (enforced in repo validation + DB has no check for this; UI filters via `availableCategories`).
- Changing a category's type is blocked if existing transactions would conflict.
- Category hierarchy: any depth, no cycles; delete of a parent with children or a category with transactions fails (FK RESTRICT).
- Archived accounts: still shown in Accounts list & dashboard totals, but excluded from account pickers (transaction, transfer, owe-complete).
- Currency setting changes the label only; stored amounts are not converted.
- Dashboard "Net this month" (Home & Reports) = income − expense − tax (month).

---

## 6. App layer

### 6.1 `AppServices` (`lib/app/app_services.dart`)
`ChangeNotifier` holding: `database`, `categories`, `accounts`, `assets`, `transactions`, `transfers`, `taxes` (repos), `dashboard`, `activity`, `settings` (services); mutable `currencyCode='PKR'`, `themeMode=ThemeMode.system`.
- `AppServices.create()` (real DB) / `AppServices.withDatabase(LocalDatabase)` (tests).
- `initialize()`: opens DB, loads currency + theme, notifies.
- `setThemeMode(mode)`: persists + notifies (MaterialApp rebuilds).
- `changed()`: notify all listeners (triggers all controllers' `refresh`).
- `close()`: closes DB.

### 6.2 Controllers (`lib/app/controllers/`)
All (except Splash) extend `BaseController` and call `refresh()` in constructor. `BaseController.clearError()` is called before opening editor sheets.

| Controller | State | Methods |
|---|---|---|
| `SplashController` (plain ChangeNotifier) | ready, error | `initialize()` → `services.initialize()` |
| `HomeController` | `summary: DashboardSummary?`, `recentActivity` (5) | `load()` (pull-to-refresh) |
| `HistoryController(services, {accountId, categoryId, range, preset})` | `items`, `accounts`, `categories`, `filter: ActivityFilter{all, expense, income, transfer, owe, tax}`, `query`, `accountId`, `categoryId`, `range: DateRange?`, `preset: DatePreset{thisMonth,lastMonth,last3Months,thisYear,custom}?` | `setFilter/Query/Account/Category`, `setPreset(p,{now})`, `setRange`, `clearFilters` (not type/search); getters `visibleItems`, `activeFilterCount`, `isFiltering`, `selectedAccount/Category`, `totalsOf(items)` → (in, out) (per-account effect when account filtered). Tax filter = standalone tax OR `taxMinor>0`. Category filter includes all descendants. Search matches title/subtitle/note/party/accountName, and amounts ("1250", "1,250.5", "Rs 1250" → prefix of `amountInputText`, also tax). |
| `ReportsController(services, {now})` | `period: ReportPeriod{month,sixMonths,year,custom}`, `range: DateRange`, `report: PeriodReport?`, `position: DashboardSummary?` (today), `categories` | `setPeriod` (resets to the current one), `setCustomRange`, `previous()`, `next()`; getters `canStep` (not custom), `canGoNext` (next period has started), `spending`/`earning` → `List<CategoryGroup{categoryId, name, isIncome, icon, color (root's), totalMinor, parts: [(name,total)]}>` (rolled up to top-level category; parts empty if only the parent itself). |
| `TransactionController(services, {existing, existingTax, initialKind = expense})` | `kind`, `taxText`, `taxLoaded`, amountText, categoryId, accountId, occurredAt (now), dueAt, note, party, accounts (non-archived), `balances`, categories, `editing` | setters, `save()`, `remove()`; getters `isOwe`, `isTax`, `isIncome`, `availableCategories`, `pathFor()`, `selectedCategory`, `selectedAccount`. Auto-selects the only account on new entries. |
| `TransferController(services, {existing})` | `editing`, accounts, `balances`, from/to ids, amountText, note, occurredAt | setters, `swap()`, `save()` (create/update), `remove()` |
| `AccountController` | items, `balances: Map<int,int>` | `save({id,name,type,openingBalance(String),isArchived})`, `remove(id)` |
| `AssetController` | items | `save({...})`, `remove(id)` |
| `CategoryController` | items | `save({id,name,type,parentId,icon,color})`, `remove(id)`, `pathFor()` |
| `OweController` | items (pending owes), accounts | `complete(id, accountId)`; getters `owedToMe`, `iOwe`, `owedToMeMinor`, `iOweMinor` |
| `DefaultsController` | `defaults`, `accounts` (active), `categories` | `categoriesFor(kind)`, `sortedCategories`, `categoryFor(kind)`, `accountFor(kind)`, `accountForCategory(id)`, `setCategory`, `setAccount`, `setCategoryAccount` (each saves then reloads) |
| `ImportExportController(services, {now, store})` | `period: ReportPeriod`, `range`, `entryCount` (rows in range), `lastImport: ImportSummary?` | `setPeriod`, `setCustomRange`, `previous`, `next`, `canStep`, `canGoNext`; `export()` → `ExportResult?`, `template()` → bytes, `import(bytes)` → `ImportSummary?` (calls `services.changed()` if anything imported). Default store = `AppTransactionIoStore(services.database)`. |
| `SettingsController` | currency, themeMode | `setCurrency(v)` (also sets `services.currencyCode` + `changed()`), `setThemeMode(v)` |

**`EntryKind { income, expense, oweIn, oweOut, tax }`** (in transaction_controller.dart). `tax` is UI-only and saves to `TaxRepository`.

**`TransactionController.save()`:** parse amount (>0) → tax kind: require account → `taxes.create`/`update` (`existingTax`) | else require category, account unless owe → build `MoneyTransaction(type: byName(kind.name))`; owe keeps `editing?.oweStatus ?? pending` + `completedAt`, sets dueAt/party → `transactions.saveWithTax(tx, taxMinor)` (tax only for income/expense; empty = 0) → `services.changed()`. On edit, `refresh()` loads the linked tax once into `taxText` and sets `taxLoaded` (the screen keys the tax row on it). Getters `canHaveTax`, `amountMinor`, `taxMinor`, `isEditing`. **Defaults (new entries only):** first `refresh()` loads `EntryDefaults` and applies the kind's category (if none chosen and type-compatible) then the wallet: category's wallet → kind's wallet (active accounts only); falls back to the only account. `setKind` re-applies; `setCategory` re-applies the wallet; `setAccount` marks `_accountChosen` so defaults never overwrite a manual pick. `TransferController` applies `transferFrom`/`transferTo` once for new transfers. Pickers include an archived account only if the entry already uses it (same in TransferController). `setKind` clears incompatible category and dueAt if not owe. When editing, kind can't change (chips hidden).

**`MoneyAmount.parse(input, {allowZero, allowNegative})`**: regex `^-?\d+(\.\d{1,2})?$` → minor int. Accounts allow zero/negative opening; assets allow zero. `AmountField` input formatter only allows `^\d*\.?\d{0,2}`.

### 6.3 Design language (UI/UX redesign, 2026-11-15)
Based on Material 3 + Apple HIG patterns used by Google Wallet/Pay and iOS Settings:
- **Inset grouped lists** (`GroupedCard`) for related rows; hairline dividers inset to text (`ComponentSize.tileDividerIndent` 68).
- **One high-emphasis surface per screen** (Home balance card = primary; dark mode uses `primaryContainer`). Everything else neutral white/dark cards with 1px `outlineVariant` border, radius 16, no elevation/gradients.
- **Semantic color only:** `AppColors` income (green), expense (red: overdue/negative/errors), warning (amber: owes), transfer (blue). Expense amounts display in neutral text, income in green with `+`.
- **Plain language** for non-technical users: "Someone owes me", "I owe someone", "Starting balance", "Worth today", "Mark as received/paid".
- **Frequency-based prominence:** Add menu gives Expense/Income big cards; rarer actions in a list.
- **Big amount entry first** (Google Pay style), then tappable `FormRow`s that open `showPickerSheet` bottom sheets; primary button pinned via `BottomActionBar` (rises with keyboard).
- **Large collapsing titles** (`SliverAppBar.medium`) on tab roots; standard `AppBar` on pushed pages; every pushed page has a Scaffold/AppBar/back.
- Type scale ≥12sp (body 14/16), tabular figures for amounts, 48dp touch targets, 52dp buttons.
- Feedback: `EmptyState` with action, `ErrorBanner`, `InfoNote` helper text, `showMessage` snackbar ("Saved"), `confirmDelete` dialog with red Delete.

### 6.4 Screens & navigation (`lib/app/screens/`)
Flow: `main` → `SplashScreen` (brand mark, spinner; friendly error + "Try again") → fade `pushReplacement(AppShell)`.

**`AppShell`** — `Scaffold(body: IndexedStack[Home, History, Reports, Settings], bottomNavigationBar: NavigationBar (top hairline border), floatingActionButton: FAB.extended "+ Add" (tooltip 'Add') only on Home & History)`. Tabs keep state. Home's `onShowHistory` switches to tab 1.

**`openAddFlow(context, services)`** (`add_entry_sheet.dart`) — modal sheet "What would you like to add?" → `_AddChoice{expense, income, transfer, oweIn, oweOut, tax}` → pushes `TransactionScreen(initialKind:)` or `TransferScreen` → on `pop(true)` shows "Saved" snackbar. Used by shell FAB, Home welcome card, Owe screen FAB.

| Screen | Opened from | Layout (top → bottom) |
|---|---|---|
| `HomeScreen({services, onShowHistory})` | Tab 0 | RefreshIndicator + CustomScrollView: `SliverAppBar.medium('Overview')`, long date, `_BalanceCard` (Total balance, "Across N accounts", net-this-month pill; tap → Accounts), `_WelcomeCard` (only when no activity), "This month" `_MonthFlow` (Income/Spent `_StatCard`s), "Money owed" `_OweSummary` (→ OweScreen), "Accounts" + Manage (→ AccountScreen) `_AccountsCard` (non-archived), "Recent activity" + See all (→ History tab) `ActivityTile`s (transactions tap → edit), "Assets and tax" (Assets → AssetScreen, Tax paid this month). |
| `HistoryScreen({services, title='History', accountId, categoryId, range, initialFilter})` | Tab 1; pushed pre-filtered from Reports (category / tax) and Account detail ("Search") | `SliverAppBar.medium(title)`, search ("Search name, note or amount"), chip row: `Filters` ActionChip (Badge = active count) + type ChoiceChips; active filters as InputChips (tap → sheet, × → clear); `_ResultSummary` card (N entries · In · Out) when filtering; `ActivityDayGroups(accountId:)`. `_FilterSheet` (SheetScaffold "Filter activity"): Account picker (All/-1 sentinel), Category picker (tree indent), Date chips (Any time / This month / Last month / Last 3 months / This year / Custom dates… → `showDateRangePicker`), primary "Show N results", secondary "Clear filters". No-match state offers "Clear filters". Every row tappable via `openActivity`. |
| `AccountDetailScreen({services, accountId})` | Account list, Home accounts card, Reports accounts | AppBar(name, edit ✎ → `showAccountEditor`; pops if deleted). Balance card (Cash/Bank balance, Archived pill, starting balance), "This month · Month Year" Money in / Money out stat cards (per-account `effectOn`), "Activity" + Search (→ HistoryScreen(accountId)), `ActivityDayGroups(accountId)` (transfers shown ± for this account, account name omitted). Uses `AccountController` + `HistoryController(accountId)`. |
| `ReportsScreen` | Tab 2 | `ReportsController`. `SegmentedButton` Month / 6 months / Year / Custom (Custom → `showDateRangePicker`), `_RangeBar` (‹ label › with next disabled at current; custom: "Change" row), `_Summary` (Net for this period, income/expense/tax bar, rows, "N entries"), "Month by month" `_TrendChart` (only when >1 month; income vs spending incl. tax bars, Semantics label), "Spending by category" / "Income by category" `_Breakdown` (rolled-up groups with subcategory lines; tap → HistoryScreen(category, range, type)), "Tax paid" `_TaxSection` (total, % of income, per account; "See entries" → History tax filter), "Accounts" `_AccountFlows` (In · Out, signed net; tap → AccountDetailScreen), "Money owed settled" (if any), "Where you stand today" `_Position` (net worth). |
| `SettingsScreen({services})` | Tab 3 | `SliverAppBar.medium('Settings')`: Preferences (Currency tile → picker of `currencyNames`; "Defaults for new entries" → `DefaultsScreen`; Appearance `SegmentedButton<ThemeMode>` System/Light/Dark), InfoNote about no conversion, Manage (Accounts, Categories, Money owed, Assets → push), **Data (Import and export → `ImportExportScreen`)**, About (privacy, Version 0.1.0). |
| `ImportExportScreen({services, files})` | Settings › Data | AppBar 'Import and export'. Working row (spinner + "Preparing Excel file…"/"Importing…"), ErrorBanner. "Export to Excel": period `SegmentedButton` Month/6 months/Year/Custom (date range picker), card with ‹ range › (custom: "Change"), "N entries in this period", FilledButton "Export to Excel" (disabled at 0) → `files.save(fileName, bytes)` → snackbar "Exported N entries to …". InfoNote listing columns. "Import from Excel" card: explanation, "Choose Excel file" (`files.pick()` → import → snackbar "Imported X, skipped Y duplicates"), "Save a blank template". "Last import" GroupedCard (Imported / Skipped as duplicates / Problems) + first 30 issues ("Row N: message"). `ExcelFiles` interface (save/pick) defaults to `_PlatformExcelFiles` using `FilePicker.saveFile(bytes, xlsx MIME)` / `pickFiles(custom, ['xlsx'])`; tests inject a fake. |
| `TransactionScreen({services, existing, existingTax, initialKind})` | Add menu, `openActivity` (transactions & standalone tax), Owe "Edit details" | AppBar title by kind ("Add expense", "Someone owes me", "Edit tax payment"…), delete icon when editing (confirm mentions linked tax). Body: kind `ChoiceChip`s (new only), `AmountField` (income green, else neutral), GroupedCard[Category (picker w/ icons + "Manage categories" footer → CategoryScreen), Account (picker w/ balances; optional+clearable for owes), Date, Due date (owes, clearable)], **income/expense only:** GroupedCard[`FormTextRow(amount, prefix symbol, suffix "tax paid", hint "Tax paid (optional)")`], GroupedCard[Person (owes), Note], InfoNote tax summary ("Rs 1,170.00 leaves Cash: Rs 1,000.00 plus Rs 170.00 tax." / "Bank receives … minus … tax."), InfoNote for owes/tax, ErrorBanner. `bottomNavigationBar: BottomActionBar(Save)`. |
| `TransferScreen({services, existing})` | Add menu, `openActivity` | Title "Transfer money"/"Edit transfer" (+ delete icon), `AmountField` (blue), GroupedCard[From, To] with centered `IconButton.filledTonal` swap, GroupedCard[Date, Note], InfoNote, pinned "Transfer"/"Save". |
| `DefaultsScreen` | Settings › Defaults for new entries | AppBar 'Defaults', InfoNote (category wallet beats type wallet), sections Expense / Income / Someone owes me / I owe someone (Category + Wallet FormRows, clearable, placeholder "None"), Tax payment (Wallet), Transfer (From/To), then "Wallet for expense/income/shared categories" tiles (indented tree, trailing wallet or "None"). Pickers include "No default" (-1 sentinel). |
| `AccountScreen` | Settings › Accounts, Home | AppBar + FAB "Add account". Total-in-active card, "Active" and "Archived" groups. Tap row → `AccountDetailScreen`. `showAccountEditor(context, {services, controller, existing}) → Future<bool deleted>` (top-level, reused by detail) opens `SheetScaffold`: Account name, Cash/Bank `SegmentedButton`, Starting balance (symbol prefix, helper), Archive switch (edit), Save, "Delete account" (confirm). |
| `AssetScreen` | Settings › Assets, Home | AppBar + FAB "Add asset". Total value card, list with paid/date subtitle and gain/loss. Sheet: Name, Price paid / Worth today (row), Bought on, Notes, InfoNote, Save, Delete. Blank "worth today" = price paid. |
| `CategoryScreen` | Settings › Categories, category picker footer | AppBar + FAB "Add category". Sections Expenses / Income / Used for both; tree order by path, indented 24dp per depth, rows lead with `CategoryBadge` (40, 32 for children). Sheet: live 56dp `CategoryBadge` preview + Name (rebuilds preview while typing), Used for segmented, GroupedCard[Icon ("Automatic"/"Custom" + preview, clearable → `showIconPickerSheet`), Color (swatch + hex or "Automatic", clearable → `showColorPickerSheet`, saved via `colorToHex`), Inside → picker (Top level = -1 sentinel)], Save, Delete. |
| `OweScreen` | Settings › Money owed, Home owe cards | AppBar + FAB "Add" (openAddFlow). InfoNote, sections "Owed to you"/"You owe" with total in header; rows: party name, due/overdue (red "Overdue since …"). Tap → sheet "Mark as received/paid" with account radio list (preselects existing/only account), primary action, "Edit details" (→ TransactionScreen). |

### 6.5 Shared components (`lib/app/widgets/app_widgets.dart`)
Exports `formatters.dart` and `category_icons.dart`.
- Layout: `SectionHeader(title, {actionLabel, onAction, padding})`, `GroupedCard({children, dividerIndent})`, `IconBadge(icon, {color, background, size})`, `AppTile({title, subtitle, leading, trailing, onTap, showChevron, subtitleColor})`.
- Forms: `FormRow({icon, label, value, placeholder='Choose', onTap, onClear})`, `FormTextRow({icon, hint, value, onChanged, maxLines, capitalization})`, `AppTextField({label, value, onChanged, hint, helper, keyboardType, maxLines, prefixText, capitalization})`, `AmountField({controller, currency, onChanged, color, autofocus})`, `pickDate(context, initial)`.
- Money: `AmountText(minor, {currency, tone: AmountTone{neutral,income,expense,muted}, signed, style})` (tabular figures), `ActivityTile({item, currency, onTap, showDate, accountId})` (icon/color by kind/type; owes titled by party; subtitle = type · account · "Tax Rs X" · date; transfers show route, and ± when `accountId` given; Pending `StatusPill`), `StatusPill(label, {color})`.
- `FormTextRow` also takes `amount` (decimal keyboard, 2-dp formatter), `prefixText`, `suffixText`.
- In `screens/activity_list.dart`: `ActivityDayGroups({items, services, accountId})`, `openActivity(context, services, item)` (transaction → TransactionScreen, tax → TransactionScreen(existingTax), transfer → TransferScreen(existing); "Saved" snackbar).
- Feedback: `EmptyState({icon, title, message, actionLabel, onAction})`, `ErrorBanner(message?)`, `InfoNote(text)`, `showMessage(context, text)`, `confirmDelete(context, {title, message}) → Future<bool>`.
- Sheets: `showAppSheet(context, builder)` (scroll-controlled, keyboard-aware), `SheetScaffold({title, subtitle, children, primaryLabel, onPrimary, error, busy, secondaryLabel, onSecondary, destructiveLabel, onDestructive})`, `showPickerSheet<T>(context, {title, options: List<PickerOption<T>{value,title,subtitle,icon,indent}>, selected, emptyMessage, footerLabel, onFooter}) → Future<T?>`, `BottomActionBar(child)`.
- **Periods:** `ReportPeriod {month, sixMonths, year, custom}` lives in `date_range.dart` (re-exported by reports_controller) with `DateRange.current(period, today)`, `range.step(period, ±1)`, `range.canStepForward(period, today)`; used by Reports and Import/Export.
- **Category look** (`widgets/category_icons.dart`, exported by app_widgets): `categoryIconGroups` (9 labelled groups, ~90 icons; **keys are persisted — never rename**), `isCategoryIconKey`, `categoryIcon(name, {income, iconKey})` (chosen key, else keyword guess: food, salary, phone, rent, fuel, health…, fallback `sell_outlined`/`south_west_rounded`), `colorFromHex`/`colorToHex` (`#RRGGBB`), `categorySwatches` (12), `categoryColor(name, {hex})` (stored color or stable swatch from a name hash), `readableCategoryColor(color, brightness)` (lightens dark colors in dark mode, darkens pale ones in light mode), `CategoryBadge({name, iconKey, colorHex, income, size=40})` (tinted rounded square, alpha .14 light / .22 dark). Used by category list/pickers, transaction Category row & picker, History filter picker, Defaults, Reports breakdown (bar uses category color), and `ActivityTile` for income/expense (owes/tax/transfer keep semantic icons).
- **Pickers** (`widgets/category_pickers.dart`): `showIconPickerSheet(context, {color, selected, automatic}) → String?` (`automaticIcon` = '' for "Automatic"; cells have Semantics labels = key with spaces), `showColorPickerSheet(context, {initial, icon}) → Color?` (SheetScaffold "Tag color": preview badge + swatch + Hex field (6 hex chars), `_SaturationValuePanel` (white→hue × transparent→black; tap/drag via separate vertical+horizontal drag recognizers so the sheet doesn't steal drags), `_HueSlider`, quick swatches, "Use this color").
- `PickerOption` has `leading` (overrides `icon`); `FormRow` has `leading` (overrides `icon`) and `valueLeading` (before value text).

### 6.6 Theme & sizes
- `AppTheme.light()/dark()` → `_build`: palette (`_Palette.light/dark`) mapped onto `ColorScheme.fromSeed(...).copyWith(...)` with all `surfaceContainer*` = surface (flat) and `surfaceContainerHighest` = field color. `AppColors` extension (`AppColors.of(context)`): income, expense, transfer, warning (+Container variants), neutralContainer.
  - Light: bg `#F3F4F6`, surface white, text `#101828`/`#667085`, primary `#2C5BE0`, primaryContainer `#E3EAFD`. Dark: bg `#0C0E13`, surface `#171A21`, text `#ECEEF2`/`#98A2B3`, primary `#8AA8FF`, primaryContainer `#23315C`.
  - Component themes: AppBar (flat, bg = background), NavigationBar (68dp, indicator primaryContainer), FAB (radius 16), Card (border, radius 16), Divider, Input (filled, borderless, radius 12, focus ring primary), Filled/Outlined buttons (52dp, radius 12), SegmentedButton, Chip, BottomSheet (drag handle, radius 28, bg = background), Dialog (radius 20), SnackBar (floating, inverse), DatePicker.
  - Text: displaySmall 32/w700 (hero amounts), headlineMedium 28, headlineSmall 24, titleLarge 20/w600, titleMedium 16/w600, bodyLarge 16, bodyMedium 14, bodySmall 12 (secondary color), labelLarge 14/w600.
- `app_sizes.dart`: `TextSize{caption 12, small 13, body 14, bodyLarge 16, title 16, headline 20, largeTitle 28, amount 32, amountInput 44}`, `CardSize{padding 16, heroPadding 20}`, `IconSize{small 18, medium 20, large 24, hero 36}`, `RadiusSize{small 8, medium 12, large 16, extraLarge 20, sheet 28}`, `SpaceSize{tiny 2, extraSmall 4, small 8, medium 12, large 16, extraLarge 20, section 28, huge 40, gutter 16, fabClearance 96}`, `ComponentSize{iconBadge 40, minTouchTarget 48, buttonHeight 52, navigationBarHeight 68, splashLogo 72, tileDividerIndent 68}`.
- `ui_ux.json` v2 documents the design (not loaded at runtime).

---

## 6.7 Import/export module (`packages/transaction_io`)
Separate Dart package; the app only calls its public functions and implements `TransactionIoStore` (in `data/services/transaction_io_store.dart`). The module never imports app code.
- **Format (same for export and import)** — sheet `Transactions` (+ `How to import` help sheet), bold header row, columns in order: `Sr`, `Type` (Income / Expense / Owed to me / I owe / Tax / Transfer), `Category` ("Parent / Child"; blank for Tax/Transfer), `Amount` (number, major units), `Date` (Excel **date-time** to the second, `yyyy-mm-dd hh:mm:ss`), `Account` (wallet; transfers "From → To"; may be blank for pending owes), `Note`, `Owed person`, `Due date` (date-time; owes only), `Owed completed` (date-time), `Owed status` (Pending/Completed), `Tax paid` (number; income/expense only). Export rows sorted by date, Sr 1..N; file name `transactions_<from>_to_<last>.xlsx` (or `transactions_all.xlsx`).
- **Import parsing** (`decodeXlsx`): uses sheet `Transactions` else first non-empty sheet; header row = first row containing Type+Amount+Date (any order; aliases via `TxColumn.match`, case/spacing ignored; extra columns ignored); blank rows skipped. Type synonyms (outgoing, spent, lent, borrowed…); amounts from numbers or text like "Rs 1,250.50" (abs, must be ≠0); dates from Excel date / date-time cells, serial numbers (time fraction rounded to the second), and text: a date (`yyyy-mm-dd`, `dd/mm/yyyy`, `15 Nov 2026`) optionally followed (space, `T` or `,`) by a time `14:30`, `14:30:05(.fff)`, `2:30 PM` (trailing `Z`/offset ignored; invalid times are row errors); a date without time = midnight. `Due date` is kept only for owes. Rules: category required for income/expense/owes, account required except pending owes; owe status from text, or Completed when a completed date exists; completed owe needs an account; transfer account must split on →, -> or => into two different names. Bad rows become `RowIssue(rowNumber, message)`; good rows continue.
- **Duplicates** (`splitDuplicates`): key = type | account (lower-case; transfer "from>to") | amountMinor | calendar **day** (time ignored on purpose, so hand-typed dates without times still match). Compared against **all** existing rows (`store.readRows()`), **one-for-one** (multiset) so genuine repeats survive a round trip; duplicates inside the file alone are not removed.
- **Threading:** `exportTransactions` reads rows via the store, then `Isolate.run(encodeXlsx)`. `importTransactions` reads existing rows, then one `Isolate.run` does decode + duplicate split; writes happen on the main isolate through `store.writeRows` (sqflite does its own background I/O). `transactionTemplate()` = header-only file in an isolate.
- **Results:** `ExportResult{bytes, rowCount, fileName}`, `ImportSummary{rowsRead, imported, duplicates, issues (sorted by row)}`.
- Round trip is lossless for entries: dates/times to the second, owe due & completed date-times, linked tax, category paths, notes, people. (Sub-second precision is dropped.)

## 7. Tests (`test/`)
Use `sqfliteFfiInit()` + `LocalDatabase(factory: databaseFactoryFfi[NoIsolate], path: inMemoryDatabasePath)`. Widget tests use a `_settle` helper (`runAsync` delay + `pumpAndSettle`) because sqflite futures are real async. NavigationBar labels are found with `find.descendant(of: find.byType(NavigationBar), ...)`; `SliverAppBar.medium` titles appear twice (use `findsWidgets`).
- `data_layer_test.dart`: seeded defaults; v2 upgrade; balances/owing/tax/dashboard; activity merge; **category totals by month** (excludes owes and other months).
- `app_smoke_test.dart`: shell (Overview, Total balance, welcome card, nav, Add menu → Add expense / Transfer money, Reports, Settings); **end-to-end expense** (Add → Expense → amount 1250.5 → Category Food → Cash preselected → Save → "Saved", balance −125050); appearance segmented System/Light/Dark persisted.
- `formatters_test.dart`: money grouping/symbols/signs, amountInputText, relative/long dates.
- `features_test.dart` (plain `test`, `AppServices.withDatabase` + `_World` seed: Cash 10,000 + Bank, Food › Groceries; `_idle(controller)` polls `busy`): linked tax balances/move/clear/cascade + owes reject tax; v3→v4 column added; `ReportService.build` totals/accounts/months + category roll-up; report period stepping & labels; History filters (account totals, category tree, preset, tax, amount/text search); `DateRange` labels; category icon/hex color storage, validation, propagation to activity & totals; color/icon helpers; **defaults** (storage, type/category/manual priority, tax & transfer, edit ignores, archived skipped, forget on delete).
- `app_smoke_test.dart` also: expense **with tax 100** (summary note, balance −135050, `taxMinor`), and History Filters sheet → This month → "Show 1 results" → tap transfer → "Edit transfer"; Reports Year; Home account → AccountDetailScreen; Settings › Defaults pick Expense category Shopping → new expense prefilled Shopping + Cash; CategoryScreen → Food → Icon "local pizza" → Color hex 12ab9c → "#12AB9C" → Save persists `local_pizza`/`#12AB9C`.
- `data_layer_test.dart` v2 upgrade also asserts `categories` gained `icon`/`color`.
- `import_export_test.dart`: needs **separate DB files** per `AppServices` (FFI in-memory DBs are shared within a process). Seeds every entry kind (with times of day and owe due dates), exports November, imports into a fresh DB (balances, Food › Groceries, pending/completed owes, exact occurred/due/completed date-times, linked tax match; re-import = all duplicates); app-rejected row (expense on income category) reported with its row number while others import and missing wallets are created; widget test drives `ImportExportScreen` with a fake `ExcelFiles` (count, Year period, export bytes decode, import → "Last import", "Imported 0, skipped 1").
- Module tests (`packages/transaction_io/test`): run with `flutter test` inside the package.
- The test font renders wide glyphs, so it catches text overflow (a real one in the balance card was fixed this way). For visual review, a temporary test can load Roboto from `<flutter>/bin/cache/artifacts/material_fonts` and `RenderRepaintBoundary.toImage()` screens to PNG.

---

## 8. Known gaps / quirks (useful when adding features)
- Tax can't be attached to owes (only income/expense). Linked tax always uses the transaction's account and date.
- Owes: no partial repayments (settle is all-or-nothing).
- Excel import/export exists (entries only). No full backup/restore of settings, categories' icons/colors, assets or defaults; uninstall loses data. No app lock.
- Import isn't atomic: rows are saved one by one; a failed row is reported and the rest are kept.
- Production setup not done: `applicationId com.example.money_tracker`, debug signing, default launcher icon, version 0.1.0.
- History loads the whole feed into memory and filters there (fine for personal-scale data; move filters into SQL if it grows to many thousands).
- Transaction type can't be changed when editing.
- Asset ↔ purchase-expense link exists in data layer but has no UI (`purchaseTransactionId` preserved on edit).
- `CategoryRepository.childrenOf` unused.
- Archived accounts still count in Home total balance (`DashboardSummary.totalBalanceMinor`) but the "Across N accounts" text and Accounts card count only active ones; Account screen total counts active only.
- Category tree: a child whose type differs from its parent appears indented in its own type section without the parent.
- Empty note saved as `''` not `null`.
- Dates use local ISO strings; no timezone handling. No date-format setting.
- No i18n; strings are inline English.

## 9. Recent history (git)
- `3caed13` schema v3 + seed default categories/accounts
- `165f2cf` removed microfinance account type
- `cefac17` recent activity on home
- `d70eb8b` theme mode default → system
- `7b62f4d` UI component sizing refactor (app_sizes.dart)

## 10. How to add things (checklists)
- **New screen/UI:** compose only from `app_widgets.dart` components (SectionHeader + GroupedCard + AppTile/FormRow, SheetScaffold for editors, showPickerSheet for choices, EmptyState/ErrorBanner). Use `SpaceSize.gutter` margins, `AppColors` for money semantics, plain-language labels. Pushed pages need a Scaffold + AppBar. Reachable from Home or Settings › Manage.
- **New entity:** model in `data/models` (+ `part`, run build_runner) → table in `_createSchema` + migration in `_upgradeSchema` (bump version) → repo extending `CrudRepository` → field on `AppServices` → controller extending `BaseController` (call `services.changed()` after writes) → screen with `AnimatedBuilder(controller)` → navigation entry → tests.
- **New default:** add a `DefaultKind` constant, a section in `DefaultsScreen`, and apply it in the relevant controller's first `refresh()` for new entries only.
- **New setting:** key in `app_settings` via `SettingsService` getter/setter (insert-replace) → mirror on `AppServices` if global → `SettingsController` + a tile in `SettingsScreen` Preferences (picker sheet or SegmentedButton).
- **New Excel column:** add to `TxColumn` (header + aliases) and `TxRow`, write it in `_cell` and read it in `_parseRow` (xlsx_codec.dart), map it in `AppTransactionIoStore.readRows/writeRows`, extend the module round-trip test.
- **New money field:** store as `int` minor; parse with `MoneyAmount.parse`; display with `AmountText`/`money()`; prefill inputs with `amountInputText()`.
- **Affects balances?** Update `AccountRepository.balanceMinor` AND `DashboardService` AND `ReportService` (totals + `_accountFlows`) AND `ActivityService` (`netEffectMinor`/`effectOn`) consistently.
