import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import '../../data/models/tax_payment.dart';
import 'base_controller.dart';
import 'category_path.dart';
import 'money_amount.dart';

enum EntryKind { income, expense, oweIn, oweOut, tax }

class TransactionController extends BaseController {
  TransactionController(super.services, {MoneyTransaction? existing})
    : editing = existing {
    if (existing != null) {
      kind = EntryKind.values.byName(existing.type.name);
      amountText = (existing.amountMinor / 100).toStringAsFixed(2);
      categoryId = existing.categoryId;
      accountId = existing.accountId;
      occurredAt = existing.occurredAt;
      dueAt = existing.dueAt;
      note = existing.note ?? '';
      party = existing.party ?? '';
    }
    refresh();
  }

  final MoneyTransaction? editing;
  List<Account> accounts = [];
  List<Category> categories = [];
  EntryKind kind = EntryKind.expense;
  String amountText = '';
  int? categoryId;
  int? accountId;
  DateTime occurredAt = DateTime.now();
  DateTime? dueAt;
  String note = '';
  String party = '';

  bool get isOwe => kind == EntryKind.oweIn || kind == EntryKind.oweOut;
  bool get isTax => kind == EntryKind.tax;
  bool get isIncome => kind == EntryKind.income || kind == EntryKind.oweIn;
  List<Category> get availableCategories => categories
      .where(
        (c) =>
            c.type == CategoryType.both ||
            c.type == (isIncome ? CategoryType.income : CategoryType.expense),
      )
      .toList();
  String pathFor(Category category) => categoryPath(category, categories);

  @override
  void refresh() {
    run(() async {
      categories = await services.categories.getAll();
      accounts = (await services.accounts.getAll())
          .where((a) => !a.isArchived)
          .toList();
    });
  }

  void setKind(EntryKind value) {
    kind = value;
    if (!availableCategories.any((c) => c.id == categoryId)) categoryId = null;
    if (!isOwe) dueAt = null;
    changed();
  }

  void setAmount(String value) {
    amountText = value;
    changed();
  }

  void setCategory(int? value) {
    categoryId = value;
    changed();
  }

  void setAccount(int? value) {
    accountId = value;
    changed();
  }

  void setNote(String value) {
    note = value;
    changed();
  }

  void setParty(String value) {
    party = value;
    changed();
  }

  void setDate(DateTime value) {
    occurredAt = value;
    changed();
  }

  void setDueDate(DateTime? value) {
    dueAt = value;
    changed();
  }

  Future<bool> save() async =>
      await run(() async {
        final amount = MoneyAmount.parse(amountText);
        if (isTax) {
          if (accountId == null) throw ArgumentError('Choose an account');
          await services.taxes.create(
            TaxPayment(
              amountMinor: amount,
              paidAt: occurredAt,
              accountId: accountId!,
              note: note.trim(),
            ),
          );
        } else {
          if (categoryId == null) throw ArgumentError('Choose a category');
          if (!isOwe && accountId == null) {
            throw ArgumentError('Choose an account');
          }
          final transaction = MoneyTransaction(
            id: editing?.id,
            type: TransactionType.values.byName(kind.name),
            amountMinor: amount,
            categoryId: categoryId!,
            accountId: accountId,
            occurredAt: occurredAt,
            dueAt: isOwe ? dueAt : null,
            oweStatus: isOwe ? (editing?.oweStatus ?? OweStatus.pending) : null,
            completedAt: isOwe ? editing?.completedAt : null,
            note: note.trim(),
            party: isOwe ? party.trim() : null,
          );
          if (editing == null) {
            await services.transactions.create(transaction);
          } else {
            await services.transactions.update(transaction);
          }
        }
        services.changed();
        return true;
      }) ==
      true;

  Future<bool> remove() async =>
      await run(() async {
        final id = editing?.id;
        if (id == null) throw StateError('Transaction is not saved');
        await services.transactions.delete(id);
        services.changed();
        return true;
      }) ==
      true;
}
