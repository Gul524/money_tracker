import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import '../../data/services/activity_service.dart';
import '../date_range.dart';
import '../formatters.dart';
import 'base_controller.dart';
import 'category_path.dart';

enum ActivityFilter { all, expense, income, transfer, owe, tax }

/// Quick date choices offered in the History filter sheet.
enum DatePreset { thisMonth, lastMonth, last3Months, thisYear, custom }

/// Activity feed with type, account, category, date and text/amount filters.
class HistoryController extends BaseController {
  HistoryController(
    super.services, {
    this.accountId,
    this.categoryId,
    this.range,
    this.preset,
  }) {
    refresh();
  }

  List<ActivityItem> items = [];
  List<Account> accounts = [];
  List<Category> categories = [];

  ActivityFilter filter = ActivityFilter.all;
  String query = '';
  int? accountId;
  int? categoryId;
  DateRange? range;
  DatePreset? preset;

  @override
  void refresh() {
    run(() async {
      items = await services.activity.history();
      accounts = await services.accounts.getAll();
      categories = await services.categories.getAll();
    });
  }

  void setFilter(ActivityFilter value) {
    filter = value;
    changed();
  }

  void setQuery(String value) {
    query = value;
    changed();
  }

  void setAccount(int? value) {
    accountId = value;
    changed();
  }

  void setCategory(int? value) {
    categoryId = value;
    changed();
  }

  void setPreset(DatePreset? value, {DateTime? now}) {
    final today = now ?? DateTime.now();
    preset = value;
    range = switch (value) {
      null => null,
      DatePreset.thisMonth => DateRange.month(today),
      DatePreset.lastMonth => DateRange.month(
        DateTime(today.year, today.month - 1),
      ),
      DatePreset.last3Months => DateRange.months(today, 3),
      DatePreset.thisYear => DateRange.year(today.year),
      DatePreset.custom => range,
    };
    changed();
  }

  void setRange(DateRange? value) {
    range = value;
    preset = value == null ? null : DatePreset.custom;
    changed();
  }

  /// Clears account, category and date filters (not the type or search).
  void clearFilters() {
    accountId = null;
    categoryId = null;
    range = null;
    preset = null;
    changed();
  }

  int get activeFilterCount =>
      (accountId == null ? 0 : 1) +
      (categoryId == null ? 0 : 1) +
      (range == null ? 0 : 1);

  bool get isFiltering =>
      activeFilterCount > 0 ||
      filter != ActivityFilter.all ||
      query.trim().isNotEmpty;

  Account? get selectedAccount =>
      accounts.where((a) => a.id == accountId).firstOrNull;
  Category? get selectedCategory =>
      categories.where((c) => c.id == categoryId).firstOrNull;
  String pathFor(Category category) => categoryPath(category, categories);

  /// The selected category and all of its subcategories.
  Set<int> _categoryTree() {
    final ids = <int>{categoryId!};
    var grew = true;
    while (grew) {
      grew = false;
      for (final c in categories) {
        if (c.parentId != null && ids.contains(c.parentId) && ids.add(c.id!)) {
          grew = true;
        }
      }
    }
    return ids;
  }

  bool _matchesType(ActivityItem item) {
    final type = item.transaction?.type;
    return switch (filter) {
      ActivityFilter.all => true,
      ActivityFilter.expense => type == TransactionType.expense,
      ActivityFilter.income => type == TransactionType.income,
      ActivityFilter.owe =>
        type == TransactionType.oweIn || type == TransactionType.oweOut,
      ActivityFilter.transfer => item.kind == ActivityKind.transfer,
      ActivityFilter.tax => item.kind == ActivityKind.tax || item.taxMinor > 0,
    };
  }

  static final _numeric = RegExp(r'^\d+(\.\d{0,2})?$');

  bool _matchesQuery(ActivityItem item) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final text = [
      item.title,
      item.subtitle,
      item.note,
      item.party,
      item.accountName ?? '',
      item.linkLabel ?? '',
    ];
    if (text.any((field) => field.toLowerCase().contains(q))) return true;
    // Amount search: "1250", "1,250" or "1250.5" match Rs 1,250.50.
    final number = q
        .replaceAll(RegExp(r'[,\s]'), '')
        .replaceAll(RegExp(r'^[^\d]+'), '');
    if (!_numeric.hasMatch(number)) return false;
    return [
      item.amountMinor.abs(),
      if (item.taxMinor > 0) item.taxMinor,
    ].any((minor) => amountInputText(minor).startsWith(number));
  }

  List<ActivityItem> get visibleItems {
    final tree = categoryId == null ? null : _categoryTree();
    return items.where((item) {
      if (!_matchesType(item)) return false;
      if (accountId != null && !item.accountIds.contains(accountId)) {
        return false;
      }
      if (tree != null && !tree.contains(item.categoryId)) return false;
      if (range != null && !range!.contains(item.date)) return false;
      return _matchesQuery(item);
    }).toList();
  }

  /// Money in and out across [visible] items. With an account filter,
  /// transfers count for that account; otherwise they are left out.
  (int inMinor, int outMinor) totalsOf(List<ActivityItem> visible) {
    var inflow = 0;
    var outflow = 0;
    for (final item in visible) {
      final effect = accountId == null
          ? item.netEffectMinor
          : item.effectOn(accountId!);
      if (effect > 0) {
        inflow += effect;
      } else {
        outflow -= effect;
      }
    }
    return (inflow, outflow);
  }
}
