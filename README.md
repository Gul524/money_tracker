# Money Tracker

An editable description of the current interface is in [ui_ux.json](ui_ux.json). Change that file and share it to request UI updates; the app does not load the JSON at runtime.

UI dimensions are centralized in [lib/app/app_sizes.dart](lib/app/app_sizes.dart) on a 4 dp grid (`TextSize`, `CardSize`, `IconSize`, `RadiusSize`, `SpaceSize`, `ComponentSize`). Colors and component styles live in [lib/app/app_theme.dart](lib/app/app_theme.dart); finance colors (income, expense, transfer, warning) are the `AppColors` theme extension. Flutter still applies the device's accessibility text scaling.

A local first mobile app for recording income, expenses, money owed to you, money you owe, tax payments, transfers, accounts, and assets. The app now has a Flutter UI backed by controllers and SQLite repositories.

## Product and UI plan

The design follows Material 3 and Apple's Human Interface Guidelines: neutral inset-grouped lists, one brand-colored hero surface, readable type, plain language, and 48 dp touch targets. The standard bottom navigation bar has Home, History, Reports, and Settings. A single **+ Add** button (on Home, History and Money owed) opens a menu that names each choice plainly: Expense, Income, Transfer, Someone owes me, I owe someone, Tax payment. Settings is the hub for Accounts, Categories, Money owed, and Assets.

```text
┌──────────────────────────────┐
│ Overview                     │
│ ┌──────────────────────────┐ │
│ │ Total balance            │ │
│ │ Rs 262,851.00            │ │
│ └──────────────────────────┘ │
│ This month   [Income][Spent] │
│ Money owed   [To you][You owe]│
│ Accounts / Recent activity   │
│                    ( + Add ) │
├──────────────────────────────┤
│ Home  History  Reports  Settings│
└──────────────────────────────┘
```

| Screen | Purpose |
| --- | --- |
| Home | Total balance and net this month; income and spending; money owed; accounts; five recent entries; assets and tax. A welcome card guides first-time users. |
| Add menu | Choose what to record in plain words; Expense and Income are the largest targets. |
| Transaction | Large amount entry, type chips, then Category, Account, Date (and Person and Due date for owes) as tappable rows. Save stays above the keyboard. Edit and delete existing entries. |
| Transfer | Amount, From and To accounts with a swap button, date, and note. |
| History | Every entry grouped by day with a daily net; search, and filter chips for Expenses, Income, Transfers, Owed, and Tax. |
| Reports | Pick a month; see net, income versus outflow, spending and income by category, and where you stand today, including net worth. |
| Settings | Currency, appearance (System, Light, Dark), links to Accounts, Categories, Money owed, and Assets, and privacy information. |
| Accounts | Active and archived cash and bank accounts with balances; edit, archive, or delete in a sheet. |
| Categories | Expense, income, and shared categories shown as an indented tree; rename, move, or delete. |
| Money owed | Pending amounts owed to you and by you, with overdue items in red; mark them as received or paid into an account. |
| Assets | Things you own, their value, and gain or loss. |

## Data rules

- Amounts use integer **minor currency units** (for example, cents or paisa). The UI chooses a currency and formats amounts; no currency conversion exists yet.
- A transaction has exactly one category ID. Its category must permit the transaction direction: income/owe in use income or both; expense/owe out use expense or both. The selected category may be at any depth.
- The app starts with income categories Salary, Business, and Bonus; expense categories Food, Shopping, Phone, Donation, Gifts, and Education; and a Cash account with a zero opening balance. Existing databases receive any missing defaults once when upgraded. These are ordinary records and can be edited or deleted.
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
lib/app/widgets/       Design-system components (GroupedCard, AppTile, FormRow, pickers, sheets)
lib/app/formatters.dart  Money and date formatting
```

`LocalDatabase` owns the database connection and schema. Category, Account, Transaction, Asset, Tax, and Transfer repositories expose `create`, `getById`, `getAll`, `update`, and `delete`, plus focused queries. Shared behavior lives in `CrudRepository`. Screen controllers call repositories and services; screens pass user input to controllers and render their state. Screens are built only from the shared components in `app_widgets.dart`, so spacing and styling stay consistent.

The SQLite schema is version 3. IDs link categories to their parent, transactions to categories/accounts, assets to optional purchase transactions, tax payments to accounts, and transfers to both accounts. Existing version 1 and 2 databases are upgraded in place. Foreign keys are enabled on every connection.

## Development

```sh
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

The generated `*.g.dart` files implement `fromJson` and `toJson`. When a model changes, rerun the generator. SQLite uses `sqflite`; desktop support is not configured. Display currency defaults to PKR and can be changed in Settings. Changing it changes the label only; saved amounts are not converted. Appearance defaults to System, which follows the device's light or dark setting. Choose Light, Dark, or System in Settings; the choice is saved locally.
