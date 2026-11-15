import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/app_services.dart';
import 'package:money_tracker/app/app_theme.dart';
import 'package:money_tracker/app/screens/import_export_screen.dart';
import 'package:money_tracker/data/models/account.dart';
import 'package:money_tracker/data/models/account_transfer.dart';
import 'package:money_tracker/data/models/category.dart';
import 'package:money_tracker/data/models/model_types.dart';
import 'package:money_tracker/data/models/money_transaction.dart';
import 'package:money_tracker/data/models/tax_payment.dart';
import 'package:money_tracker/data/services/local_database.dart';
import 'package:money_tracker/data/services/transaction_io_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:transaction_io/transaction_io.dart';

var _dbCount = 0;

/// Each call gets its own database file (in-memory databases are shared).
Future<AppServices> _services({bool noIsolate = false}) async {
  final dir = await Directory.systemTemp.createTemp('money_tracker_io_');
  final s = AppServices.withDatabase(
    LocalDatabase(
      factory: noIsolate ? databaseFactoryFfiNoIsolate : databaseFactoryFfi,
      path: '${dir.path}/db${_dbCount++}.db',
    ),
  );
  await s.initialize();
  return s;
}

/// Income with tax, expense in a subcategory, pending and completed owes,
/// standalone tax and a transfer, all in November 2026, plus one in October.
Future<void> _seed(AppServices s) async {
  final cats = await s.categories.getAll();
  final food = cats.firstWhere((c) => c.name == 'Food');
  final salary = cats.firstWhere((c) => c.name == 'Salary');
  final groceries = await s.categories.create(
    Category(name: 'Groceries', type: CategoryType.expense, parentId: food.id),
  );
  final bank = await s.accounts.create(
    const Account(name: 'HBL Bank', type: AccountType.bank),
  );
  Future<void> tx(MoneyTransaction t, [int tax = 0]) =>
      s.transactions.saveWithTax(t, taxMinor: tax);
  await tx(
    MoneyTransaction(
      type: TransactionType.income,
      amountMinor: 10000000,
      categoryId: salary.id!,
      accountId: bank.id,
      occurredAt: DateTime(2026, 11, 1, 9, 15, 42),
      note: 'Pay',
    ),
    1000000,
  );
  await tx(
    MoneyTransaction(
      type: TransactionType.expense,
      amountMinor: 125050,
      categoryId: groceries.id!,
      accountId: 1,
      occurredAt: DateTime(2026, 11, 2),
    ),
  );
  await tx(
    MoneyTransaction(
      type: TransactionType.oweIn,
      amountMinor: 50000,
      categoryId: salary.id!,
      occurredAt: DateTime(2026, 11, 3, 13, 5),
      dueAt: DateTime(2026, 12, 1, 17, 30),
      party: 'Ali',
      oweStatus: OweStatus.pending,
    ),
  );
  await tx(
    MoneyTransaction(
      type: TransactionType.oweOut,
      amountMinor: 70000,
      categoryId: food.id!,
      accountId: 1,
      occurredAt: DateTime(2026, 11, 4),
      party: 'Sara',
      oweStatus: OweStatus.completed,
      completedAt: DateTime(2026, 11, 9, 20, 45),
      dueAt: DateTime(2026, 11, 8),
    ),
  );
  await s.taxes.create(
    TaxPayment(
      amountMinor: 30000,
      paidAt: DateTime(2026, 11, 5),
      accountId: bank.id!,
      note: 'Property',
    ),
  );
  await s.transfers.create(
    AccountTransfer(
      fromAccountId: bank.id!,
      toAccountId: 1,
      amountMinor: 2000000,
      occurredAt: DateTime(2026, 11, 6),
    ),
  );
  await tx(
    MoneyTransaction(
      type: TransactionType.expense,
      amountMinor: 999,
      categoryId: food.id!,
      accountId: 1,
      occurredAt: DateTime(2026, 10, 20),
    ),
  );
}

Future<Map<String, int>> _balances(AppServices s) async => {
  for (final a in await s.accounts.getAll())
    a.name: await s.accounts.balanceMinor(a.id!),
};

