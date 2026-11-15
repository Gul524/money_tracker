import '../../data/models/account.dart';
import '../../data/models/account_transfer.dart';
import '../../data/services/defaults_service.dart';
import '../formatters.dart';
import 'base_controller.dart';
import 'money_amount.dart';

class TransferController extends BaseController {
  TransferController(super.services, {AccountTransfer? existing})
    : editing = existing {
    if (existing != null) {
      fromAccountId = existing.fromAccountId;
      toAccountId = existing.toAccountId;
      amountText = amountInputText(existing.amountMinor);
      note = existing.note ?? '';
      occurredAt = existing.occurredAt;
    }
    refresh();
  }
  final AccountTransfer? editing;
  bool _defaultsApplied = false;
  List<Account> accounts = [];
  Map<int, int> balances = {};
  int? fromAccountId;
  int? toAccountId;
  String amountText = '';
  String note = '';
  DateTime occurredAt = DateTime.now();

  @override
  void refresh() {
    run(() async {
      // Archived accounts are hidden, except ones this transfer already uses.
      accounts = (await services.accounts.getAll())
          .where(
            (a) =>
                !a.isArchived || a.id == fromAccountId || a.id == toAccountId,
          )
          .toList();
      if (editing == null && !_defaultsApplied) {
        _defaultsApplied = true;
        final defaults = (await services.defaults.load()).accountByKind;
        bool usable(int? id) =>
            id != null && accounts.any((a) => a.id == id && !a.isArchived);
        final from = defaults[DefaultKind.transferFrom];
        final to = defaults[DefaultKind.transferTo];
        if (fromAccountId == null && usable(from)) fromAccountId = from;
        if (toAccountId == null && usable(to) && to != fromAccountId) {
          toAccountId = to;
        }
      }
      balances = {
        for (final a in accounts)
          a.id!: await services.accounts.balanceMinor(a.id!),
      };
    });
  }

  void swap() {
    final from = fromAccountId;
    fromAccountId = toAccountId;
    toAccountId = from;
    changed();
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
        final transfer = AccountTransfer(
          id: editing?.id,
          fromAccountId: fromAccountId!,
          toAccountId: toAccountId!,
          amountMinor: amount,
          occurredAt: occurredAt,
          note: note.trim(),
        );
        if (editing == null) {
          await services.transfers.create(transfer);
        } else {
          await services.transfers.update(transfer);
        }
        services.changed();
        return true;
      }) ==
      true;

  Future<bool> remove() async =>
      await run(() async {
        await services.transfers.delete(editing!.id!);
        services.changed();
        return true;
      }) ==
      true;
}
