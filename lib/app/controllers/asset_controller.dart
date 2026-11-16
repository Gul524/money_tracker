import '../../data/models/account.dart';
import '../../data/models/asset.dart';
import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import '../../data/services/defaults_service.dart';
import 'base_controller.dart';
import 'category_path.dart';
import 'money_amount.dart';

/// How an asset was acquired (optional; [owned] moves no money).
/// - [paid]: paid from a wallet → a linked expense.
/// - [owed]: bought on credit → a linked "I owe" entry.
enum AssetSource { owned, paid, owed }

class AssetController extends BaseController {
  AssetController(super.services) {
    refresh();
  }
  List<Asset> items = [];

  /// Entries assets were acquired with / given away in, by transaction id.
  Map<int, MoneyTransaction> links = {};
  List<Account> accounts = [];

  /// Categories an asset purchase can use (expense or both).
  List<Category> categories = [];
  List<Category> _allCategories = [];
  EntryDefaults defaults = const EntryDefaults();

  List<Asset> get owned => items.where((a) => !a.isGivenAway).toList();
  List<Asset> get givenAway => items.where((a) => a.isGivenAway).toList();
  int get ownedValueMinor =>
      owned.fold(0, (sum, a) => sum + a.currentValueMinor);

  MoneyTransaction? purchaseOf(Asset a) =>
      a.purchaseTransactionId == null ? null : links[a.purchaseTransactionId];
  MoneyTransaction? givenIn(Asset a) =>
      a.givenTransactionId == null ? null : links[a.givenTransactionId];

  AssetSource sourceOf(Asset? a) {
    final purchase = a == null ? null : purchaseOf(a);
    if (purchase == null) return AssetSource.owned;
    return purchase.type == TransactionType.expense
        ? AssetSource.paid
        : AssetSource.owed;
  }

  String pathFor(Category c) => categoryPath(c, _allCategories);
  String? accountName(int? id) =>
      accounts.where((a) => a.id == id).firstOrNull?.name;
  Category? category(int? id) =>
      _allCategories.where((c) => c.id == id).firstOrNull;

  /// Default category for a new purchase of this kind, if usable.
  int? defaultCategory(AssetSource source) {
    final id =
        defaults.categoryByKind[source == AssetSource.owed
            ? DefaultKind.oweOut
            : DefaultKind.expense];
    return categories.any((c) => c.id == id) ? id : null;
  }

  /// Default wallet for paying: the expense default, else the only wallet.
  int? get defaultAccount {
    final id = defaults.accountByKind[DefaultKind.expense];
    final active = accounts.where((a) => !a.isArchived).toList();
    if (active.any((a) => a.id == id)) return id;
    return active.length == 1 ? active.first.id : null;
  }

  @override
  void refresh() {
    run(() async {
      items = await services.assets.getAll();
      final ids = {
        for (final a in items) ...{
          ?a.purchaseTransactionId,
          ?a.givenTransactionId,
        },
      };
      links = {
        for (final id in ids) id: ?await services.transactions.getById(id),
      };
      accounts = await services.accounts.getAll();
      _allCategories = await services.categories.getAll();
      categories =
          _allCategories.where((c) => c.type != CategoryType.income).toList()
            ..sort((a, b) => pathFor(a).compareTo(pathFor(b)));
      defaults = await services.defaults.load();
    });
  }

  /// Saves an asset. With [source] paid/owed, the purchase entry is created
  /// (or, for an already linked asset, kept in step: amount = price paid,
  /// date = bought on).
  Future<bool> save({
    int? id,
    required String name,
    required String purchaseAmount,
    required String currentValue,
    required DateTime acquiredOn,
    String? notes,
    AssetSource source = AssetSource.owned,
    int? accountId,
    int? categoryId,
    String party = '',
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
        final existing = items.where((a) => a.id == id).firstOrNull;
        final value = Asset(
          id: id,
          name: name,
          acquiredOn: acquiredOn,
          purchaseAmountMinor: purchaseAmountMinor,
          currentValueMinor: currentValueMinor,
          notes: notes,
          purchaseTransactionId: existing?.purchaseTransactionId,
          givenTransactionId: existing?.givenTransactionId,
        );
        MoneyTransaction? purchase;
        if (source != AssetSource.owned) {
          if (purchaseAmountMinor <= 0) {
            throw ArgumentError('Enter the price paid');
          }
          if (categoryId == null) throw ArgumentError('Choose a category');
          final paid = source == AssetSource.paid;
          if (paid && accountId == null) {
            throw ArgumentError('Choose the wallet you paid from');
          }
          final linked = existing == null ? null : purchaseOf(existing);
          purchase = linked != null
              ? linked.copyWith(
                  amountMinor: purchaseAmountMinor,
                  occurredAt: acquiredOn,
                  categoryId: categoryId,
                  accountId: paid ? accountId : linked.accountId,
                  party: paid ? linked.party : party.trim(),
                )
              : MoneyTransaction(
                  type: paid ? TransactionType.expense : TransactionType.oweOut,
                  amountMinor: purchaseAmountMinor,
                  categoryId: categoryId,
                  accountId: paid ? accountId : null,
                  occurredAt: acquiredOn,
                  oweStatus: paid ? null : OweStatus.pending,
                  party: paid ? null : party.trim(),
                  note: name.trim(),
                );
        }
        await services.assets.saveWithPurchase(value, purchase: purchase);
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
