import '../models/account_transfer.dart';
import '../models/money_transaction.dart';
import '../models/model_types.dart';
import '../models/tax_payment.dart';
import '../repo/account_repository.dart';
import '../repo/asset_repository.dart';
import '../repo/category_repository.dart';
import '../repo/tax_repository.dart';
import '../repo/transaction_repository.dart';
import '../repo/transfer_repository.dart';
import 'local_database.dart';

enum ActivityKind { transaction, tax, transfer }

/// One row of the merged activity feed (transactions, tax, transfers).
class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.amountMinor,
    required this.date,
    required this.kind,
    this.isPending = false,
    this.transaction,
    this.tax,
    this.transfer,
    this.taxMinor = 0,
    this.accountIds = const {},
    this.accountName,
    this.categoryId,
    this.categoryIcon,
    this.categoryColor,
    this.linkLabel,
  });

  final String title;
  final String subtitle;

  /// Signed: + money in, − money out. Transfers are positive.
  final int amountMinor;
  final DateTime date;
  final ActivityKind kind;
  final bool isPending;
  final MoneyTransaction? transaction;

  /// Set for standalone tax payments.
  final TaxPayment? tax;
  final AccountTransfer? transfer;

  /// Tax recorded together with this transaction (0 when none).
  final int taxMinor;

  /// Accounts this entry touches (both sides for a transfer).
  final Set<int> accountIds;

  /// Display name of the account, e.g. `Cash` or `Cash → Bank`.
  final String? accountName;
  final int? categoryId;

  /// The category's chosen icon key and `#RRGGBB` color (null = automatic).
  final String? categoryIcon;
  final String? categoryColor;

  /// The other side of the entry, e.g. `Lent from Cash`, `Borrowed into
  /// Bank`, `Gave Gold ring`, `Got Laptop`, `Bought Desk`. Null when none.
  final String? linkLabel;

  bool get isOwe =>
      transaction?.type == TransactionType.oweIn ||
      transaction?.type == TransactionType.oweOut;

  String get note => switch (kind) {
    ActivityKind.transaction => transaction?.note ?? '',
    ActivityKind.tax => tax?.note ?? '',
    ActivityKind.transfer => transfer?.note ?? '',
  };

  String get party => transaction?.party ?? '';

  /// What this entry did to the user's wallets overall: transfers change
  /// nothing; linked tax is included. An owe counts money lent/borrowed when
  /// it started and money received/repaid once settled (so a settled loan of
  /// money nets to 0).
  int get netEffectMinor {
    if (kind == ActivityKind.transfer) return 0;
    if (isOwe) {
      final t = transaction!;
      return (isPending ? 0 : amountMinor) -
          (t.exchangeAccountId == null ? 0 : amountMinor);
    }
    if (isPending) return 0;
    return amountMinor - taxMinor;
  }

  /// Effect of this entry on one account's balance.
  int effectOn(int accountId) {
    if (!accountIds.contains(accountId)) return 0;
    if (kind == ActivityKind.transfer) {
      return transfer!.toAccountId == accountId
          ? transfer!.amountMinor
          : -transfer!.amountMinor;
    }
    if (isOwe) {
      final t = transaction!;
      return (!isPending && t.accountId == accountId ? amountMinor : 0) -
          (t.exchangeAccountId == accountId ? amountMinor : 0);
    }
    return netEffectMinor;
  }
}

class ActivityService {
  ActivityService(LocalDatabase storage)
    : _transactions = TransactionRepository(storage),
      _taxes = TaxRepository(storage),
      _transfers = TransferRepository(storage),
      _categories = CategoryRepository(storage),
      _accounts = AccountRepository(storage),
      _assets = AssetRepository(storage);

  final TransactionRepository _transactions;
  final TaxRepository _taxes;
  final TransferRepository _transfers;
  final CategoryRepository _categories;
  final AccountRepository _accounts;
  final AssetRepository _assets;

