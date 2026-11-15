import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'local_database.dart';

/// Entry types defaults can be set for. Names match the app's `EntryKind`
/// plus the two sides of a transfer.
abstract final class DefaultKind {
  static const income = 'income';
  static const expense = 'expense';
  static const oweIn = 'oweIn';
  static const oweOut = 'oweOut';
  static const tax = 'tax';
  static const transferFrom = 'transferFrom';
  static const transferTo = 'transferTo';
}

/// The user's preselected choices for new entries.
class EntryDefaults {
  const EntryDefaults({
    this.categoryByKind = const {},
    this.accountByKind = const {},
    this.accountByCategory = const {},
  });

  /// Entry type (see [DefaultKind]) → category id.
  final Map<String, int> categoryByKind;

  /// Entry type (see [DefaultKind]) → account id.
  final Map<String, int> accountByKind;

  /// Category id → account id.
  final Map<int, int> accountByCategory;
}

/// Stores [EntryDefaults] as rows in `app_settings`:
/// `default_category:<kind>`, `default_account:<kind>` and
/// `default_account_for_category:<categoryId>`, each holding an id.
/// Ids that no longer exist are ignored by readers and removed when the
/// category or account is deleted.
class DefaultsService {
  DefaultsService(this.storage);
  final LocalDatabase storage;

  static const _category = 'default_category:';
  static const _account = 'default_account:';
  static const _categoryAccount = 'default_account_for_category:';

  Future<EntryDefaults> load() async {
    final db = await storage.database;
    final rows = await db.query(
      'app_settings',
      where: 'key LIKE ?',
      whereArgs: ['default_%'],
    );
    final categoryByKind = <String, int>{};
    final accountByKind = <String, int>{};
    final accountByCategory = <int, int>{};
    for (final row in rows) {
      final key = row['key'] as String;
      final value = int.tryParse(row['value'] as String);
      if (value == null) continue;
      if (key.startsWith(_categoryAccount)) {
        final id = int.tryParse(key.substring(_categoryAccount.length));
        if (id != null) accountByCategory[id] = value;
      } else if (key.startsWith(_category)) {
        categoryByKind[key.substring(_category.length)] = value;
      } else if (key.startsWith(_account)) {
        accountByKind[key.substring(_account.length)] = value;
      }
    }
    return EntryDefaults(
      categoryByKind: categoryByKind,
      accountByKind: accountByKind,
      accountByCategory: accountByCategory,
    );
  }

  Future<void> setCategoryForKind(String kind, int? categoryId) =>
      _set('$_category$kind', categoryId);

  Future<void> setAccountForKind(String kind, int? accountId) =>
      _set('$_account$kind', accountId);

  Future<void> setAccountForCategory(int categoryId, int? accountId) =>
      _set('$_categoryAccount$categoryId', accountId);

  /// Removes every default that points at [categoryId].
  Future<void> forgetCategory(int categoryId) async {
    final db = await storage.database;
    await db.delete(
      'app_settings',
      where: '(key LIKE ? AND value = ?) OR key = ?',
      whereArgs: ['$_category%', '$categoryId', '$_categoryAccount$categoryId'],
    );
  }

  /// Removes every default that points at [accountId].
  Future<void> forgetAccount(int accountId) async {
    final db = await storage.database;
    await db.delete(
      'app_settings',
      where: '(key LIKE ? OR key LIKE ?) AND value = ?',
      whereArgs: ['$_account%', '$_categoryAccount%', '$accountId'],
    );
  }

  Future<void> _set(String key, int? id) async {
    final db = await storage.database;
    if (id == null) {
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('app_settings', {
        'key': key,
        'value': '$id',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
