import '../../data/models/account_transfer.dart';
import '../../data/models/category.dart';
import '../../data/models/money_transaction.dart';
import '../../data/models/model_types.dart';
import '../../data/models/tax_payment.dart';
import 'base_controller.dart';

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

class HistoryController extends BaseController {
  HistoryController(super.services) {
    refresh();
  }
  List<MoneyTransaction> transactions = [];
  List<TaxPayment> taxes = [];
  List<AccountTransfer> transfers = [];
  Map<int, Category> categories = {};
  List<ActivityItem> items = [];

  @override
  void refresh() {
    run(() async {
      transactions = await services.transactions.history();
      taxes = await services.taxes.getAll();
      transfers = await services.transfers.history();
      categories = {
        for (final c in await services.categories.getAll()) c.id!: c,
      };
      final accounts = {
        for (final a in await services.accounts.getAll()) a.id!: a.name,
      };
      items = [
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
    });
  }
}
