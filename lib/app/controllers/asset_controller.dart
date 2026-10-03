import '../../data/models/asset.dart';
import 'base_controller.dart';
import 'money_amount.dart';

class AssetController extends BaseController {
  AssetController(super.services) {
    refresh();
  }
  List<Asset> items = [];

  @override
  void refresh() {
    run(() async {
      items = await services.assets.getAll();
    });
  }

  Future<bool> save({
    int? id,
    required String name,
    required String purchaseAmount,
    required String currentValue,
    required DateTime acquiredOn,
    String? notes,
    int? purchaseTransactionId,
  }) async =>
      await run(() async {
        final purchaseAmountMinor = MoneyAmount.parse(
          purchaseAmount,
          allowZero: true,
        );
        final currentValueMinor = MoneyAmount.parse(
          currentValue,
          allowZero: true,
        );
        final value = Asset(
          id: id,
          name: name,
          acquiredOn: acquiredOn,
          purchaseAmountMinor: purchaseAmountMinor,
          currentValueMinor: currentValueMinor,
          notes: notes,
          purchaseTransactionId: purchaseTransactionId,
        );
        if (id == null) {
          await services.assets.create(value);
        } else {
          await services.assets.update(value);
        }
        services.changed();
        return true;
      }) ==
      true;

  Future<bool> remove(int id) async =>
      await run(() async {
        await services.assets.delete(id);
        services.changed();
        return true;
      }) ==
      true;
}
