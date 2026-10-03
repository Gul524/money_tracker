import '../../data/models/account.dart';
import '../../data/models/account_transfer.dart';
import 'base_controller.dart';
import 'money_amount.dart';

class TransferController extends BaseController {
  TransferController(super.services) {
    refresh();
  }
  List<Account> accounts = [];
  int? fromAccountId;
  int? toAccountId;
  String amountText = '';
  String note = '';
  DateTime occurredAt = DateTime.now();

  @override
  void refresh() {
    run(() async {
      accounts = (await services.accounts.getAll())
          .where((a) => !a.isArchived)
          .toList();
    });
  }

  void setFrom(int? value) {
    fromAccountId = value;
    changed();
  }

  void setTo(int? value) {
    toAccountId = value;
    changed();
  }

  void setAmount(String value) {
    amountText = value;
    changed();
  }

  void setNote(String value) {
    note = value;
    changed();
  }

  void setDate(DateTime value) {
    occurredAt = value;
    changed();
  }

  Future<bool> save() async =>
      await run(() async {
        if (fromAccountId == null || toAccountId == null) {
          throw ArgumentError('Choose both accounts');
        }
        final amount = MoneyAmount.parse(amountText);
        await services.transfers.create(
          AccountTransfer(
            fromAccountId: fromAccountId!,
            toAccountId: toAccountId!,
            amountMinor: amount,
            occurredAt: occurredAt,
            note: note.trim(),
          ),
        );
        services.changed();
        return true;
      }) ==
      true;
}
