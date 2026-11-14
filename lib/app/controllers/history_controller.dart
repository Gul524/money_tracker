import '../../data/models/model_types.dart';
import '../../data/services/activity_service.dart';
import 'base_controller.dart';

enum ActivityFilter { all, expense, income, transfer, owe, tax }

class HistoryController extends BaseController {
  HistoryController(super.services) {
    refresh();
  }

  List<ActivityItem> items = [];
  ActivityFilter filter = ActivityFilter.all;
  String query = '';

  @override
  void refresh() {
    run(() async {
      items = await services.activity.history();
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

  bool _matchesFilter(ActivityItem item) {
    final type = item.transaction?.type;
    return switch (filter) {
      ActivityFilter.all => true,
      ActivityFilter.expense => type == TransactionType.expense,
      ActivityFilter.income => type == TransactionType.income,
      ActivityFilter.owe =>
        type == TransactionType.oweIn || type == TransactionType.oweOut,
      ActivityFilter.transfer => item.kind == ActivityKind.transfer,
      ActivityFilter.tax => item.kind == ActivityKind.tax,
    };
  }

  bool _matchesQuery(ActivityItem item) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final t = item.transaction;
    return [
      item.title,
      item.subtitle,
      t?.note ?? '',
      t?.party ?? '',
    ].any((field) => field.toLowerCase().contains(q));
  }

  List<ActivityItem> get visibleItems =>
      items.where((i) => _matchesFilter(i) && _matchesQuery(i)).toList();
}
