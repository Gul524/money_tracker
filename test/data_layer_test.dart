import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/data/models/account.dart';
import 'package:money_tracker/data/models/account_transfer.dart';
import 'package:money_tracker/data/models/asset.dart';
import 'package:money_tracker/data/models/category.dart';
import 'package:money_tracker/data/models/model_types.dart';
import 'package:money_tracker/data/models/money_transaction.dart';
import 'package:money_tracker/data/models/tax_payment.dart';
import 'package:money_tracker/data/repo/account_repository.dart';
import 'package:money_tracker/data/repo/asset_repository.dart';
import 'package:money_tracker/data/repo/category_repository.dart';
import 'package:money_tracker/data/repo/tax_repository.dart';
import 'package:money_tracker/data/repo/transaction_repository.dart';
import 'package:money_tracker/data/repo/transfer_repository.dart';
import 'package:money_tracker/data/services/dashboard_service.dart';
import 'package:money_tracker/data/services/local_database.dart';
import 'package:money_tracker/data/services/settings_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('linked records, balances, owing, tax and dashboard totals', () async {
    final storage = LocalDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(storage.close);
    final categories = CategoryRepository(storage);
    final accounts = AccountRepository(storage);
    final transactions = TransactionRepository(storage);
    final assets = AssetRepository(storage);
    final taxes = TaxRepository(storage);
    final date = DateTime(2026, 10, 3);

    final income = await categories.create(
      const Category(name: 'Work', type: CategoryType.income),
    );
    final expense = await categories.create(
      const Category(name: 'Home', type: CategoryType.expense),
    );
    final child = await categories.create(
      Category(
        name: 'Furniture',
        type: CategoryType.expense,
        parentId: expense.id,
      ),
    );
    final account = await accounts.create(
      const Account(
        name: 'Cash',
        type: AccountType.cash,
        openingBalanceMinor: 1000,
      ),
    );

    await transactions.create(
      MoneyTransaction(
        type: TransactionType.income,
        amountMinor: 500,
        categoryId: income.id!,
        accountId: account.id,
        occurredAt: date,
      ),
    );
    final purchase = await transactions.create(
      MoneyTransaction(
        type: TransactionType.expense,
        amountMinor: 200,
        categoryId: child.id!,
        accountId: account.id,
        occurredAt: date,
      ),
    );
    final owe = await transactions.create(
      MoneyTransaction(
        type: TransactionType.oweIn,
        amountMinor: 300,
        categoryId: income.id!,
        occurredAt: date,
        dueAt: date.add(const Duration(days: 7)),
        oweStatus: OweStatus.pending,
      ),
    );
    await taxes.create(
      TaxPayment(amountMinor: 50, paidAt: date, accountId: account.id!),
    );
    await assets.create(
      Asset(
        name: 'Desk',
        acquiredOn: date,
        purchaseAmountMinor: 200,
        currentValueMinor: 180,
        purchaseTransactionId: purchase.id,
      ),
    );

    expect(await accounts.balanceMinor(account.id!), 1250);
    expect((await transactions.pendingOwes()).single.id, owe.id);
    final before = await DashboardService(storage).currentMonth(now: date);
    expect(before.incomeMinor, 500);
    expect(before.expenseMinor, 200);
    expect(before.oweInMinor, 300);
    expect(before.taxPaidMinor, 50);
    expect(before.assetValueMinor, 180);

    await transactions.completeOwe(owe.id!, account.id!, at: date);
    expect(await transactions.pendingOwes(), isEmpty);
    expect(await accounts.balanceMinor(account.id!), 1550);
    expect(await categories.childrenOf(expense.id), hasLength(1));
    await expectLater(categories.delete(income.id!), throwsException);
    expect(Category.fromJson(income.toJson()).name, 'Work');
    expect(income.copyWith(parentId: expense.id).parentId, expense.id);

    final bank = await accounts.create(
      const Account(name: 'Bank', type: AccountType.bank),
    );
    final transfer = await TransferRepository(storage).create(
      AccountTransfer(
        fromAccountId: account.id!,
        toAccountId: bank.id!,
        amountMinor: 400,
        occurredAt: date,
      ),
    );
    expect(AccountTransfer.fromJson(transfer.toJson()).amountMinor, 400);
    expect(await accounts.balanceMinor(account.id!), 1150);
    expect(await accounts.balanceMinor(bank.id!), 400);
    expect(
      (await DashboardService(storage).currentMonth(now: date)).incomeMinor,
      500,
    );
    final settings = SettingsService(storage);
    await settings.setCurrency('USD');
    expect(await settings.currency(), 'USD');
    expect(await settings.themeMode(), 'system');
    await settings.setThemeMode('dark');
    expect(await settings.themeMode(), 'dark');
    await settings.setThemeMode('system');
    expect(await settings.themeMode(), 'system');
  });
}
