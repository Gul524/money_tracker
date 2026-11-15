import '../../data/models/category.dart';
import '../../data/services/dashboard_service.dart';
import '../../data/services/report_service.dart';
import '../date_range.dart';
export '../date_range.dart' show ReportPeriod;
import 'base_controller.dart';

/// A top-level category with its subcategories' totals rolled up.
class CategoryGroup {
  CategoryGroup({
    required this.categoryId,
    required this.name,
    required this.isIncome,
    this.icon,
    this.color,
  });
  final int categoryId;
  final String name;
  final bool isIncome;

  /// The top-level category's chosen icon key and `#RRGGBB` color.
  final String? icon;
  final String? color;
  int totalMinor = 0;

  /// Totals of the subcategories (and the parent itself) inside this group,
  /// largest first. Empty when everything was recorded on the parent.
  final List<(String name, int totalMinor)> parts = [];
}

class ReportsController extends BaseController {
  ReportsController(super.services, {DateTime? now})
    : _now = now,
      range = DateRange.month(now ?? DateTime.now()) {
    refresh();
  }

  final DateTime? _now;
  ReportPeriod period = ReportPeriod.month;
  DateRange range;
  PeriodReport? report;

  /// Today's position (balances, owes, assets) — not period based.
  DashboardSummary? position;
  List<Category> categories = [];

  DateTime get _today => _now ?? DateTime.now();

  @override
  void refresh() {
    run(() async {
      report = await services.reports.build(range.start, range.end);
      position = await services.dashboard.currentMonth(now: _today);
      categories = await services.categories.getAll();
    });
  }

  void setPeriod(ReportPeriod value) {
    if (value == ReportPeriod.custom) return;
    period = value;
    range = DateRange.current(value, _today) ?? range;
    refresh();
  }

  void setCustomRange(DateRange value) {
    period = ReportPeriod.custom;
    range = value;
    refresh();
  }

  bool get canStep => period != ReportPeriod.custom;

  /// Whether a later period exists that has started already.
  bool get canGoNext => range.canStepForward(period, _today);

  void previous() {
    if (!canStep) return;
    range = range.step(period, -1);
    refresh();
  }

  void next() {
    if (!canGoNext) return;
    range = range.step(period, 1);
    refresh();
  }

  List<CategoryGroup> get spending => _groups(income: false);
  List<CategoryGroup> get earning => _groups(income: true);

  List<CategoryGroup> _groups({required bool income}) {
    final byId = {for (final c in categories) c.id!: c};
    Category? rootOf(int id) {
      var current = byId[id];
      final seen = <int>{};
      while (current?.parentId != null && seen.add(current!.id!)) {
        final parent = byId[current.parentId];
        if (parent == null) break;
        current = parent;
      }
      return current;
    }

    final groups = <int, CategoryGroup>{};
    for (final total in report?.categories ?? const <CategoryTotal>[]) {
      if (total.isIncome != income) continue;
      final root = rootOf(total.categoryId);
      final rootId = root?.id ?? total.categoryId;
      final group = groups.putIfAbsent(
        rootId,
        () => CategoryGroup(
          categoryId: rootId,
          name: root?.name ?? total.name,
          isIncome: income,
          icon: root?.icon ?? total.icon,
          color: root?.color ?? total.color,
        ),
      );
      group.totalMinor += total.totalMinor;
      group.parts.add((total.name, total.totalMinor));
    }
    for (final g in groups.values) {
      if (g.parts.length == 1 && g.parts.single.$1 == g.name) g.parts.clear();
      g.parts.sort((a, b) => b.$2.compareTo(a.$2));
    }
    return groups.values.toList()
      ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  }
}
