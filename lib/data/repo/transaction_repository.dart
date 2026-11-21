import 'package:sqflite/sqflite.dart';

import '../models/model_types.dart';
import '../models/money_transaction.dart';
import '../models/tax_payment.dart';
import 'category_repository.dart';
import 'crud_repository.dart';

/// The item handed over when an owe started (the other side of the deal).
/// - "Owed to me": an asset you own and gave them ([OweItem.given]); it
///   leaves your assets.
/// - "I owe": the thing you got from them ([OweItem.received]); it is kept
///   as an asset worth the owed amount.
class OweItem {
  const OweItem.given(int this.assetId) : name = null;
  const OweItem.received(String this.name) : assetId = null;
  final int? assetId;
  final String? name;
}

class TransactionRepository extends CrudRepository<MoneyTransaction> {
  TransactionRepository(super.storage)
    : _categories = CategoryRepository(storage);

  final CategoryRepository _categories;

  @override
  String get table => 'transactions';

  @override
  MoneyTransaction fromRow(Map<String, Object?> row) => MoneyTransaction(
    id: row['id'] as int,
    type: TransactionType.values.byName(row['type'] as String),
    amountMinor: row['amount_minor'] as int,
    categoryId: row['category_id'] as int,
    accountId: row['account_id'] as int?,
    occurredAt: DateTime.parse(row['occurred_at'] as String),
    note: row['note'] as String?,
    party: row['party'] as String?,
    dueAt: _parseDate(row['due_at']),
    oweStatus: row['owe_status'] == null
        ? null
        : OweStatus.values.byName(row['owe_status'] as String),
    completedAt: _parseDate(row['completed_at']),
    exchangeAccountId: row['exchange_account_id'] as int?,
    parentId: row['parent_id'] as int?,
  );

  DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  @override
  Map<String, Object?> toRow(MoneyTransaction value) => {
    'id': value.id,
    'type': value.type.name,
    'amount_minor': value.amountMinor,
    'category_id': value.categoryId,
    'account_id': value.accountId,
    'occurred_at': value.occurredAt.toIso8601String(),
    'note': value.note,
    'party': value.party,
    'due_at': value.dueAt?.toIso8601String(),
    'owe_status': value.oweStatus?.name,
    'completed_at': value.completedAt?.toIso8601String(),
    'exchange_account_id': value.exchangeAccountId,
    'parent_id': value.parentId,
  };

  @override
  MoneyTransaction withId(MoneyTransaction value, int id) =>
      value.copyWith(id: id);

  @override
  Future<void> validate(MoneyTransaction value, {int? updatingId}) async {
    if (value.amountMinor <= 0) throw ArgumentError('Amount must be positive');
    await _validateCategory(value);
    _validateOweFields(value);
  }

  Future<void> _validateCategory(MoneyTransaction value) async {
    final category = await _categories.getById(value.categoryId);
    if (category == null) throw ArgumentError('Category does not exist');
    final needed = switch (value.type) {
      TransactionType.income || TransactionType.oweIn => CategoryType.income,
      _ => CategoryType.expense,
    };
    if (category.type != CategoryType.both && category.type != needed) {
      throw ArgumentError('Category cannot be used for this transaction type');
    }
  }

  void _validateOweFields(MoneyTransaction value) {
    final isOwe =
        value.type == TransactionType.oweIn ||
        value.type == TransactionType.oweOut;
    if (!isOwe) {
      if (value.exchangeAccountId != null) {
        throw ArgumentError(
          'Only money owed can record money lent or borrowed',
        );
      }
      if (value.accountId == null ||
          value.oweStatus != null ||
          value.dueAt != null ||
          value.completedAt != null) {
        throw ArgumentError(
          'Income and expense require an account and no owe fields',
        );
      }
      return;
    }
    if (value.oweStatus == null) throw ArgumentError('Owe status is required');
    if (value.oweStatus == OweStatus.pending && value.completedAt != null) {
      throw ArgumentError('Pending owe cannot have a completion date');
    }
    if (value.oweStatus == OweStatus.completed &&
        (value.completedAt == null || value.accountId == null)) {
      throw ArgumentError(
        'Completed owe requires an account and completion date',
      );
    }
  }

  Future<MoneyTransaction> completeOwe(
    int id,
    int accountId, {
    DateTime? at,
  }) async {
    final existing = await getById(id);
    if (existing == null) throw StateError('Transaction $id does not exist');
    if (existing.oweStatus != OweStatus.pending) {
      throw StateError('Only a pending owe can be completed');
    }
    return update(
      existing.copyWith(
        accountId: accountId,
        oweStatus: OweStatus.completed,
        completedAt: at ?? DateTime.now(),
      ),
    );
  }

