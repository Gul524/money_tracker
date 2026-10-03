import '../../data/services/dashboard_service.dart';
import '../../data/services/activity_service.dart';
import 'base_controller.dart';

class HomeController extends BaseController {
  HomeController(super.services) {
    refresh();
  }
  DashboardSummary? summary;
  List<ActivityItem> recentActivity = [];

  @override
  void refresh() {
    load();
  }

  Future<void> load() async {
    await run(() async {
      summary = await services.dashboard.currentMonth();
      recentActivity = await services.activity.history(limit: 5);
    });
  }
}
