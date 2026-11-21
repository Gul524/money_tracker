import '../../data/models/account.dart';
import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import 'money_amount.dart';
import 'base_controller.dart';

class OweController extends BaseController {
  OweController(super.services) {
    refresh();
  }
  List<MoneyTransaction> items = [];
  List<Account> accounts = [];

  /// What each owe exchanged, e.g. `Lent from Cash` or `Gave Gold ring`.
  Map<int, String> links = {};

  /// Part payments made so far, per owe id, oldest first.
  Map<int, List<MoneyTransaction>> parts = {};

  int paidMinor(MoneyTransaction t) =>
      (parts[t.id] ?? const []).fold(0, (s, p) => s + p.amountMinor);

  /// The owe's original amount: what is still owed plus what was paid.
  int totalMinor(MoneyTransaction t) => t.amountMinor + paidMinor(t);

  List<MoneyTransaction> get owedToMe =>
      items.where((t) => t.type == TransactionType.oweIn).toList();
  List<MoneyTransaction> get iOwe =>
      items.where((t) => t.type == TransactionType.oweOut).toList();
  int get owedToMeMinor => owedToMe.fold(0, (s, t) => s + t.amountMinor);
  int get iOweMinor => iOwe.fold(0, (s, t) => s + t.amountMinor);

  @override
  void refresh() {
    run(() async {
      items = await services.transactions.pendingOwes();
      parts = await services.transactions.partsByOwe();
      accounts = await services.accounts.getAll();
      final names = {for (final a in accounts) a.id!: a.name};
      final bought = <int, String>{};
      final given = <int, String>{};
      for (final a in await services.assets.getAll()) {
        if (a.purchaseTransactionId != null) {
          bought[a.purchaseTransactionId!] = a.name;
        }
        if (a.givenTransactionId != null) given[a.givenTransactionId!] = a.name;
      }
      final incoming = TransactionType.oweIn;
      links = {
        for (final t in items)
          if (t.exchangeAccountId != null)
            t.id!: t.type == incoming
                ? 'Lent from ${names[t.exchangeAccountId]}'
                : 'Borrowed into ${names[t.exchangeAccountId]}'
          else if (t.type == incoming && given[t.id] != null)
            t.id!: 'Gave ${given[t.id]}'
          else if (t.type != incoming && bought[t.id] != null)
            t.id!: 'Got ${bought[t.id]}',
      };
    });
  }

  /// Records a payment of [amountText] against owe [id]; paying everything
  /// that is left settles it.
  Future<bool> pay(int id, int accountId, String amountText) async =>
      await run(() async {
        await services.transactions.payPart(
          id,
          MoneyAmount.parse(amountText),
          accountId,
          note: 'Part payment',
        );
        services.changed();
        return true;
      }) ==
      true;

  Future<bool> complete(int id, int accountId) async =>
      await run(() async {
        await services.transactions.completeOwe(id, accountId);
        services.changed();
        return true;
      }) ==
      true;
}
