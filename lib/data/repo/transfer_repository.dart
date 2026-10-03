import '../models/account_transfer.dart';
import 'crud_repository.dart';

class TransferRepository extends CrudRepository<AccountTransfer> {
  TransferRepository(super.storage);
  @override
  String get table => 'transfers';
  @override
  AccountTransfer fromRow(Map<String, Object?> row) => AccountTransfer(
    id: row['id'] as int,
    fromAccountId: row['from_account_id'] as int,
    toAccountId: row['to_account_id'] as int,
    amountMinor: row['amount_minor'] as int,
    occurredAt: DateTime.parse(row['occurred_at'] as String),
    note: row['note'] as String?,
  );
  @override
  Map<String, Object?> toRow(AccountTransfer value) => {
    'id': value.id,
    'from_account_id': value.fromAccountId,
    'to_account_id': value.toAccountId,
    'amount_minor': value.amountMinor,
    'occurred_at': value.occurredAt.toIso8601String(),
    'note': value.note,
  };
  @override
  AccountTransfer withId(AccountTransfer value, int id) =>
      value.copyWith(id: id);
  @override
  Future<void> validate(AccountTransfer value, {int? updatingId}) async {
    if (value.amountMinor <= 0) throw ArgumentError('Amount must be positive');
    if (value.fromAccountId == value.toAccountId) {
      throw ArgumentError('Choose two different accounts');
    }
  }

  Future<List<AccountTransfer>> history({int? limit}) async {
    final db = await storage.database;
    final rows = await db.query(
      table,
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(fromRow).toList();
  }
}
