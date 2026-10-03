import '../../data/models/account.dart';
import '../../data/models/model_types.dart';
import 'base_controller.dart';
import 'money_amount.dart';

class AccountController extends BaseController {
  AccountController(super.services) {
    refresh();
  }
  List<Account> items = [];
  Map<int, int> balances = {};

  @override
  void refresh() {
    run(() async {
      items = await services.accounts.getAll();
      balances = {
        for (final a in items)
          a.id!: await services.accounts.balanceMinor(a.id!),
      };
    });
  }

  Future<bool> save({
    int? id,
    required String name,
    required AccountType type,
    required String openingBalance,
    bool isArchived = false,
  }) async {
    return await run(() async {
          final openingBalanceMinor = MoneyAmount.parse(
            openingBalance,
            allowZero: true,
            allowNegative: true,
          );
          final value = Account(
            id: id,
            name: name,
            type: type,
            openingBalanceMinor: openingBalanceMinor,
            isArchived: isArchived,
          );
          if (id == null) {
            await services.accounts.create(value);
          } else {
            await services.accounts.update(value);
          }
          services.changed();
          return true;
        }) ==
        true;
  }

  Future<bool> remove(int id) async =>
      await run(() async {
        await services.accounts.delete(id);
        services.changed();
        return true;
      }) ==
      true;
}
