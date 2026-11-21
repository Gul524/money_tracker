import '../models/tax_payment.dart';
import 'crud_repository.dart';

class TaxRepository extends CrudRepository<TaxPayment> {
  TaxRepository(super.storage);

  @override
  String get table => 'tax_payments';

  @override
  TaxPayment fromRow(Map<String, Object?> row) => TaxPayment(
    id: row['id'] as int,
    amountMinor: row['amount_minor'] as int,
    paidAt: DateTime.parse(row['paid_at'] as String),
    accountId: row['account_id'] as int,
    note: row['note'] as String?,
    transactionId: row['transaction_id'] as int?,
    taxRateId: row['tax_rate_id'] as int?,
    taxName: row['tax_name'] as String?,
    taxCode: row['tax_code'] as String?,
    rateBasisPoints: row['rate_bp'] as int?,
    inclusive: row['inclusive'] == null ? null : row['inclusive'] == 1,
  );

  @override
  Map<String, Object?> toRow(TaxPayment value) => {
    'id': value.id,
    'amount_minor': value.amountMinor,
    'paid_at': value.paidAt.toIso8601String(),
    'account_id': value.accountId,
    'note': value.note,
    'transaction_id': value.transactionId,
    'tax_rate_id': value.taxRateId,
    'tax_name': value.taxName,
    'tax_code': value.taxCode,
    'rate_bp': value.rateBasisPoints,
    'inclusive': value.inclusive == null ? null : (value.inclusive! ? 1 : 0),
  };

  @override
  TaxPayment withId(TaxPayment value, int id) => value.copyWith(id: id);

  @override
  Future<void> validate(TaxPayment value, {int? updatingId}) async {
    if (value.amountMinor <= 0) {
      throw ArgumentError('Tax amount must be positive');
    }
  }

  Future<List<TaxPayment>> paidInMonth(int year, int month) async {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    final db = await storage.database;
    final rows = await db.query(
      table,
      where: 'paid_at >= ? AND paid_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'paid_at DESC',
    );
    return rows.map(fromRow).toList();
  }

  Future<List<TaxPayment>> history({int? limit}) async {
    final db = await storage.database;
    final rows = await db.query(
      table,
      orderBy: 'paid_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(fromRow).toList();
  }

  /// The tax recorded together with transaction [transactionId], if any.
  Future<TaxPayment?> forTransaction(int transactionId) async {
    final db = await storage.database;
    final rows = await db.query(
      table,
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    return rows.isEmpty ? null : fromRow(rows.first);
  }
}
