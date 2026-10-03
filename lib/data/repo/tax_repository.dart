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
  );

  @override
  Map<String, Object?> toRow(TaxPayment value) => {
    'id': value.id,
    'amount_minor': value.amountMinor,
    'paid_at': value.paidAt.toIso8601String(),
    'account_id': value.accountId,
    'note': value.note,
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
}
