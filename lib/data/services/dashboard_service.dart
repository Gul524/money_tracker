import '../models/account.dart';
import '../repo/account_repository.dart';
import 'local_database.dart';

class AccountOverview {
  const AccountOverview(this.account, this.balanceMinor);
  final Account account;
  final int balanceMinor;
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
