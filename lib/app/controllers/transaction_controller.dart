import '../../data/models/account.dart';
import '../../data/models/asset.dart';
import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import '../../data/models/tax_payment.dart';
import '../../data/models/tax_rate.dart';
import '../../data/repo/transaction_repository.dart';
import '../../data/services/defaults_service.dart';
import 'base_controller.dart';
import '../formatters.dart';
import 'category_path.dart';
import 'money_amount.dart';

enum EntryKind { income, expense, oweIn, oweOut, tax }

/// What changed hands when an owe started (optional):
/// - [money]: lent from a wallet (owed to me) / borrowed into one (I owe).
/// - [item]: an asset given away (owed to me) / a thing received (I owe).
enum OweExchange { none, money, item }

/// How tax is added to an income or expense:
/// - [rate]: worked out from a managed tax's percentage.
/// - [custom]: an amount typed by the user.
enum TaxMode { none, rate, custom }

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
      if (existingTax.label != null) {
        selectedTax = TaxDetails(
          taxRateId: existingTax.taxRateId,
          name: existingTax.taxName,
          code: existingTax.taxCode,
          rateBasisPoints: existingTax.rateBasisPoints,
        );
      }
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
      exchangeAccountId = existing.exchangeAccountId;
      if (exchangeAccountId != null) exchange = OweExchange.money;
    }
    refresh();
  }

  final MoneyTransaction? editing;

  /// A standalone tax payment being edited.
  final TaxPayment? editingTax;
  bool get isEditing => editing != null || editingTax != null;

  /// Custom tax amount, as typed ([TaxMode.custom]).
  String taxText = '';

  TaxMode taxMode = TaxMode.none;

  /// The tax picked for this entry, copied from the managed tax when it was
  /// picked (or from the saved entry), so later edits of the tax don't
  /// change it. For a standalone tax payment it only names the tax.
  TaxDetails? selectedTax;

  /// Whether the typed amount already includes the tax.
  bool taxInclusive = false;

  /// Managed taxes (Settings › Tax).
  List<TaxRate> taxRates = [];

  /// Bumped when the controller rewrites [amountText] (an edited entry's
  /// amount is shown with or without its tax), so the screen can sync.
  int amountRevision = 0;

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

  /// Optional other side of an owe (see [OweExchange]).
  OweExchange exchange = OweExchange.none;
  int? exchangeAccountId;
  int? givenAssetId;
  String receivedItem = '';

  /// Set once an edited owe's linked item has been loaded.
  bool itemLoaded = false;

  /// Assets that can be given away (owned, or already given in this entry).
  List<Asset> assets = [];

  bool get isOwe => kind == EntryKind.oweIn || kind == EntryKind.oweOut;
  bool get isTax => kind == EntryKind.tax;
  bool get isIncome => kind == EntryKind.income || kind == EntryKind.oweIn;

  /// Only income and expense entries can carry tax.
  bool get canHaveTax => kind == EntryKind.income || kind == EntryKind.expense;

  /// Parsed amount, or null while the text isn't a valid amount.
  int? get amountMinor => _tryParse(amountText);

  /// The typed amount split into subtotal and tax.
  TaxSplit get taxSplit {
    final amount = amountMinor ?? 0;
    if (!canHaveTax) return TaxSplit(amount, 0);
    switch (taxMode) {
      case TaxMode.none:
        return TaxSplit(amount, 0);
      case TaxMode.rate:
        return splitTax(
          amount,
          selectedTax?.rateBasisPoints ?? 0,
          inclusive: taxInclusive,
        );
      case TaxMode.custom:
        final tax = _tryParse(taxText) ?? 0;
        return taxInclusive
            ? TaxSplit(amount - tax, tax)
            : TaxSplit(amount, tax);
    }
  }

  int get taxMinor => taxSplit.taxMinor;

  /// e.g. `GST 17%`, `Custom`, or null when there is no tax.
  String? get taxLabel => switch (taxMode) {
    TaxMode.none => null,
    TaxMode.custom => 'Custom',
    TaxMode.rate => [
      selectedTax?.code ?? selectedTax?.name ?? 'Tax',
      if (selectedTax?.rateBasisPoints != null)
        formatRate(selectedTax!.rateBasisPoints!),
    ].join(' '),
  };

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
  Account? get exchangeAccount =>
      accounts.where((a) => a.id == exchangeAccountId).firstOrNull;
  Asset? get givenAsset =>
      assets.where((a) => a.id == givenAssetId).firstOrNull;

  /// Part payments already made against the owe being edited.
  List<MoneyTransaction> parts = [];

  @override
  void refresh() {
    run(() async {
      final owe = editing?.id;
      parts = owe == null
          ? []
          : (await services.transactions.partsByOwe())[owe] ?? [];
      categories = await services.categories.getAll();
      // Archived accounts are hidden, except one already used by this entry.
      accounts = (await services.accounts.getAll())
          .where(
            (a) =>
                !a.isArchived || a.id == accountId || a.id == exchangeAccountId,
          )
          .toList();
      assets = (await services.assets.getAll())
          .where(
            (a) =>
                !a.isGivenAway ||
                (editing?.id != null && a.givenTransactionId == editing!.id),
          )
          .toList();
      final id = editing?.id;
      if (id != null && !itemLoaded && exchange == OweExchange.none) {
        if (editing!.type == TransactionType.oweIn) {
          final given = await services.assets.givenIn(id);
          if (given != null) {
            exchange = OweExchange.item;
            givenAssetId = given.id;
          }
        } else if (editing!.type == TransactionType.oweOut) {
          final got = await services.assets.purchasedWith(id);
          if (got != null) {
            exchange = OweExchange.item;
            receivedItem = got.name;
          }
        }
      }
      itemLoaded = true;
      taxRates = await services.taxRates.sorted();
      if (editing?.id != null && !taxLoaded) {
        final tax = await services.taxes.forTransaction(editing!.id!);
        if (tax != null) _loadLinkedTax(editing!, tax);
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

  /// Shows an edited entry's tax the way it was entered.
  void _loadLinkedTax(MoneyTransaction tx, TaxPayment tax) {
    final isExpense = tx.type == TransactionType.expense;
    // Entries saved before tax management: an expense's amount was before
    // tax and an income's included it.
    taxInclusive = tax.inclusive ?? !isExpense;
    if (tax.rateBasisPoints != null) {
      taxMode = TaxMode.rate;
      selectedTax = TaxDetails(
        taxRateId: tax.taxRateId,
        name: tax.taxName,
        code: tax.taxCode,
        rateBasisPoints: tax.rateBasisPoints,
        inclusive: taxInclusive,
      );
    } else {
      taxMode = TaxMode.custom;
      taxText = amountInputText(tax.amountMinor);
    }
    final subtotal = isExpense
        ? tx.amountMinor
        : tx.amountMinor - tax.amountMinor;
    amountText = amountInputText(
      taxInclusive ? subtotal + tax.amountMinor : subtotal,
    );
    amountRevision++;
  }

  /// Uses [rate]'s current percentage; its "includes tax" setting becomes
  /// the starting choice.
  void setTaxRate(TaxRate rate) {
    selectedTax = TaxDetails(
      taxRateId: rate.id,
      name: rate.name,
      code: rate.code,
      rateBasisPoints: rate.rateBasisPoints,
      inclusive: rate.inclusive,
    );
    if (!isTax) {
      taxMode = TaxMode.rate;
      taxInclusive = rate.inclusive;
    }
    changed();
  }

  void setCustomTax() {
    taxMode = TaxMode.custom;
    selectedTax = null;
    changed();
  }

  void clearTax() {
    taxMode = TaxMode.none;
    selectedTax = null;
    taxText = '';
    changed();
  }

  void setTaxInclusive(bool value) {
    taxInclusive = value;
    changed();
  }

  void setKind(EntryKind value) {
    kind = value;
    if (!availableCategories.any((c) => c.id == categoryId)) categoryId = null;
    if (!isOwe) dueAt = null;
    if (!isOwe) exchange = OweExchange.none;
    // An item given and an item received are different things.
    givenAssetId = null;
    receivedItem = '';
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

  void setExchange(OweExchange value) {
    exchange = value;
    changed();
  }

  void setExchangeAccount(int? value) {
    exchangeAccountId = value;
    changed();
  }

  void setGivenAsset(int? value) {
    givenAssetId = value;
    changed();
  }

  void setReceivedItem(String value) {
    receivedItem = value;
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
            taxRateId: selectedTax?.taxRateId,
            taxName: selectedTax?.name,
            taxCode: selectedTax?.code,
            rateBasisPoints: selectedTax?.rateBasisPoints,
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
          final lendsMoney = isOwe && exchange == OweExchange.money;
          if (lendsMoney && exchangeAccountId == null) {
            throw ArgumentError(
              kind == EntryKind.oweIn
                  ? 'Choose the wallet the money left'
                  : 'Choose the wallet the money went into',
            );
          }
          OweItem? item;
          if (isOwe && exchange == OweExchange.item) {
            if (kind == EntryKind.oweIn) {
              if (givenAssetId == null) {
                throw ArgumentError('Choose the item you gave');
              }
              item = OweItem.given(givenAssetId!);
            } else {
              if (receivedItem.trim().isEmpty) {
                throw ArgumentError('Name the item you got');
              }
              item = OweItem.received(receivedItem.trim());
            }
          }
          if (canHaveTax &&
              taxMode == TaxMode.custom &&
              taxText.trim().isNotEmpty) {
            MoneyAmount.parse(taxText, allowZero: true); // reports bad input
          }
          final split = taxSplit;
          if (split.subtotalMinor <= 0) {
            throw ArgumentError('Tax must be less than the amount');
          }
          // An expense stores its amount before tax (the wallet pays amount +
          // tax); an income stores it with tax (the wallet keeps amount − tax).
          final stored = switch (kind) {
            EntryKind.expense => split.subtotalMinor,
            EntryKind.income => split.totalMinor,
            _ => amount,
          };
          final transaction = MoneyTransaction(
            id: editing?.id,
            type: TransactionType.values.byName(kind.name),
            amountMinor: stored,
            categoryId: categoryId!,
            accountId: accountId,
            occurredAt: occurredAt,
            dueAt: isOwe ? dueAt : null,
            oweStatus: isOwe ? (editing?.oweStatus ?? OweStatus.pending) : null,
            completedAt: isOwe ? editing?.completedAt : null,
            note: note.trim(),
            party: isOwe ? party.trim() : null,
            exchangeAccountId: lendsMoney ? exchangeAccountId : null,
          );
          await services.transactions.saveWithTax(
            transaction,
            taxMinor: split.taxMinor,
            taxDetails: !canHaveTax
                ? null
                : switch (taxMode) {
                    TaxMode.none => null,
                    TaxMode.custom => TaxDetails.custom(
                      inclusive: taxInclusive,
                    ),
                    TaxMode.rate => TaxDetails(
                      taxRateId: selectedTax?.taxRateId,
                      name: selectedTax?.name,
                      code: selectedTax?.code,
                      rateBasisPoints: selectedTax?.rateBasisPoints,
                      inclusive: taxInclusive,
                    ),
                  },
            item: item,
          );
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