  /// Pays part of a pending owe: the owe keeps what is left and a completed
  /// copy for [amountMinor] (same party, category and money link) records the
  /// payment, so balances and reports need no special case. Paying the whole
  /// remainder settles the owe itself.
  Future<void> payPart(
    int id,
    int amountMinor,
    int accountId, {
    DateTime? at,
    String? note,
  }) async {
    final owe = await getById(id);
    if (owe == null) throw StateError('Transaction $id does not exist');
    if (owe.oweStatus != OweStatus.pending) {
      throw StateError('Only a pending owe can be paid');
    }
    if (amountMinor <= 0) throw ArgumentError('Amount must be positive');
    if (amountMinor > owe.amountMinor) {
      throw ArgumentError('That is more than what is still owed');
    }
    final when = at ?? DateTime.now();
    if (amountMinor == owe.amountMinor) {
      await completeOwe(id, accountId, at: when);
      return;
    }
    final db = await storage.database;
    await db.transaction((txn) async {
      await txn.update(
        table,
        {'amount_minor': owe.amountMinor - amountMinor},
        where: 'id = ?',
        whereArgs: [id],
      );
      final part = owe.copyWith(
        id: null,
        amountMinor: amountMinor,
        accountId: accountId,
        occurredAt: when,
        note: note,
        dueAt: null,
        oweStatus: OweStatus.completed,
        completedAt: when,
        parentId: id,
      );
      await txn.insert(table, toRow(part)..remove('id'));
    });
  }

  /// Payments made so far against each owe: owe id → payments, oldest first.
  Future<Map<int, List<MoneyTransaction>>> partsByOwe() async {
    final db = await storage.database;
    final rows = await db.query(
      table,
      where: 'parent_id IS NOT NULL',
      orderBy: 'occurred_at ASC, id ASC',
    );
    final map = <int, List<MoneyTransaction>>{};
    for (final t in rows.map(fromRow)) {
      (map[t.parentId!] ??= []).add(t);
    }
    return map;
  }

  Future<List<MoneyTransaction>> pendingOwes({DateTime? through}) async {
    final db = await storage.database;
    final rows = await db.query(
      table,
      where: through == null
          ? 'owe_status = ?'
          : 'owe_status = ? AND due_at IS NOT NULL AND due_at < ?',
      whereArgs: through == null
          ? ['pending']
          : ['pending', through.toIso8601String()],
      orderBy: 'due_at IS NULL, due_at ASC, id ASC',
    );
    return rows.map(fromRow).toList();
  }

