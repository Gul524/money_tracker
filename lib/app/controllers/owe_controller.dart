import '../../data/models/account.dart';
import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import 'base_controller.dart';

class OweController extends BaseController {
  OweController(super.services) {
    refresh();
  }
  List<MoneyTransaction> items = [];
  List<Account> accounts = [];

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
      accounts = await services.accounts.getAll();
    });
  }

  Future<bool> complete(int id, int accountId) async =>
      await run(() async {
        await services.transactions.completeOwe(id, accountId);
        services.changed();
        return true;
      }) ==
      true;
}
