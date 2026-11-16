import '../models/asset.dart';
import '../models/model_types.dart';
import '../models/money_transaction.dart';
import 'crud_repository.dart';
import 'transaction_repository.dart';

class AssetRepository extends CrudRepository<Asset> {
  AssetRepository(super.storage)
    : _transactions = TransactionRepository(storage);

  final TransactionRepository _transactions;

  @override
  String get table => 'assets';

  @override
  Asset fromRow(Map<String, Object?> row) => Asset(
    id: row['id'] as int,
    name: row['name'] as String,
    acquiredOn: DateTime.parse(row['acquired_on'] as String),
    purchaseAmountMinor: row['purchase_amount_minor'] as int,
    currentValueMinor: row['current_value_minor'] as int,
    purchaseTransactionId: row['purchase_transaction_id'] as int?,
    givenTransactionId: row['given_transaction_id'] as int?,
    notes: row['notes'] as String?,
  );

  @override
  Map<String, Object?> toRow(Asset value) => {
    'id': value.id,
    'name': value.name.trim(),
    'acquired_on': value.acquiredOn.toIso8601String(),
    'purchase_amount_minor': value.purchaseAmountMinor,
    'current_value_minor': value.currentValueMinor,
    'purchase_transaction_id': value.purchaseTransactionId,
    'given_transaction_id': value.givenTransactionId,
    'notes': value.notes,
  };

  @override
  Asset withId(Asset value, int id) => value.copyWith(id: id);

  @override
  Future<void> validate(Asset value, {int? updatingId}) async {
    _validateFields(value);
    if (value.purchaseTransactionId != null) {
      final type = await _typeOf(value.purchaseTransactionId!);
      if (type != 'expense' && type != 'oweOut') {
        throw ArgumentError(
          'Asset purchase must link to an expense or money you owe',
        );
      }
    }
    if (value.givenTransactionId != null &&
        await _typeOf(value.givenTransactionId!) != 'oweIn') {
      throw ArgumentError('A given item must link to money owed to you');
    }
  }

  void _validateFields(Asset value) {
    if (value.name.trim().isEmpty) {
      throw ArgumentError('Asset name is required');
    }
    if (value.purchaseAmountMinor < 0 || value.currentValueMinor < 0) {
      throw ArgumentError('Asset values cannot be negative');
    }
  }

  Future<String?> _typeOf(int transactionId) async {
    final db = await storage.database;
    final rows = await db.query(
      'transactions',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['type'] as String?;
  }

  /// Saves [asset] together with how it was acquired, in one database
  /// transaction. [purchase] is an expense (paid from a wallet) or an
  /// "I owe" entry (still owed to the seller); its amount and date should
  /// match the asset's price and date. Null keeps any existing link as is.
  Future<Asset> saveWithPurchase(
    Asset asset, {
    MoneyTransaction? purchase,
  }) async {
    if (purchase == null) {
      return asset.id == null ? create(asset) : update(asset);
    }
    if (purchase.type != TransactionType.expense &&
        purchase.type != TransactionType.oweOut) {
      throw ArgumentError('Asset purchase must be an expense or money you owe');
    }
    if (purchase.exchangeAccountId != null) {
      throw ArgumentError('Record either money or an item, not both');
    }
    _validateFields(asset);
    await _transactions.validate(purchase, updatingId: purchase.id);
    if (asset.givenTransactionId != null &&
        await _typeOf(asset.givenTransactionId!) != 'oweIn') {
      throw ArgumentError('A given item must link to money owed to you');
    }
    final db = await storage.database;
    return db.transaction((txn) async {
      final txRow = _transactions.toRow(purchase);
      final int txId;
      if (purchase.id == null) {
        txId = await txn.insert('transactions', txRow..remove('id'));
      } else {
        txId = purchase.id!;
        final count = await txn.update(
          'transactions',
          txRow,
          where: 'id = ?',
          whereArgs: [txId],
        );
        if (count == 0) {
          throw StateError('transactions row $txId does not exist');
        }
        // Tax recorded with the purchase follows its wallet and date.
        await txn.update(
          'tax_payments',
          {
            'paid_at': purchase.occurredAt.toIso8601String(),
            'account_id': purchase.accountId,
          },
          where: 'transaction_id = ?',
          whereArgs: [txId],
        );
      }
      final linked = asset.copyWith(purchaseTransactionId: txId);
      final row = toRow(linked);
      if (asset.id == null) {
        return withId(linked, await txn.insert(table, row..remove('id')));
      }
      final count = await txn.update(
        table,
        row,
        where: 'id = ?',
        whereArgs: [asset.id],
      );
      if (count == 0) throw StateError('$table row ${asset.id} does not exist');
      return linked;
    });
  }

  /// The asset bought with entry [transactionId], if any.
  Future<Asset?> purchasedWith(int transactionId) =>
      _firstWhere('purchase_transaction_id = ?', transactionId);

  /// The asset given away in entry [transactionId], if any.
  Future<Asset?> givenIn(int transactionId) =>
      _firstWhere('given_transaction_id = ?', transactionId);

  Future<Asset?> _firstWhere(String where, int id) async {
    final db = await storage.database;
    final rows = await db.query(table, where: where, whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : fromRow(rows.first);
  }
}
