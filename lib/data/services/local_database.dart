import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single local SQLite connection and its schema.
class LocalDatabase {
  LocalDatabase({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? path;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final databasePath =
        path ?? p.join(await getDatabasesPath(), 'money_tracker.db');
    _database = await _factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 6,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense', 'both')),
        parent_id INTEGER REFERENCES categories(id) ON DELETE RESTRICT,
        icon TEXT,
        color TEXT CHECK($_colorCheck),
        CHECK(length(trim(name)) > 0)
      )
    ''');
    await db.execute(
      'CREATE INDEX categories_parent_idx ON categories(parent_id)',
    );
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('cash', 'bank')),
        opening_balance_minor INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0, 1)),
        CHECK(length(trim(name)) > 0)
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense', 'oweIn', 'oweOut')),
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
        account_id INTEGER REFERENCES accounts(id) ON DELETE RESTRICT,
        occurred_at TEXT NOT NULL,
        note TEXT,
        party TEXT,
        due_at TEXT,
        owe_status TEXT CHECK(owe_status IN ('pending', 'completed')),
        completed_at TEXT,
        exchange_account_id INTEGER REFERENCES accounts(id) ON DELETE RESTRICT
          CHECK($_exchangeCheck),
        CHECK((type IN ('income', 'expense') AND account_id IS NOT NULL
          AND owe_status IS NULL AND due_at IS NULL AND completed_at IS NULL)
          OR (type IN ('oweIn', 'oweOut') AND owe_status IS NOT NULL
          AND (owe_status = 'pending' AND completed_at IS NULL
            OR owe_status = 'completed' AND completed_at IS NOT NULL AND account_id IS NOT NULL)))
      )
    ''');
    await db.execute(
      'CREATE INDEX transactions_date_idx ON transactions(occurred_at)',
    );
    await db.execute(
      'CREATE INDEX transactions_category_idx ON transactions(category_id)',
    );
    await db.execute(
      'CREATE INDEX transactions_account_idx ON transactions(account_id)',
    );
    await db.execute(
      'CREATE INDEX transactions_due_idx ON transactions(owe_status, due_at)',
    );
    await db.execute('''
      CREATE TABLE assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        acquired_on TEXT NOT NULL,
        purchase_amount_minor INTEGER NOT NULL CHECK(purchase_amount_minor >= 0),
        current_value_minor INTEGER NOT NULL CHECK(current_value_minor >= 0),
        purchase_transaction_id INTEGER UNIQUE REFERENCES transactions(id) ON DELETE RESTRICT,
        notes TEXT,
        given_transaction_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
        CHECK(length(trim(name)) > 0)
      )
    ''');
    await db.execute('''
      CREATE TABLE tax_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        paid_at TEXT NOT NULL,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        note TEXT,
        transaction_id INTEGER REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX tax_payments_date_idx ON tax_payments(paid_at)',
    );
    await _createTaxLinkIndex(db);
    await _createOweLinkIndexes(db);
    await _createTransfers(db);
    await _createSettings(db);
    await _seedDefaults(db);
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createTransfers(db);
      await _createSettings(db);
    }
    if (oldVersion < 3) await _seedDefaults(db);
    if (oldVersion < 4 && await _hasColumnlessTaxTable(db)) {
      // Tax paid as part of an income/expense entry is linked to it, and is
      // removed together with that entry.
      await db.execute(
        'ALTER TABLE tax_payments ADD COLUMN transaction_id INTEGER '
        'REFERENCES transactions(id) ON DELETE CASCADE',
      );
      await _createTaxLinkIndex(db);
    }
    if (oldVersion < 5) {
      // User-chosen category icon key and tag color (#RRGGBB).
      final columns = await db.rawQuery('PRAGMA table_info(categories)');
      final names = columns.map((c) => c['name']).toSet();
      if (columns.isNotEmpty && !names.contains('icon')) {
        await db.execute('ALTER TABLE categories ADD COLUMN icon TEXT');
      }
      if (columns.isNotEmpty && !names.contains('color')) {
        await db.execute(
          'ALTER TABLE categories ADD COLUMN color TEXT CHECK($_colorCheck)',
        );
      }
    }
    if (oldVersion < 6) {
      // Two-way owes: the wallet money moved through when an owe started,
      // and the asset given away in an "owed to me" entry.
      final tx = await _columnNames(db, 'transactions');
      final assets = await _columnNames(db, 'assets');
      if (tx.isNotEmpty && !tx.contains('exchange_account_id')) {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN exchange_account_id INTEGER '
          'REFERENCES accounts(id) ON DELETE RESTRICT CHECK($_exchangeCheck)',
        );
      }
      if (assets.isNotEmpty && !assets.contains('given_transaction_id')) {
        await db.execute(
          'ALTER TABLE assets ADD COLUMN given_transaction_id INTEGER '
          'REFERENCES transactions(id) ON DELETE SET NULL',
        );
      }
      if (tx.isNotEmpty && assets.isNotEmpty) await _createOweLinkIndexes(db);
    }
  }

  Future<Set<Object?>> _columnNames(Database db, String table) async =>
      (await db.rawQuery('PRAGMA table_info($table)'))
          .map((c) => c['name'])
          .toSet();

  /// Only owes can record the wallet money moved through.
  static const _exchangeCheck =
      "exchange_account_id IS NULL OR type IN ('oweIn', 'oweOut')";

  Future<void> _createOweLinkIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS transactions_exchange_idx '
      'ON transactions(exchange_account_id)',
    );
    // An asset can be given away in only one entry.
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS assets_given_idx '
      'ON assets(given_transaction_id) WHERE given_transaction_id IS NOT NULL',
    );
  }

  /// A stored color is NULL or `#RRGGBB` in upper-case hex.
  static const _colorCheck =
      "color IS NULL OR (length(color) = 7 AND color GLOB '#[0-9A-F][0-9A-F]"
      "[0-9A-F][0-9A-F][0-9A-F][0-9A-F]')";

  Future<bool> _hasColumnlessTaxTable(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(tax_payments)');
    return columns.isNotEmpty &&
        !columns.any((c) => c['name'] == 'transaction_id');
  }

  Future<void> _createTaxLinkIndex(Database db) => db.execute(
    'CREATE UNIQUE INDEX tax_payments_transaction_idx '
    'ON tax_payments(transaction_id) WHERE transaction_id IS NOT NULL',
  );

  Future<void> _seedDefaults(Database db) async {
    const categories = {
      'income': ['Salary', 'Business', 'Bonus'],
      'expense': [
        'Food',
        'Shopping',
        'Phone',
        'Donation',
        'Gifts',
        'Education',
      ],
    };
    for (final entry in categories.entries) {
      for (final name in entry.value) {
        await db.rawInsert(
          '''
          INSERT INTO categories (name, type)
          SELECT ?, ? WHERE NOT EXISTS (
            SELECT 1 FROM categories
            WHERE name = ? COLLATE NOCASE AND type = ? AND parent_id IS NULL
          )
        ''',
          [name, entry.key, name, entry.key],
        );
      }
    }
    await db.rawInsert('''
      INSERT INTO accounts (name, type, opening_balance_minor)
      SELECT 'Cash', 'cash', 0 WHERE NOT EXISTS (
        SELECT 1 FROM accounts WHERE name = 'Cash' COLLATE NOCASE AND type = 'cash'
      )
    ''');
  }

  Future<void> _createTransfers(Database db) async {
    await db.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        to_account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        occurred_at TEXT NOT NULL,
        note TEXT,
        CHECK(from_account_id != to_account_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX transfers_date_idx ON transfers(occurred_at)',
    );
  }

  Future<void> _createSettings(Database db) async {
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.insert('app_settings', {'key': 'currency', 'value': 'PKR'});
  }
}