void main() {
  sqfliteFfiInit();

  test('export a month and import it into an empty app', () async {
    final source = await _services();
    addTearDown(source.close);
    await _seed(source);

    final exported = await exportTransactions(
      AppTransactionIoStore(source.database),
      from: DateTime(2026, 11),
      to: DateTime(2026, 12),
    );
    expect(exported.rowCount, 6);

    final target = await _services();
    addTearDown(target.close);
    final store = AppTransactionIoStore(target.database);
    final summary = await importTransactions(store, exported.bytes);
    expect(summary.issues, isEmpty);
    expect((summary.rowsRead, summary.imported, summary.duplicates), (6, 6, 0));

    // Wallets and the Food › Groceries subcategory were created/matched.
    final balances = await _balances(target);
    final sourceBalances = await _balances(source);
    expect(balances['HBL Bank'], sourceBalances['HBL Bank']);
    expect(balances['Cash'], sourceBalances['Cash']! + 999);
    final cats = await target.categories.getAll();
    final groceries = cats.firstWhere((c) => c.name == 'Groceries');
    expect(cats.firstWhere((c) => c.id == groceries.parentId).name, 'Food');
    final owes = await target.transactions.pendingOwes();
    expect((owes.single.party, owes.single.amountMinor), ('Ali', 50000));
    expect(owes.single.occurredAt, DateTime(2026, 11, 3, 13, 5));
    expect(owes.single.dueAt, DateTime(2026, 12, 1, 17, 30));
    final pay = (await target.transactions.getAll()).firstWhere(
      (t) => t.type == TransactionType.income,
    );
    expect(pay.occurredAt, DateTime(2026, 11, 1, 9, 15, 42));
    final repaid = (await target.transactions.getAll()).firstWhere(
      (t) => t.type == TransactionType.oweOut,
    );
    expect(repaid.completedAt, DateTime(2026, 11, 9, 20, 45));
    expect(repaid.dueAt, DateTime(2026, 11, 8));
    final linkedTax = (await target.taxes.getAll()).where(
      (t) => t.transactionId != null,
    );
    expect(linkedTax.single.amountMinor, 1000000);

    // Importing the same file again adds nothing.
    final again = await importTransactions(store, exported.bytes);
    expect((again.imported, again.duplicates), (0, 6));
  });

  test('import reports rows the app rejects', () async {
    final s = await _services();
    addTearDown(s.close);
    // Salary is an income category; using it for an expense is refused.
    final bytes = encodeXlsx([
      TxRow(
        type: TxType.expense,
        amountMinor: 100,
        date: DateTime(2026, 1, 1),
        category: 'Salary',
        account: 'Cash',
        sourceRow: 2,
      ),
      TxRow(
        type: TxType.expense,
        amountMinor: 100,
        date: DateTime(2026, 1, 1),
        category: 'Travel / Taxi',
        account: 'Wallet',
      ),
    ]);
    final summary = await importTransactions(
      AppTransactionIoStore(s.database),
      bytes,
    );
    expect(summary.imported, 1);
    expect(summary.issues.single.row, 2);
    expect(summary.issues.single.message, contains('is for income'));
    expect((await s.accounts.getAll()).map((a) => a.name), contains('Wallet'));
  });

  testWidgets('settings screen exports and imports through the module', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = (await tester.runAsync(() => _services(noIsolate: true)))!;
    addTearDown(services.close);
    await tester.runAsync(
      () => services.transactions.saveWithTax(
        MoneyTransaction(
          type: TransactionType.expense,
          amountMinor: 5000,
          categoryId: 4,
          accountId: 1,
          occurredAt: DateTime.now(),
        ),
      ),
    );
    final files = _FakeFiles();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ImportExportScreen(services: services, files: files),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    await settle();
    expect(find.text('1 entry in this period'), findsOneWidget);
    await tester.tap(find.text('Year'));
    await settle();
    expect(find.text('${DateTime.now().year}'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Export to Excel'),
    );
    await settle();
    await settle();
    expect(files.saved.keys.single, startsWith('transactions_'));
    expect(decodeXlsx(files.saved.values.single).rows.single.amountMinor, 5000);

    files.toPick = files.saved.values.single;
    await tester.tap(find.text('Choose Excel file'));
    await settle();
    await settle();
    expect(find.text('Last import'), findsOneWidget);
    expect(find.text('Skipped as duplicates'), findsOneWidget);
    expect(find.textContaining('Imported 0, skipped 1'), findsOneWidget);
  });
}

class _FakeFiles implements ExcelFiles {
  final saved = <String, Uint8List>{};
  Uint8List? toPick;

  @override
  Future<String?> save(String fileName, Uint8List bytes) async {
    saved[fileName] = bytes;
    return fileName;
  }

  @override
  Future<Uint8List?> pick() async => toPick;
}
