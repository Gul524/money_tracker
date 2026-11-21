import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../data/repo/account_repository.dart';
import '../data/repo/asset_repository.dart';
import '../data/repo/category_repository.dart';
import '../data/repo/tax_rate_repository.dart';
import '../data/repo/tax_repository.dart';
import '../data/repo/transaction_repository.dart';
import '../data/repo/transfer_repository.dart';
import '../data/services/dashboard_service.dart';
import '../data/services/defaults_service.dart';
import '../data/services/activity_service.dart';
import '../data/services/local_database.dart';
import '../data/services/report_service.dart';
import '../data/services/settings_service.dart';

class AppServices extends ChangeNotifier {
  AppServices._(this.database)
    : categories = CategoryRepository(database),
      accounts = AccountRepository(database),
      assets = AssetRepository(database),
      transactions = TransactionRepository(database),
      transfers = TransferRepository(database),
      taxes = TaxRepository(database),
      taxRates = TaxRateRepository(database),
      dashboard = DashboardService(database),
      activity = ActivityService(database),
      reports = ReportService(database),
      settings = SettingsService(database),
      defaults = DefaultsService(database);

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

  /// Taxes managed in Settings › Tax.
  final TaxRateRepository taxRates;
  final DashboardService dashboard;
  final ActivityService activity;
  final ReportService reports;
  final SettingsService settings;
  final DefaultsService defaults;
  String currencyCode = 'PKR';
  ThemeMode themeMode = ThemeMode.system;

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
