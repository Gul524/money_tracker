import 'package:flutter/foundation.dart';

import '../app_services.dart';

/// Opens the local database (and loads app settings) while the splash shows.
class SplashController extends ChangeNotifier {
  SplashController(this.services);
  final AppServices services;

  bool ready = false;
  bool loading = false;
  String? error;
  bool _disposed = false;

  Future<void> initialize() async {
    if (loading || ready) return;
    loading = true;
    error = null;
    _notify();
    try {
      await services.initialize();
      ready = true;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
