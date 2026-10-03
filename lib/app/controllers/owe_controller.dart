import '../../data/models/account.dart';
import '../../data/models/money_transaction.dart';
import 'base_controller.dart';

class OweController extends BaseController {
  OweController(super.services) {
    refresh();
  }
  List<MoneyTransaction> items = [];
  List<Account> accounts = [];

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
