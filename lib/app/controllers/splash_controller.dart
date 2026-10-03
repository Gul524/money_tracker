import 'package:flutter/foundation.dart';

import '../app_services.dart';

class SplashController extends ChangeNotifier {
  SplashController(this.services);
  final AppServices services;
  bool ready = false;
  String? error;

  Future<void> initialize() async {
    error = null;
    notifyListeners();
    try {
      await services.initialize();
      ready = true;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }
}
