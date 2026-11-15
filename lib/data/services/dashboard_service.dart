import '../models/account.dart';
import '../repo/account_repository.dart';
import 'local_database.dart';

class AccountOverview {
  const AccountOverview(this.account, this.balanceMinor);
  final Account account;
  final int balanceMinor;
}

class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.isIncome,
    required this.totalMinor,
    this.parentId,
    this.icon,
    this.color,
  });
  final int categoryId;
  final int? parentId;
  final String? icon;
  final String? color;
  final String name;
  final bool isIncome;
  final int totalMinor;
}

class DashboardSummary {
  const DashboardSummary({
    required this.asOf,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.oweInMinor,
    required this.oweOutMinor,
    required this.taxPaidMinor,
    required this.assetValueMinor,
    required this.accounts,
  });

  final DateTime asOf;
  final int incomeMinor;
  final int expenseMinor;
  final int oweInMinor;
  final int oweOutMinor;
  final int taxPaidMinor;
  final int assetValueMinor;
  final List<AccountOverview> accounts;
  int get totalBalanceMinor =>
      accounts.fold<int>(0, (sum, account) => sum + account.balanceMinor);
}

class DashboardService {
  DashboardService(this.storage) : _accounts = AccountRepository(storage);

  final LocalDatabase storage;
  final AccountRepository _accounts;

  Future<DashboardSummary> currentMonth({DateTime? now}) async {
    final date = now ?? DateTime.now();
    final start = DateTime(date.year, date.month).toIso8601String();
    final end = DateTime(date.year, date.month + 1).toIso8601String();
    final db = await storage.database;
    final monthly = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount_minor ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount_minor ELSE 0 END), 0) AS expense
      FROM transactions WHERE occurred_at >= ? AND occurred_at < ?
    ''',
      [start, end],
    );
    final owes = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'oweIn' THEN amount_minor ELSE 0 END), 0) AS owe_in,
        COALESCE(SUM(CASE WHEN type = 'oweOut' THEN amount_minor ELSE 0 END), 0) AS owe_out
      FROM transactions WHERE owe_status = 'pending'
    ''');
    final tax = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS total FROM tax_payments
      WHERE paid_at >= ? AND paid_at < ?
    ''',
      [start, end],
    );
    final assets = await db.rawQuery('''
      SELECT COALESCE(SUM(current_value_minor), 0) AS total FROM assets
    ''');
    final accounts = await _loadAccounts();
    return DashboardSummary(
      asOf: date,
      incomeMinor: monthly.first['income'] as int,
      expenseMinor: monthly.first['expense'] as int,
      oweInMinor: owes.first['owe_in'] as int,
      oweOutMinor: owes.first['owe_out'] as int,
      taxPaidMinor: tax.first['total'] as int,
      assetValueMinor: assets.first['total'] as int,
      accounts: accounts,
    );
  }

  /// Income and expense totals per category for the month containing [month],
  /// largest first. Owes are excluded because they are not income/expense.
  Future<List<CategoryTotal>> categoryTotals(DateTime month) =>
      categoryTotalsBetween(
        DateTime(month.year, month.month),
        DateTime(month.year, month.month + 1),
      );

  /// Income and expense totals per category for `from <= date < to`.
  Future<List<CategoryTotal>> categoryTotalsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final start = from.toIso8601String();
    final end = to.toIso8601String();
    final db = await storage.database;
    final rows = await db.rawQuery(
      '''
      SELECT t.category_id AS id, c.name AS name, c.parent_id AS parent_id,
        c.icon AS icon, c.color AS color,
        t.type AS type,
        SUM(t.amount_minor) AS total
      FROM transactions t JOIN categories c ON c.id = t.category_id
      WHERE t.type IN ('income', 'expense')
        AND t.occurred_at >= ? AND t.occurred_at < ?
      GROUP BY t.category_id, t.type
      ORDER BY total DESC
    ''',
      [start, end],
    );
    return [
      for (final row in rows)
        CategoryTotal(
          categoryId: row['id'] as int,
          name: row['name'] as String,
          parentId: row['parent_id'] as int?,
          icon: row['icon'] as String?,
          color: row['color'] as String?,
          isIncome: row['type'] == 'income',
          totalMinor: row['total'] as int,
        ),
    ];
  }

  Future<List<AccountOverview>> _loadAccounts() async {
    final accounts = await _accounts.getAll();
    final result = <AccountOverview>[];
    for (final account in accounts) {
      result.add(
        AccountOverview(account, await _accounts.balanceMinor(account.id!)),
      );
    }
    return result;
  }
}
