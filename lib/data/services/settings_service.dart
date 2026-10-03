import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'local_database.dart';

class SettingsService {
  SettingsService(this.storage);
  final LocalDatabase storage;

  Future<String> currency() async {
    final db = await storage.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['currency'],
      limit: 1,
    );
    return rows.isEmpty ? 'PKR' : rows.first['value'] as String;
  }

  Future<void> setCurrency(String code) async {
    if (!['PKR', 'USD', 'EUR', 'GBP'].contains(code)) {
      throw ArgumentError('Unsupported currency');
    }
    final db = await storage.database;
    await db.update(
      'app_settings',
      {'value': code},
      where: 'key = ?',
      whereArgs: ['currency'],
    );
  }

  Future<String> themeMode() async {
    final db = await storage.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['theme_mode'],
      limit: 1,
    );
    final value = rows.isEmpty ? null : rows.first['value'] as String;
    return const ['light', 'dark', 'system'].contains(value) ? value! : 'light';
  }

  Future<void> setThemeMode(String mode) async {
    if (!const ['light', 'dark', 'system'].contains(mode)) {
      throw ArgumentError('Unsupported theme mode');
    }
    final db = await storage.database;
    await db.insert('app_settings', {
      'key': 'theme_mode',
      'value': mode,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