  Future<List<ActivityItem>> history({int? limit}) async {
    final transactions = await _transactions.history(limit: limit);
    final taxes = await _taxes.history();
    final transfers = await _transfers.history(limit: limit);
    final categories = {for (final c in await _categories.getAll()) c.id!: c};
    final accounts = {for (final a in await _accounts.getAll()) a.id!: a.name};
    final linkedTax = {
      for (final t in taxes)
        if (t.transactionId != null) t.transactionId!: t.amountMinor,
    };
    final standaloneTax = taxes.where((t) => t.transactionId == null);
    final bought = <int, String>{};
    final given = <int, String>{};
    for (final a in await _assets.getAll()) {
      if (a.purchaseTransactionId != null) {
        bought[a.purchaseTransactionId!] = a.name;
      }
      if (a.givenTransactionId != null) given[a.givenTransactionId!] = a.name;
    }
    String? link(MoneyTransaction t) => switch (t.type) {
      TransactionType.oweIn =>
        t.exchangeAccountId != null
            ? 'Lent from ${accounts[t.exchangeAccountId] ?? 'account'}'
            : given[t.id] == null
            ? null
            : 'Gave ${given[t.id]}',
      TransactionType.oweOut =>
        t.exchangeAccountId != null
            ? 'Borrowed into ${accounts[t.exchangeAccountId] ?? 'account'}'
            : bought[t.id] == null
            ? null
            : 'Got ${bought[t.id]}',
      TransactionType.expense =>
        bought[t.id] == null ? null : 'Bought ${bought[t.id]}',
      TransactionType.income => null,
    };

    final items = <ActivityItem>[
      for (final t in transactions)
        ActivityItem(
          title: categories[t.categoryId]?.name ?? 'Category',
          subtitle: switch (t.type) {
            TransactionType.income => 'Income',
            TransactionType.expense => 'Expense',
            TransactionType.oweIn =>
              t.oweStatus == OweStatus.completed
                  ? 'Received owe'
                  : 'Owed to you',
            TransactionType.oweOut =>
              t.oweStatus == OweStatus.completed ? 'Repaid owe' : 'You owe',
          },
          amountMinor:
              t.type == TransactionType.income ||
                  t.type == TransactionType.oweIn
              ? t.amountMinor
              : -t.amountMinor,
          date: t.occurredAt,
          kind: ActivityKind.transaction,
          isPending: t.oweStatus == OweStatus.pending,
          transaction: t,
          taxMinor: linkedTax[t.id] ?? 0,
          accountIds: {?t.accountId, ?t.exchangeAccountId},
          accountName: t.accountId == null ? null : accounts[t.accountId],
          categoryId: t.categoryId,
          categoryIcon: categories[t.categoryId]?.icon,
          categoryColor: categories[t.categoryId]?.color,
          linkLabel: link(t),
        ),
      for (final t in limit == null ? standaloneTax : standaloneTax.take(limit))
        ActivityItem(
          title: 'Tax payment',
          subtitle: (t.note ?? '').trim().isEmpty ? 'Paid tax' : t.note!,
          amountMinor: -t.amountMinor,
          date: t.paidAt,
          kind: ActivityKind.tax,
          tax: t,
          accountIds: {t.accountId},
          accountName: accounts[t.accountId],
        ),
      for (final t in transfers)
        _transferItem(
          t,
          '${accounts[t.fromAccountId] ?? 'Account'} → '
          '${accounts[t.toAccountId] ?? 'Account'}',
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return limit == null ? items : items.take(limit).toList();
  }

  ActivityItem _transferItem(AccountTransfer t, String route) => ActivityItem(
    title: 'Transfer',
    subtitle: route,
    amountMinor: t.amountMinor,
    date: t.occurredAt,
    kind: ActivityKind.transfer,
    transfer: t,
    accountIds: {t.fromAccountId, t.toAccountId},
    accountName: route,
  );
}