  Future<List<MoneyTransaction>> history({int? limit}) async {
    final db = await storage.database;
    final rows = await db.query(
      table,
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(fromRow).toList();
  }

  /// Creates or updates [value] and, in the same database transaction, its
  /// links:
  /// - Tax: [taxMinor] of 0 removes any linked tax. Tax is paid from the
  ///   transaction's account on the transaction's date (income/expense only).
  /// - Owes: [item] is the thing exchanged when the owe started; null removes
  ///   the link (the asset itself is kept). An owe has money
  ///   ([MoneyTransaction.exchangeAccountId]) or an item, not both.
  /// - An asset bought with this entry follows its amount and date.
  Future<MoneyTransaction> saveWithTax(
    MoneyTransaction value, {
    int taxMinor = 0,
    TaxDetails? taxDetails,
    OweItem? item,
  }) async {
    if (taxMinor < 0) throw ArgumentError('Tax cannot be negative');
    final isOwe =
        value.type == TransactionType.oweIn ||
        value.type == TransactionType.oweOut;
    if (taxMinor > 0 && isOwe) {
      throw ArgumentError('Tax can only be added to income or expense');
    }
    if (item != null) {
      if (!isOwe) throw ArgumentError('Only money owed can record an item');
      if (value.exchangeAccountId != null) {
        throw ArgumentError('Record either money or an item, not both');
      }
      if (value.type == TransactionType.oweIn && item.assetId == null ||
          value.type == TransactionType.oweOut &&
              (item.name ?? '').trim().isEmpty) {
        throw ArgumentError(
          value.type == TransactionType.oweIn
              ? 'Choose the item you gave'
              : 'Name the item you got',
        );
      }
    }
    await validate(value, updatingId: value.id);
    final db = await storage.database;
    return db.transaction((txn) async {
      final row = toRow(value);
      final int id;
      if (value.id == null) {
        id = await txn.insert(table, row..remove('id'));
      } else {
        id = value.id!;
        final count = await txn.update(
          table,
          row,
          where: 'id = ?',
          whereArgs: [id],
        );
        if (count == 0) throw StateError('$table row $id does not exist');
      }
      if (taxMinor == 0) {
        await txn.delete(
          'tax_payments',
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
      } else {
        final tax = {
          'amount_minor': taxMinor,
          'paid_at': value.occurredAt.toIso8601String(),
          'account_id': value.accountId,
          'transaction_id': id,
          // No details (e.g. imported rows): a plain amount, as before.
          ...taxDetails?.toRow() ?? TaxDetails.none,
        };
        final updated = await txn.update(
          'tax_payments',
          tax,
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
        if (updated == 0) await txn.insert('tax_payments', tax);
      }
      if (value.type == TransactionType.oweIn) {
        await _linkGivenAsset(txn, id, item?.assetId);
      } else if (value.type == TransactionType.oweOut && item == null) {
        await _unlinkPurchase(txn, id);
      }
      await _syncPurchasedAsset(
        txn,
        id,
        value,
        createAs: value.type == TransactionType.oweOut ? item?.name : null,
      );
      return withId(value, id);
    });
  }

  /// Marks [assetId] as given away in owe [id] (and releases any other asset
  /// it pointed at). Null releases all.
  Future<void> _linkGivenAsset(
    DatabaseExecutor txn,
    int id,
    int? assetId,
  ) async {
    await txn.update(
      'assets',
      {'given_transaction_id': null},
      where: 'given_transaction_id = ? AND id IS NOT ?',
      whereArgs: [id, assetId],
    );
    if (assetId == null) return;
    final rows = await txn.query(
      'assets',
      columns: ['given_transaction_id'],
      where: 'id = ?',
      whereArgs: [assetId],
    );
    if (rows.isEmpty) throw ArgumentError('That item no longer exists');
    final givenIn = rows.first['given_transaction_id'];
    if (givenIn != null && givenIn != id) {
      throw ArgumentError('That item was already given in another entry');
    }
    await txn.update(
      'assets',
      {'given_transaction_id': id},
      where: 'id = ?',
      whereArgs: [assetId],
    );
  }

  Future<void> _unlinkPurchase(DatabaseExecutor txn, int id) => txn.update(
    'assets',
    {'purchase_transaction_id': null},
    where: 'purchase_transaction_id = ?',
    whereArgs: [id],
  );

  /// Keeps the asset bought with entry [id] in step with it: price paid and
  /// date follow the entry, and "worth today" follows too while it still
  /// equals the price paid. With [createAs], the asset is created (or
  /// renamed) as well.
  Future<void> _syncPurchasedAsset(
    DatabaseExecutor txn,
    int id,
    MoneyTransaction value, {
    String? createAs,
  }) async {
    final rows = await txn.query(
      'assets',
      where: 'purchase_transaction_id = ?',
      whereArgs: [id],
    );
    final name = createAs?.trim();
    if (rows.isEmpty) {
      if (name == null || name.isEmpty) return;
      await txn.insert('assets', {
        'name': name,
        'acquired_on': value.occurredAt.toIso8601String(),
        'purchase_amount_minor': value.amountMinor,
        'current_value_minor': value.amountMinor,
        'purchase_transaction_id': id,
      });
      return;
    }
    final asset = rows.first;
    final followsPrice =
        asset['current_value_minor'] == asset['purchase_amount_minor'];
    await txn.update(
      'assets',
      {
        if (name != null && name.isNotEmpty) 'name': name,
        'acquired_on': value.occurredAt.toIso8601String(),
        'purchase_amount_minor': value.amountMinor,
        if (followsPrice) 'current_value_minor': value.amountMinor,
      },
      where: 'id = ?',
      whereArgs: [asset['id']],
    );
  }

  /// Deletes the transaction and any tax recorded with it. Assets linked to
  /// it are kept: one bought with it stays owned, one given away in it comes
  /// back.
  @override
  Future<void> delete(int id) async {
    final db = await storage.database;
    await db.transaction((txn) async {
      await txn.delete(
        'tax_payments',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      await _unlinkPurchase(txn, id);
      await _linkGivenAsset(txn, id, null);
      // Removing a part payment puts its amount back on the owe (reopening
      // it if that payment had settled it).
      final part = await txn.query(table, where: 'id = ?', whereArgs: [id]);
      final parent = part.isEmpty ? null : part.first['parent_id'];
      if (parent != null) {
        await txn.rawUpdate(
          'UPDATE transactions SET amount_minor = amount_minor + ?, '
          "owe_status = 'pending', completed_at = NULL WHERE id = ?",
          [part.first['amount_minor'], parent],
        );
      }
      final count = await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      if (count == 0) throw StateError('$table row $id does not exist');
    });
  }
}
