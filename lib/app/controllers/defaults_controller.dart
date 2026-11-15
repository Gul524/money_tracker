import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import '../../data/services/defaults_service.dart';
import 'base_controller.dart';
import 'category_path.dart';

/// Settings › Defaults: preselected category and wallet per entry type, and
/// a wallet per category.
class DefaultsController extends BaseController {
  DefaultsController(super.services) {
    refresh();
  }

  EntryDefaults defaults = const EntryDefaults();

  /// Wallets that can be chosen (not archived).
  List<Account> accounts = [];
  List<Category> categories = [];

  @override
  void refresh() {
    run(() async {
      defaults = await services.defaults.load();
      accounts = (await services.accounts.getAll())
          .where((a) => !a.isArchived)
          .toList();
      categories = await services.categories.getAll();
    });
  }

  String pathFor(Category c) => categoryPath(c, categories);

  /// Categories usable for an entry type, in tree order.
  List<Category> categoriesFor(String kind) {
    final income = kind == DefaultKind.income || kind == DefaultKind.oweIn;
    return categories
        .where(
          (c) =>
              c.type == CategoryType.both ||
              c.type == (income ? CategoryType.income : CategoryType.expense),
        )
        .toList()
      ..sort(
        (a, b) => pathFor(a).toLowerCase().compareTo(pathFor(b).toLowerCase()),
      );
  }

  /// All categories in tree order, for the per-category wallet list.
  List<Category> get sortedCategories => [...categories]
    ..sort(
      (a, b) => pathFor(a).toLowerCase().compareTo(pathFor(b).toLowerCase()),
    );

  /// The default category for [kind], if it still exists and fits.
  Category? categoryFor(String kind) {
    final id = defaults.categoryByKind[kind];
    return categoriesFor(kind).where((c) => c.id == id).firstOrNull;
  }

  /// The default wallet for [kind], if it still exists and is active.
  Account? accountFor(String kind) => _account(defaults.accountByKind[kind]);

  Account? accountForCategory(int categoryId) =>
      _account(defaults.accountByCategory[categoryId]);

  Account? _account(int? id) =>
      id == null ? null : accounts.where((a) => a.id == id).firstOrNull;

  Future<void> setCategory(String kind, int? categoryId) =>
      run(() => services.defaults.setCategoryForKind(kind, categoryId))
          .then((_) => refresh());

  Future<void> setAccount(String kind, int? accountId) =>
      run(() => services.defaults.setAccountForKind(kind, accountId))
          .then((_) => refresh());

  Future<void> setCategoryAccount(int categoryId, int? accountId) =>
      run(() => services.defaults.setAccountForCategory(categoryId, accountId))
          .then((_) => refresh());
}
