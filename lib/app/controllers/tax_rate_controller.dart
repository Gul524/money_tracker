import '../../data/models/tax_rate.dart';
import 'base_controller.dart';
import 'money_amount.dart';

/// Settings › Tax: add, edit and delete managed taxes.
///
/// Entries keep a copy of the tax they were saved with, so edits and
/// deletes here never change old entries.
class TaxRateController extends BaseController {
  TaxRateController(super.services) {
    refresh();
  }

  List<TaxRate> items = [];

  @override
  void refresh() {
    run(() async {
      items = await services.taxRates.sorted();
    });
  }

  /// [percentage] is typed text such as `17` or `12.5`.
  Future<bool> save({
    int? id,
    required String name,
    required String code,
    required String percentage,
    required bool inclusive,
  }) async =>
      await run(() async {
        final rate = _parsePercentage(percentage);
        final value = TaxRate(
          id: id,
          name: name,
          code: code,
          rateBasisPoints: rate,
          inclusive: inclusive,
        );
        if (id == null) {
          await services.taxRates.create(value);
        } else {
          await services.taxRates.update(value);
        }
        services.changed();
        return true;
      }) ==
      true;

  Future<bool> remove(int id) async =>
      await run(() async {
        await services.taxRates.delete(id);
        services.changed();
        return true;
      }) ==
      true;

  static int _parsePercentage(String text) {
    final value = text.trim().replaceAll('%', '').trim();
    if (value.isEmpty) throw ArgumentError('Enter the tax percentage');
    try {
      // Same 2-decimal rules as money: 12.5 → 1250.
      return MoneyAmount.parse(value);
    } on ArgumentError {
      throw ArgumentError('Enter a percentage like 17 or 12.5');
    }
  }
}

/// Text for a percentage input, e.g. 1250 → `12.5`.
String percentageInputText(int basisPoints) =>
    formatRate(basisPoints).replaceAll('%', '');
