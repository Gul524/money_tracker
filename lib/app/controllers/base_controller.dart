import 'package:flutter/foundation.dart';

import '../app_services.dart';

abstract class BaseController extends ChangeNotifier {
  BaseController(this.services) {
    services.addListener(refresh);
  }
  final AppServices services;
  bool busy = false;
  String? error;
  bool _disposed = false;

  Future<T?> run<T>(Future<T> Function() action) async {
    busy = true;
    error = null;
    if (!_disposed) notifyListeners();
    try {
      return await action();
    } catch (e) {
      final message = e.toString();
      error = message.contains('FOREIGN KEY constraint failed')
          ? 'This item is in use and cannot be deleted.'
          : message.contains('UNIQUE constraint failed')
          ? 'This record is already linked to another item.'
          : message.replaceFirst('Invalid argument(s): ', '');
      return null;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void refresh();
  void changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    services.removeListener(refresh);
    super.dispose();
  }
}
