import '../models/asset.dart';
import 'crud_repository.dart';

class AssetRepository extends CrudRepository<Asset> {
  AssetRepository(super.storage);

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
    'notes': value.notes,
  };

  @override
  Asset withId(Asset value, int id) => value.copyWith(id: id);

  @override
  Future<void> validate(Asset value, {int? updatingId}) async {
    if (value.name.trim().isEmpty) {
      throw ArgumentError('Asset name is required');
    }
    if (value.purchaseAmountMinor < 0 || value.currentValueMinor < 0) {
      throw ArgumentError('Asset values cannot be negative');
    }
    if (value.purchaseTransactionId != null) {
      final db = await storage.database;
      final rows = await db.query(
        'transactions',
        columns: ['type'],
        where: 'id = ?',
        whereArgs: [value.purchaseTransactionId],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['type'] != 'expense') {
        throw ArgumentError(
          'Asset purchase must link to an expense transaction',
        );
      }
    }
  }
}
