# Money Tracker

An editable description of the current interface is in [ui_ux.json](ui_ux.json). Change that file and share it to request UI updates; the app does not load the JSON at runtime.

UI dimensions are centralized in [lib/app/app_sizes.dart](lib/app/app_sizes.dart). Edit `TextSize.extraLarge`, `CardSize.large`, `IconSize.medium`, `RadiusSize.extraLarge`, `SpaceSize.section`, or `ComponentSize.centerActionHeight` to adjust the corresponding sizes across the app. Cards grow with their content; `CardSize` controls their inner padding rather than setting a fixed card height. Flutter still applies the device's accessibility text scaling.

A local first mobile app for recording income, expenses, money owed to you, money you owe, tax payments, transfers, accounts, and assets. The app now has a Flutter UI backed by controllers and SQLite repositories.

## Product and UI plan

The dashboard leads with total account balance and monthly net, followed by income and expenses, outstanding amounts, assets, tax, account balances, and the five most recent transactions, tax payments, or transfers. Owe, Accounts, and Assets open from their overview sections; Categories are available from the transaction form. The floating, rounded bottom bar has Home, History, an elevated split action control, Reports, and Settings. The control's left **+** button opens a new transaction; its right **↔** button opens a transfer. Tax payments are entered from the transaction screen as a distinct record type.

```text
Home   History   ┌─────┬─────┐   Reports   Settings
                 │  +  │  ↔  │
                 └─────┴─────┘
```

| Screen | Purpose |
| --- | --- |
| Dashboard | Total balance and monthly net; income, expense, and tax paid; pending owe in/out; account balances; asset value; five recent activity entries with a link to History. |
| Add / manage transaction | Record income, expense, owe in, or owe out. Require category; allow optional nested subcategory, note, and party. Select an account for immediate money movement. |
| Categories | Create, rename, and delete income, expense, or both categories at any depth. A parent and any nested category can be selected for a transaction. |
| Accounts | CRUD for cash, bank, and microfinance accounts; show calculated balance and allow archiving. |
| Assets | CRUD for held items, acquisition cost, estimated current value, and optional linked purchase expense. |
| History | Show transactions, tax payments, and transfers in date order; open transactions for editing or deletion. Search and filters are future work. |
| Reports | Show current month income, expenses, tax paid, and net, plus current balances, pending owes, and asset value. |
| Transfer | Move an amount between two different accounts without changing income or expense totals. |
| Owe | Show pending owed amounts and due dates; complete an owe against an account. |
| Settings | Choose a display currency and light, dark, or device appearance; see local storage information. Date format preferences are future work. |

## Data rules

- Amounts use integer **minor currency units** (for example, cents or paisa). The UI chooses a currency and formats amounts; no currency conversion exists yet.
- A transaction has exactly one category ID. Its category must permit the transaction direction: income/owe in use income or both; expense/owe out use expense or both. The selected category may be at any depth.
- Income and expense require an account and immediately affect its balance. Pending owes have no balance effect. Completing an owe requires an account and completion date; owe in increases that balance and owe out decreases it.
- Tax is stored as a separate paid tax record, requires an account, and reduces that account balance. It is not counted again as an expense transaction. Dashboard tax totals use the payment date.
- Assets have an acquisition cost and a current value. An asset may link to one expense transaction for its purchase. Asset records alone do not change cash balances, avoiding a duplicate debit.
- Transfers move the same amount out of one account and into another. They do not affect income, expenses, or tax totals.
- Account balances are calculated from opening balance, completed money movements, and tax payments. Deleting a referenced category, account, or transaction is restricted by SQLite foreign keys. The UI should offer archiving or a reassignment flow where deletion is unavailable.
- Dashboard income and expense totals use transaction occurrence dates within the current month. Pending owe totals and asset value represent the current outstanding/held amounts, regardless of month.

## Code layout

```text
lib/data/models/       JSON serializable entities, enums, copyWith
lib/data/services/     SQLite schema/connection, dashboard and settings
lib/data/repo/         Shared CRUD implementation and entity repositories
lib/app/controllers/   Screen state, validation and repository calls
lib/app/screens/       Navigation and screen-specific presentation
lib/app/widgets/       Shared cards, rows, fields and date controls
```

`LocalDatabase` owns the database connection and schema. Category, Account, Transaction, Asset, Tax, and Transfer repositories expose `create`, `getById`, `getAll`, `update`, and `delete`, plus focused queries. Shared behavior lives in `CrudRepository`. Screen controllers call repositories and services; screens pass user input to controllers and render their state. Shared interaction widgets accept `isViewOnly` to render values without editing.

The SQLite schema is version 2. IDs link categories to their parent, transactions to categories/accounts, assets to optional purchase transactions, tax payments to accounts, and transfers to both accounts. Existing version 1 databases are upgraded in place. Foreign keys are enabled on every connection.

## Development

```sh
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

The generated `*.g.dart` files implement `fromJson` and `toJson`. When a model changes, rerun the generator. SQLite uses `sqflite`; desktop support is not configured. Display currency defaults to PKR and can be changed in Settings. Changing it changes the label only; saved amounts are not converted. Appearance defaults to System, which follows the device's light or dark setting. Choose Light, Dark, or System in Settings; the choice is saved locally.
