import '../models/account.dart';
import '../repo/account_repository.dart';
import 'dashboard_service.dart';
import 'local_database.dart';

/// Money in and out of one account during a report period.
class AccountFlow {
  const AccountFlow({
    required this.account,
    required this.inMinor,
    required this.outMinor,
    required this.taxMinor,
    required this.balanceMinor,
  });
  final Account account;

  /// Income, received owes, money borrowed and transfers in.
  final int inMinor;

  /// Expenses, repaid owes, money lent, tax and transfers out.
  final int outMinor;

  /// Part of [outMinor] that was tax.
  final int taxMinor;

  /// Balance today (not limited to the period).
  final int balanceMinor;
  int get netMinor => inMinor - outMinor;
}

/// Income, spending and tax for one calendar month inside a period.
class MonthBucket {
  const MonthBucket({
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.taxMinor,
  });
  final DateTime month;
  final int incomeMinor;
  final int expenseMinor;
  final int taxMinor;
}

class PeriodReport {
  const PeriodReport({
    required this.start,
    required this.end,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.taxMinor,
    required this.oweReceivedMinor,
    required this.oweRepaidMinor,
    this.lentMinor = 0,
    this.borrowedMinor = 0,
    required this.entryCount,
    required this.categories,
    required this.accounts,
    required this.months,
  });

  /// Inclusive start of the period.
  final DateTime start;

  /// Exclusive end of the period.
  final DateTime end;
  final int incomeMinor;
  final int expenseMinor;
  final int taxMinor;

  /// Owes settled during the period (money received back / paid back).
  final int oweReceivedMinor;
  final int oweRepaidMinor;

  /// Money that left a wallet as a loan (owed to me) / came into a wallet as
  /// a loan (I owe) during the period. Not income or spending.
  final int lentMinor;
  final int borrowedMinor;

  /// Income, expense and tax entries in the period.
  final int entryCount;
  final List<CategoryTotal> categories;
  final List<AccountFlow> accounts;
  final List<MonthBucket> months;

  int get netMinor => incomeMinor - expenseMinor - taxMinor;
  int get outflowMinor => expenseMinor + taxMinor;
}

/// Builds reports for any date range from transactions, tax and transfers.
class ReportService {
  ReportService(this.storage)
    : _accounts = AccountRepository(storage),
      _dashboard = DashboardService(storage);

  final LocalDatabase storage;
  final AccountRepository _accounts;
  final DashboardService _dashboard;

