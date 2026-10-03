import '../models/account.dart';
import '../models/model_types.dart';
import 'crud_repository.dart';

class AccountRepository extends CrudRepository<Account> {
  AccountRepository(super.storage);

  @override
  String get table => 'accounts';

  @override
  Account fromRow(Map<String, Object?> row) => Account(
    id: row['id'] as int,
    name: row['name'] as String,
    type: AccountType.values.byName(row['type'] as String),
    openingBalanceMinor: row['opening_balance_minor'] as int,
    isArchived: row['is_archived'] == 1,
  );

  @override
  Map<String, Object?> toRow(Account value) => {
    'id': value.id,
    'name': value.name.trim(),
    'type': value.type.name,
    'opening_balance_minor': value.openingBalanceMinor,
    'is_archived': value.isArchived ? 1 : 0,
  };

  @override
  Account withId(Account value, int id) => value.copyWith(id: id);

  @override
  Future<void> validate(Account value, {int? updatingId}) async {
    if (value.name.trim().isEmpty) {
      throw ArgumentError('Account name is required');
    }
  }

  Future<int> balanceMinor(int accountId) async {
    final account = await getById(accountId);
    if (account == null) throw StateError('Account $accountId does not exist');
    final db = await storage.database;
    final transactionRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN type IN ('income', 'oweIn') THEN amount_minor
        ELSE -amount_minor END), 0) AS amount
      FROM transactions WHERE account_id = ?
        AND (type IN ('income', 'expense') OR owe_status = 'completed')
    ''',
      [accountId],
    );
    final taxRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS amount
      FROM tax_payments WHERE account_id = ?
    ''',
      [accountId],
    );
    final transferRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN to_account_id = ? THEN amount_minor
        ELSE -amount_minor END), 0) AS amount
      FROM transfers WHERE from_account_id = ? OR to_account_id = ?
    ''',
      [accountId, accountId, accountId],
    );
    return account.openingBalanceMinor +
        (transactionRows.first['amount'] as int) -
        (taxRows.first['amount'] as int) +
        (transferRows.first['amount'] as int);
  }
}
