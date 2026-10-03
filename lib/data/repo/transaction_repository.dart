import '../models/model_types.dart';
import '../models/money_transaction.dart';
import 'category_repository.dart';
import 'crud_repository.dart';

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
}
