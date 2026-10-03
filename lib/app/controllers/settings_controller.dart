import 'package:flutter/material.dart' show ThemeMode;

import 'base_controller.dart';

class SettingsController extends BaseController {
  SettingsController(super.services) {
    refresh();
  }
  String currency = 'PKR';
  ThemeMode themeMode = ThemeMode.system;

  @override
  void refresh() {
    run(() async {
      currency = await services.settings.currency();
      themeMode = services.themeMode;
    });
  }

  Future<bool> setCurrency(String value) async =>
      await run(() async {
        await services.settings.setCurrency(value);
        currency = value;
        services.currencyCode = value;
        services.changed();
        return true;
      }) ==
      true;

  Future<bool> setThemeMode(ThemeMode value) async =>
      await run(() async {
        await services.setThemeMode(value);
        themeMode = value;
        return true;
      }) ==
      true;
}
