import '../../data/services/activity_service.dart';
import 'base_controller.dart';

class HistoryController extends BaseController {
  HistoryController(super.services) {
    refresh();
  }

  List<ActivityItem> items = [];

  @override
  void refresh() {
    run(() async {
      items = await services.activity.history();
    });
  }
}
