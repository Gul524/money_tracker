import '../../data/services/dashboard_service.dart';
import 'base_controller.dart';

class HomeController extends BaseController {
  HomeController(super.services) {
    refresh();
  }
  DashboardSummary? summary;

  @override
  void refresh() {
    run(() async {
      summary = await services.dashboard.currentMonth();
    });
  }
}