  /// Report for `start <= date < end`.
  Future<PeriodReport> build(DateTime start, DateTime end) async {
    final db = await storage.database;
    final range = [start.toIso8601String(), end.toIso8601String()];

    final totals = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount_minor END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount_minor END), 0) AS expense,
        COUNT(*) AS entries
      FROM transactions
      WHERE type IN ('income', 'expense') AND occurred_at >= ? AND occurred_at < ?
    ''', range);
    final tax = await db.rawQuery('''
      SELECT COALESCE(SUM(amount_minor), 0) AS total, COUNT(*) AS entries,
        COALESCE(SUM(CASE WHEN transaction_id IS NULL THEN 1 ELSE 0 END), 0) AS standalone
      FROM tax_payments WHERE paid_at >= ? AND paid_at < ?
    ''', range);
    final owes = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'oweIn' THEN amount_minor END), 0) AS received,
        COALESCE(SUM(CASE WHEN type = 'oweOut' THEN amount_minor END), 0) AS repaid
      FROM transactions
      WHERE owe_status = 'completed' AND completed_at >= ? AND completed_at < ?
    ''', range);
    final loans = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'oweIn' THEN amount_minor END), 0) AS lent,
        COALESCE(SUM(CASE WHEN type = 'oweOut' THEN amount_minor END), 0) AS borrowed
      FROM transactions
      WHERE exchange_account_id IS NOT NULL AND occurred_at >= ? AND occurred_at < ?
    ''', range);

    return PeriodReport(
      start: start,
      end: end,
      incomeMinor: totals.first['income'] as int,
      expenseMinor: totals.first['expense'] as int,
      taxMinor: tax.first['total'] as int,
      oweReceivedMinor: owes.first['received'] as int,
      oweRepaidMinor: owes.first['repaid'] as int,
      lentMinor: loans.first['lent'] as int,
      borrowedMinor: loans.first['borrowed'] as int,
      entryCount:
          (totals.first['entries'] as int) + (tax.first['standalone'] as int),
      categories: await _dashboard.categoryTotalsBetween(start, end),
      accounts: await _accountFlows(range),
      months: await _months(start, end, range),
    );
  }

  Future<List<AccountFlow>> _accountFlows(List<String> range) async {
    final db = await storage.database;
    final inflow = <int, int>{};
    final outflow = <int, int>{};
    final taxes = <int, int>{};
    void add(Map<int, int> map, Object? id, Object? amount) {
      if (id == null) return;
      map[id as int] = (map[id] ?? 0) + (amount as int);
    }

    for (final row in await db.rawQuery('''
      SELECT account_id AS id, type, SUM(amount_minor) AS total
      FROM transactions
      WHERE account_id IS NOT NULL AND (
        (type IN ('income', 'expense') AND occurred_at >= ?1 AND occurred_at < ?2)
        OR (owe_status = 'completed' AND completed_at >= ?1 AND completed_at < ?2))
      GROUP BY account_id, type
    ''', range)) {
      final incoming = row['type'] == 'income' || row['type'] == 'oweIn';
      add(incoming ? inflow : outflow, row['id'], row['total']);
    }
    // Money lent out of / borrowed into a wallet when an owe started.
    for (final row in await db.rawQuery('''
      SELECT exchange_account_id AS id, type, SUM(amount_minor) AS total
      FROM transactions
      WHERE exchange_account_id IS NOT NULL
        AND occurred_at >= ? AND occurred_at < ?
      GROUP BY exchange_account_id, type
    ''', range)) {
      add(row['type'] == 'oweOut' ? inflow : outflow, row['id'], row['total']);
    }
    for (final row in await db.rawQuery('''
      SELECT account_id AS id, SUM(amount_minor) AS total FROM tax_payments
      WHERE paid_at >= ? AND paid_at < ? GROUP BY account_id
    ''', range)) {
      add(outflow, row['id'], row['total']);
      add(taxes, row['id'], row['total']);
    }
    for (final row in await db.rawQuery('''
      SELECT from_account_id AS id, SUM(amount_minor) AS total FROM transfers
      WHERE occurred_at >= ? AND occurred_at < ? GROUP BY from_account_id
    ''', range)) {
      add(outflow, row['id'], row['total']);
    }
    for (final row in await db.rawQuery('''
      SELECT to_account_id AS id, SUM(amount_minor) AS total FROM transfers
      WHERE occurred_at >= ? AND occurred_at < ? GROUP BY to_account_id
    ''', range)) {
      add(inflow, row['id'], row['total']);
    }

    final result = <AccountFlow>[];
    for (final account in await _accounts.getAll()) {
      final id = account.id!;
      // Archived accounts only appear when they had activity in the period.
      if (account.isArchived && inflow[id] == null && outflow[id] == null) {
        continue;
      }
      result.add(
        AccountFlow(
          account: account,
          inMinor: inflow[id] ?? 0,
          outMinor: outflow[id] ?? 0,
          taxMinor: taxes[id] ?? 0,
          balanceMinor: await _accounts.balanceMinor(id),
        ),
      );
    }
    result.sort(
      (a, b) =>
          a.account.name.toLowerCase().compareTo(b.account.name.toLowerCase()),
    );
    return result;
  }

  Future<List<MonthBucket>> _months(
    DateTime start,
    DateTime end,
    List<String> range,
  ) async {
    final db = await storage.database;
    final income = <String, int>{};
    final expense = <String, int>{};
    final tax = <String, int>{};
    for (final row in await db.rawQuery('''
      SELECT substr(occurred_at, 1, 7) AS ym, type, SUM(amount_minor) AS total
      FROM transactions
      WHERE type IN ('income', 'expense') AND occurred_at >= ? AND occurred_at < ?
      GROUP BY ym, type
    ''', range)) {
      final map = row['type'] == 'income' ? income : expense;
      map[row['ym'] as String] = row['total'] as int;
    }
    for (final row in await db.rawQuery('''
      SELECT substr(paid_at, 1, 7) AS ym, SUM(amount_minor) AS total
      FROM tax_payments WHERE paid_at >= ? AND paid_at < ? GROUP BY ym
    ''', range)) {
      tax[row['ym'] as String] = row['total'] as int;
    }

    final buckets = <MonthBucket>[];
    var month = DateTime(start.year, start.month);
    while (month.isBefore(end)) {
      final key =
          '${month.year.toString().padLeft(4, '0')}-'
          '${month.month.toString().padLeft(2, '0')}';
      buckets.add(
        MonthBucket(
          month: month,
          incomeMinor: income[key] ?? 0,
          expenseMinor: expense[key] ?? 0,
          taxMinor: tax[key] ?? 0,
        ),
      );
      month = DateTime(month.year, month.month + 1);
    }
    return buckets;
  }
}
