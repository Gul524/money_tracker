import '../../data/services/dashboard_service.dart';
import 'base_controller.dart';

class ReportsController extends BaseController {
  ReportsController(super.services, {DateTime? now})
    : month = _monthOf(now ?? DateTime.now()) {
    refresh();
  }

  DateTime month;
  DashboardSummary? summary;
  List<CategoryTotal> totals = [];

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  bool get isCurrentMonth => month == _monthOf(DateTime.now());
  List<CategoryTotal> get spending => totals.where((t) => !t.isIncome).toList();
  List<CategoryTotal> get earning => totals.where((t) => t.isIncome).toList();

  @override
  void refresh() {
    run(() async {
      summary = await services.dashboard.currentMonth(now: month);
      totals = await services.dashboard.categoryTotals(month);
    });
  }

  void previousMonth() {
    month = DateTime(month.year, month.month - 1);
    refresh();
  }

  void nextMonth() {
    if (isCurrentMonth) return;
    month = DateTime(month.year, month.month + 1);
    refresh();
  }
}
