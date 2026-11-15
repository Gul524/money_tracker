import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import '../../data/models/tax_payment.dart';
import '../../data/services/defaults_service.dart';
import 'base_controller.dart';
import '../formatters.dart';
import 'category_path.dart';
import 'money_amount.dart';

enum EntryKind { income, expense, oweIn, oweOut, tax }

class TransactionController extends BaseController {
  TransactionController(
    super.services, {
    MoneyTransaction? existing,
    TaxPayment? existingTax,
    EntryKind initialKind = EntryKind.expense,
  }) : editing = existing,
       editingTax = existingTax,
       kind = initialKind {
    if (existingTax != null) {
      kind = EntryKind.tax;
      amountText = amountInputText(existingTax.amountMinor);
      accountId = existingTax.accountId;
      occurredAt = existingTax.paidAt;
      note = existingTax.note ?? '';
    }
    if (existing != null) {
      kind = EntryKind.values.byName(existing.type.name);
      amountText = amountInputText(existing.amountMinor);
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

  /// A standalone tax payment being edited.
  final TaxPayment? editingTax;
  bool get isEditing => editing != null || editingTax != null;

  /// Tax paid together with an income or expense, as typed.
  String taxText = '';

  /// Becomes true once an edited transaction's linked tax has been loaded.
  bool taxLoaded = false;

  /// Defaults from Settings › Defaults, applied to new entries only.
  EntryDefaults defaults = const EntryDefaults();
  bool _defaultsApplied = false;

  /// Set once the user picks an account, so defaults never overwrite it.
  bool _accountChosen = false;
  List<Account> accounts = [];
  List<Category> categories = [];
  Map<int, int> balances = {};
  EntryKind kind;
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

  /// Only income and expense entries can carry tax.
  bool get canHaveTax => kind == EntryKind.income || kind == EntryKind.expense;

  /// Parsed amount and tax, or null while the text isn't a valid amount.
  int? get amountMinor => _tryParse(amountText);
  int get taxMinor => _tryParse(taxText) ?? 0;

  int? _tryParse(String text) {
    if (text.trim().isEmpty) return null;
    try {
      return MoneyAmount.parse(text, allowZero: true);
    } on ArgumentError {
      return null;
    }
  }

  List<Category> get availableCategories => categories
      .where(
        (c) =>
            c.type == CategoryType.both ||
            c.type == (isIncome ? CategoryType.income : CategoryType.expense),
      )
      .toList();
  String pathFor(Category category) => categoryPath(category, categories);
  Category? get selectedCategory =>
      categories.where((c) => c.id == categoryId).firstOrNull;
  Account? get selectedAccount =>
      accounts.where((a) => a.id == accountId).firstOrNull;

  @override
  void refresh() {
    run(() async {
      categories = await services.categories.getAll();
      // Archived accounts are hidden, except one already used by this entry.
      accounts = (await services.accounts.getAll())
          .where((a) => !a.isArchived || a.id == accountId)
          .toList();
      if (editing?.id != null && !taxLoaded) {
        final tax = await services.taxes.forTransaction(editing!.id!);
        if (tax != null) taxText = amountInputText(tax.amountMinor);
      }
      taxLoaded = true;
      defaults = await services.defaults.load();
      if (!isEditing && !_defaultsApplied) {
        _defaultsApplied = true;
        _applyCategoryDefault();
        _applyAccountDefault();
      }
      balances = {
        for (final a in accounts)
          a.id!: await services.accounts.balanceMinor(a.id!),
      };
      // Preselect the only account so a first-time user has one less step.
      if (!isEditing && accountId == null && accounts.length == 1) {
        accountId = accounts.first.id;
      }
    });
  }

  void setKind(EntryKind value) {
    kind = value;
    if (!availableCategories.any((c) => c.id == categoryId)) categoryId = null;
    if (!isOwe) dueAt = null;
    if (!isEditing) {
      _applyCategoryDefault();
      _applyAccountDefault();
    }
    changed();
  }

  /// Picks the entry type's default category when none is chosen.
  void _applyCategoryDefault() {
    if (isTax || categoryId != null) return;
    final id = defaults.categoryByKind[kind.name];
    if (availableCategories.any((c) => c.id == id)) categoryId = id;
  }

  /// Picks the category's default wallet, else the entry type's, unless the
  /// user already chose one.
  void _applyAccountDefault() {
    if (_accountChosen) return;
    final byCategory = isTax || categoryId == null
        ? null
        : defaults.accountByCategory[categoryId];
    for (final id in [byCategory, defaults.accountByKind[kind.name]]) {
      if (id != null && accounts.any((a) => a.id == id && !a.isArchived)) {
        accountId = id;
        return;
      }
    }
  }

  void setAmount(String value) {
    amountText = value;
    changed();
  }

  void setCategory(int? value) {
    categoryId = value;
    if (!isEditing) _applyAccountDefault();
    changed();
  }

  void setAccount(int? value) {
    accountId = value;
    _accountChosen = true;
    changed();
  }

  void setTax(String value) {
    taxText = value;
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
          final tax = TaxPayment(
            id: editingTax?.id,
            amountMinor: amount,
            paidAt: occurredAt,
            accountId: accountId!,
            note: note.trim(),
          );
          if (editingTax == null) {
            await services.taxes.create(tax);
          } else {
            await services.taxes.update(tax);
          }
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
          final tax = canHaveTax && taxText.trim().isNotEmpty
              ? MoneyAmount.parse(taxText, allowZero: true)
              : 0;
          await services.transactions.saveWithTax(transaction, taxMinor: tax);
        }
        services.changed();
        return true;
      }) ==
      true;

  Future<bool> remove() async =>
      await run(() async {
        if (editingTax != null) {
          await services.taxes.delete(editingTax!.id!);
        } else {
          final id = editing?.id;
          if (id == null) throw StateError('Transaction is not saved');
          await services.transactions.delete(id);
        }
        services.changed();
        return true;
      }) ==
      true;
}
