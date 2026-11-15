import '../models/account_transfer.dart';
import '../models/money_transaction.dart';
import '../models/model_types.dart';
import '../models/tax_payment.dart';
import '../repo/account_repository.dart';
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

  String get note => switch (kind) {
    ActivityKind.transaction => transaction?.note ?? '',
    ActivityKind.tax => tax?.note ?? '',
    ActivityKind.transfer => transfer?.note ?? '',
  };

  String get party => transaction?.party ?? '';

  /// What this entry did to the user's money overall: transfers and pending
  /// owes change nothing; linked tax is included.
  int get netEffectMinor {
    if (kind == ActivityKind.transfer || isPending) return 0;
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
    return netEffectMinor;
  }
}

class ActivityService {
  ActivityService(LocalDatabase storage)
    : _transactions = TransactionRepository(storage),
      _taxes = TaxRepository(storage),
      _transfers = TransferRepository(storage),
      _categories = CategoryRepository(storage),
      _accounts = AccountRepository(storage);

  final TransactionRepository _transactions;
  final TaxRepository _taxes;
  final TransferRepository _transfers;
  final CategoryRepository _categories;
  final AccountRepository _accounts;

  Future<List<ActivityItem>> history({int? limit}) async {
    final transactions = await _transactions.history(limit: limit);
    final taxes = await _taxes.history();
    final transfers = await _transfers.history(limit: limit);
    final categories = {
      for (final c in await _categories.getAll()) c.id!: c.name,
    };
    final accounts = {for (final a in await _accounts.getAll()) a.id!: a.name};
    final linkedTax = {
      for (final t in taxes)
        if (t.transactionId != null) t.transactionId!: t.amountMinor,
    };
    final standaloneTax = taxes.where((t) => t.transactionId == null);

    final items = <ActivityItem>[
      for (final t in transactions)
        ActivityItem(
          title: categories[t.categoryId] ?? 'Category',
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
          accountIds: {?t.accountId},
          accountName: t.accountId == null ? null : accounts[t.accountId],
          categoryId: t.categoryId,
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
