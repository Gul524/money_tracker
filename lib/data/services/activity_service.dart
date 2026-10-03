import '../models/money_transaction.dart';
import '../models/model_types.dart';
import '../repo/account_repository.dart';
import '../repo/category_repository.dart';
import '../repo/tax_repository.dart';
import '../repo/transaction_repository.dart';
import '../repo/transfer_repository.dart';
import 'local_database.dart';

enum ActivityKind { transaction, tax, transfer }

class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.amountMinor,
    required this.date,
    required this.kind,
    this.isPending = false,
    this.transaction,
  });
  final String title;
  final String subtitle;
  final int amountMinor;
  final DateTime date;
  final ActivityKind kind;
  final bool isPending;
  final MoneyTransaction? transaction;
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
    final taxes = await _taxes.history(limit: limit);
    final transfers = await _transfers.history(limit: limit);
    final categories = {
      for (final c in await _categories.getAll()) c.id!: c.name,
    };
    final accounts = {for (final a in await _accounts.getAll()) a.id!: a.name};
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
        ),
      for (final t in taxes)
        ActivityItem(
          title: 'Tax payment',
          subtitle: t.note ?? 'Paid tax',
          amountMinor: -t.amountMinor,
          date: t.paidAt,
          kind: ActivityKind.tax,
        ),
      for (final t in transfers)
        ActivityItem(
          title: 'Transfer',
          subtitle:
              '${accounts[t.fromAccountId] ?? 'Account'} → ${accounts[t.toAccountId] ?? 'Account'}',
          amountMinor: t.amountMinor,
          date: t.occurredAt,
          kind: ActivityKind.transfer,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return limit == null ? items : items.take(limit).toList();
  }
}
