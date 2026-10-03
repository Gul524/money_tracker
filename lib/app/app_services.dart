import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../data/repo/account_repository.dart';
import '../data/repo/asset_repository.dart';
import '../data/repo/category_repository.dart';
import '../data/repo/tax_repository.dart';
import '../data/repo/transaction_repository.dart';
import '../data/repo/transfer_repository.dart';
import '../data/services/dashboard_service.dart';
import '../data/services/local_database.dart';
import '../data/services/settings_service.dart';

class AppServices extends ChangeNotifier {
  AppServices._(this.database)
    : categories = CategoryRepository(database),
      accounts = AccountRepository(database),
      assets = AssetRepository(database),
      transactions = TransactionRepository(database),
      transfers = TransferRepository(database),
      taxes = TaxRepository(database),
      dashboard = DashboardService(database),
      settings = SettingsService(database);

  factory AppServices.create() => AppServices._(LocalDatabase());
  factory AppServices.withDatabase(LocalDatabase database) =>
      AppServices._(database);

  final LocalDatabase database;
  final CategoryRepository categories;
  final AccountRepository accounts;
  final AssetRepository assets;
  final TransactionRepository transactions;
  final TransferRepository transfers;
  final TaxRepository taxes;
  final DashboardService dashboard;
  final SettingsService settings;
  String currencyCode = 'PKR';
  ThemeMode themeMode = ThemeMode.light;

  Future<void> initialize() async {
    await database.database;
    currencyCode = await settings.currency();
    themeMode = ThemeMode.values.byName(await settings.themeMode());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await settings.setThemeMode(mode.name);
    themeMode = mode;
    notifyListeners();
  }

  void changed() => notifyListeners();
  Future<void> close() => database.close();
}
