import 'dart:io';

import 'package:flutter/material.dart' show Color, Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/widgets/category_icons.dart';
import 'package:money_tracker/app/app_services.dart';
import 'package:money_tracker/app/controllers/base_controller.dart';
import 'package:money_tracker/app/controllers/history_controller.dart';
import 'package:money_tracker/app/controllers/reports_controller.dart';
import 'package:money_tracker/app/controllers/category_controller.dart';
import 'package:money_tracker/app/controllers/transaction_controller.dart';
import 'package:money_tracker/app/controllers/transfer_controller.dart';
import 'package:money_tracker/data/services/defaults_service.dart';
import 'package:money_tracker/app/date_range.dart';
import 'package:money_tracker/data/models/account.dart';
import 'package:money_tracker/data/models/account_transfer.dart';
import 'package:money_tracker/app/controllers/asset_controller.dart';
import 'package:money_tracker/data/models/asset.dart';
import 'package:money_tracker/data/repo/transaction_repository.dart';
import 'package:money_tracker/data/services/report_service.dart';
import 'package:money_tracker/data/models/category.dart';
import 'package:money_tracker/data/models/model_types.dart';
import 'package:money_tracker/data/models/money_transaction.dart';
import 'package:money_tracker/data/models/tax_payment.dart';
import 'package:money_tracker/data/repo/tax_repository.dart';
import 'package:money_tracker/data/services/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seeded world used by most tests:
/// accounts Cash (opening 10,000) and Bank (opening 0);
/// categories Salary (income), Food (expense) with child Groceries.
class _World {
  _World(this.services);
  final AppServices services;
  late Account cash;
  late Account bank;
  late Category salary;
  late Category food;
  late Category groceries;

  static Future<_World> create() async {
    final services = AppServices.withDatabase(
      LocalDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    );
    await services.initialize();
    final w = _World(services);
    final all = await services.categories.getAll();
    w.salary = all.firstWhere((c) => c.name == 'Salary');
    w.food = all.firstWhere((c) => c.name == 'Food');
    w.groceries = await services.categories.create(
      Category(
        name: 'Groceries',
        type: CategoryType.expense,
        parentId: w.food.id,
      ),
    );
    w.cash = (await services.accounts.getAll()).single;
    w.cash = await services.accounts.update(
      w.cash.copyWith(openingBalanceMinor: 1000000),
    );
    w.bank = await services.accounts.create(
      const Account(name: 'Bank', type: AccountType.bank),
    );
    return w;
  }

  Future<MoneyTransaction> add(
    TransactionType type,
    int amount,
    Category category,
    Account account,
    DateTime at, {
    int tax = 0,
    String? note,
  }) => services.transactions.saveWithTax(
    MoneyTransaction(
      type: type,
      amountMinor: amount,
      categoryId: category.id!,
      accountId: account.id,
      occurredAt: at,
      note: note,
    ),
    taxMinor: tax,
  );
}

Future<void> _idle(BaseController c) async {
  await Future<void>.delayed(Duration.zero);
  while (c.busy) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  sqfliteFfiInit();

  test('tax recorded with a transaction follows it', () async {
    final w = await _World.create();
    addTearDown(w.services.close);
    final at = DateTime(2026, 11, 5);

    final lunch = await w.add(
      TransactionType.expense,
      100000,
      w.food,
      w.cash,
      at,
      tax: 17000,
    );
    final pay = await w.add(
      TransactionType.income,
      5000000,
      w.salary,
      w.bank,
      at,
      tax: 500000,
    );
    expect(
      await w.services.accounts.balanceMinor(w.cash.id!),
      1000000 - 117000,
    );
    expect(await w.services.accounts.balanceMinor(w.bank.id!), 4500000);
    expect(
      (await w.services.taxes.forTransaction(lunch.id!))!.amountMinor,
      17000,
    );

    // Linked tax is shown on its transaction, not as a separate row.
    final feed = await w.services.activity.history();
    expect(feed, hasLength(2));
    expect(
      feed.firstWhere((i) => i.transaction?.id == lunch.id).taxMinor,
      17000,
    );
    expect(
      feed.firstWhere((i) => i.transaction?.id == pay.id).netEffectMinor,
      4500000,
    );

    // Moving the entry to another account moves its tax too.
    await w.services.transactions.saveWithTax(
      lunch.copyWith(accountId: w.bank.id),
      taxMinor: 20000,
    );
    expect(await w.services.accounts.balanceMinor(w.cash.id!), 1000000);
    expect(
      await w.services.accounts.balanceMinor(w.bank.id!),
      4500000 - 120000,
    );

    // Clearing the tax removes it; deleting the entry removes its tax.
    await w.services.transactions.saveWithTax(
      lunch.copyWith(accountId: w.bank.id),
    );
    expect(await w.services.taxes.forTransaction(lunch.id!), isNull);
    await w.services.transactions.delete(pay.id!);
    expect(await w.services.taxes.getAll(), isEmpty);

    // Owes can't carry tax.
    await expectLater(
      w.services.transactions.saveWithTax(
        MoneyTransaction(
          type: TransactionType.oweIn,
          amountMinor: 100,
          categoryId: w.salary.id!,
          occurredAt: at,
          oweStatus: OweStatus.pending,
        ),
        taxMinor: 10,
      ),
      throwsArgumentError,
    );
  });

  test('version 3 databases gain the tax link column', () async {
    final dir = await Directory.systemTemp.createTemp('money_tracker_v3_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v3.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE accounts (id INTEGER PRIMARY KEY, name TEXT NOT NULL,
              type TEXT NOT NULL, opening_balance_minor INTEGER NOT NULL DEFAULT 0,
              is_archived INTEGER NOT NULL DEFAULT 0)
          ''');
          await db.execute('''
            CREATE TABLE tax_payments (id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount_minor INTEGER NOT NULL, paid_at TEXT NOT NULL,
              account_id INTEGER NOT NULL, note TEXT)
          ''');
          await db.insert('accounts', {'name': 'Cash', 'type': 'cash'});
          await db.insert('tax_payments', {
            'amount_minor': 500,
            'paid_at': DateTime(2026).toIso8601String(),
            'account_id': 1,
          });
        },
      ),
    );
    await legacy.close();

    final storage = LocalDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(storage.close);
    final tax = (await TaxRepository(storage).getAll()).single;
    expect(tax.amountMinor, 500);
    expect(tax.transactionId, isNull);
    final columns = await (await storage.database).rawQuery(
      'PRAGMA table_info(tax_payments)',
    );
    expect(columns.map((c) => c['name']), contains('transaction_id'));
  });

  test('period report totals, accounts, tax and months', () async {
    final w = await _World.create();
    addTearDown(w.services.close);
    await w.add(
      TransactionType.income,
      300000,
      w.salary,
      w.bank,
      DateTime(2026, 9, 1),
      tax: 30000,
    );
    await w.add(
      TransactionType.expense,
      5000,
      w.groceries,
      w.cash,
      DateTime(2026, 9, 10),
    );
    await w.add(
      TransactionType.expense,
      7000,
      w.food,
      w.cash,
      DateTime(2026, 11, 2),
      tax: 1000,
    );
    await w.add(
      TransactionType.expense,
      9999,
      w.food,
      w.cash,
      DateTime(2026, 12, 1),
    );
    await w.services.transfers.create(
      AccountTransfer(
        fromAccountId: w.bank.id!,
        toAccountId: w.cash.id!,
        amountMinor: 20000,
        occurredAt: DateTime(2026, 10, 15),
      ),
    );
    await w.services.taxes.create(
      TaxPayment(
        amountMinor: 2000,
        paidAt: DateTime(2026, 10, 20),
        accountId: w.cash.id!,
      ),
    );

    final report = await w.services.reports.build(
      DateTime(2026, 9),
      DateTime(2026, 12),
    );
    expect(report.incomeMinor, 300000);
    expect(report.expenseMinor, 12000);
    expect(report.taxMinor, 33000);
    expect(report.netMinor, 300000 - 12000 - 33000);
    expect(report.entryCount, 4); // 3 transactions + 1 standalone tax
    expect(report.months.map((m) => m.month.month), [9, 10, 11]);
    expect(report.months.first.taxMinor, 30000);
    expect(report.months[1].expenseMinor, 0);

    final cash = report.accounts.firstWhere((a) => a.account.id == w.cash.id);
    final bank = report.accounts.firstWhere((a) => a.account.id == w.bank.id);
    expect(cash.inMinor, 20000);
    expect(cash.outMinor, 5000 + 7000 + 1000 + 2000);
    expect(cash.taxMinor, 3000);
    expect(bank.inMinor, 300000);
    expect(bank.outMinor, 30000 + 20000);

    // Subcategories roll up into their parent.
    final reports = ReportsController(w.services, now: DateTime(2026, 11, 15));
    addTearDown(reports.dispose);
    await _idle(reports);
    reports.setCustomRange(DateRange(DateTime(2026, 9), DateTime(2026, 12)));
    await _idle(reports);
    final food = reports.spending.single;
    expect(food.name, 'Food');
    expect(food.totalMinor, 12000);
    expect(food.parts.map((p) => p.$1), ['Food', 'Groceries']);
  });

  test('report periods step and stop at the current one', () async {
    final w = await _World.create();
    addTearDown(w.services.close);
    final c = ReportsController(w.services, now: DateTime(2026, 11, 15));
    addTearDown(c.dispose);
    await _idle(c);
    expect(c.range.label, 'November 2026');
    expect(c.canGoNext, isFalse);
    c.previous();
    expect(c.range.label, 'October 2026');
    expect(c.canGoNext, isTrue);

    c.setPeriod(ReportPeriod.sixMonths);
    expect(c.range.label, 'Jun – Nov 2026');
    c.previous();
    expect(c.range.label, 'Dec 2025 – May 2026');

    c.setPeriod(ReportPeriod.year);
    expect(c.range.label, '2026');
    expect(c.canGoNext, isFalse);

    c.setCustomRange(
      DateRange.days(DateTime(2026, 3, 3), DateTime(2026, 3, 15)),
    );
    expect(c.period, ReportPeriod.custom);
    expect(c.canStep, isFalse);
    expect(c.range.label, '3 – 15 Mar 2026');
    await _idle(c);
  });

  test(
    'history filters by account, category tree, dates, type and amount',
    () async {
      final w = await _World.create();
      addTearDown(w.services.close);
      await w.add(
        TransactionType.expense,
        125050,
        w.groceries,
        w.cash,
        DateTime(2026, 11, 3),
        note: 'Weekly shop',
      );
      await w.add(
        TransactionType.expense,
        4000,
        w.food,
        w.bank,
        DateTime(2026, 10, 8),
        tax: 600,
      );
      await w.add(
        TransactionType.income,
        900000,
        w.salary,
        w.bank,
        DateTime(2026, 11, 1),
      );
      await w.services.transfers.create(
        AccountTransfer(
          fromAccountId: w.bank.id!,
          toAccountId: w.cash.id!,
          amountMinor: 50000,
          occurredAt: DateTime(2026, 11, 2),
        ),
      );

      final h = HistoryController(w.services);
      addTearDown(h.dispose);
      await _idle(h);
      expect(h.visibleItems, hasLength(4));

      h.setAccount(w.cash.id);
      expect(
        h.visibleItems.map((i) => i.title),
        containsAll(['Groceries', 'Transfer']),
      );
      expect(h.visibleItems, hasLength(2));
      // Transfer in (+50,000) and the groceries (−125,050) from Cash's view.
      expect(h.totalsOf(h.visibleItems), (50000, 125050));
      h.setAccount(null);

      h.setCategory(w.food.id); // includes Groceries
      expect(h.visibleItems, hasLength(2));
      h.setCategory(w.groceries.id);
      expect(h.visibleItems.single.title, 'Groceries');
      h.clearFilters();

      h.setPreset(DatePreset.lastMonth, now: DateTime(2026, 11, 15));
      expect(h.visibleItems.single.title, 'Food');
      expect(h.activeFilterCount, 1);
      h.setRange(null);

      h.setFilter(ActivityFilter.tax); // linked tax counts
      expect(h.visibleItems.single.title, 'Food');
      h.setFilter(ActivityFilter.all);

      for (final q in ['1250', '1,250.5', 'Rs 1250', 'weekly']) {
        h.setQuery(q);
        expect(h.visibleItems.single.title, 'Groceries', reason: q);
      }
      h.setQuery('Cash → Bank');
      expect(h.visibleItems, isEmpty);
      h.setQuery('bank → cash');
      expect(h.visibleItems.single.title, 'Transfer');
    },
  );

  test('date range labels', () {
    expect(DateRange.month(DateTime(2026, 2, 10)).label, 'February 2026');
    expect(DateRange.year(2025).label, '2025');
    expect(DateRange.months(DateTime(2026, 2), 6).label, 'Sep 2025 – Feb 2026');
    expect(
      DateRange.days(DateTime(2026, 1, 30), DateTime(2026, 2, 2)).label,
      '30 Jan – 2 Feb 2026',
    );
    expect(
      DateRange.days(DateTime(2025, 12, 30), DateTime(2026, 1, 2)).label,
      '30 Dec 2025 – 2 Jan 2026',
    );
    expect(
      DateRange.days(DateTime(2026, 5, 4), DateTime(2026, 5, 4)).label,
      '4 May 2026',
    );
    expect(
      DateRange.days(
        DateTime(2026, 5, 4),
        DateTime(2026, 5, 4),
      ).contains(DateTime(2026, 5, 4, 23, 59)),
      isTrue,
    );
  });

  test('defaults prefill new entries without overriding choices', () async {
    final w = await _World.create();
    addTearDown(w.services.close);
    final d = w.services.defaults;
    final wallet = await w.services.accounts.create(
      const Account(name: 'Wallet', type: AccountType.cash),
    );
    await d.setCategoryForKind(DefaultKind.expense, w.groceries.id);
    await d.setAccountForKind(DefaultKind.expense, wallet.id);
    await d.setCategoryForKind(DefaultKind.income, w.salary.id);
    await d.setAccountForCategory(w.salary.id!, w.bank.id);
    await d.setAccountForKind(DefaultKind.tax, w.bank.id);
    await d.setAccountForKind(DefaultKind.transferFrom, w.bank.id);
    await d.setAccountForKind(DefaultKind.transferTo, w.cash.id);

    final loaded = await d.load();
    expect(loaded.categoryByKind, {
      'expense': w.groceries.id,
      'income': w.salary.id,
    });
    expect(loaded.accountByCategory, {w.salary.id: w.bank.id});

    final t = TransactionController(w.services);
    addTearDown(t.dispose);
    await _idle(t);
    expect(t.categoryId, w.groceries.id);
    expect(t.accountId, wallet.id);

    // Switching type applies that type's category and its category wallet.
    t.setKind(EntryKind.income);
    expect(t.categoryId, w.salary.id);
    expect(t.accountId, w.bank.id);

    // A wallet picked by hand is kept when the category changes.
    t.setAccount(w.cash.id);
    t.setCategory(w.salary.id);
    expect(t.accountId, w.cash.id);

    t.setKind(EntryKind.tax);
    expect(t.accountId, w.cash.id);
    final tax = TransactionController(w.services, initialKind: EntryKind.tax);
    addTearDown(tax.dispose);
    await _idle(tax);
    expect(tax.accountId, w.bank.id);

    // Editing never applies defaults.
    final saved = await w.add(
      TransactionType.expense,
      100,
      w.food,
      w.cash,
      DateTime(2026, 11, 1),
    );
    final edit = TransactionController(w.services, existing: saved);
    addTearDown(edit.dispose);
    await _idle(edit);
    expect((edit.categoryId, edit.accountId), (w.food.id, w.cash.id));

    final transfer = TransferController(w.services);
    addTearDown(transfer.dispose);
    await _idle(transfer);
    expect(
      (transfer.fromAccountId, transfer.toAccountId),
      (w.bank.id, w.cash.id),
    );

    // Archived wallets are skipped; deleted ones are forgotten.
    await w.services.accounts.update(wallet.copyWith(isArchived: true));
    final t2 = TransactionController(w.services);
    addTearDown(t2.dispose);
    await _idle(t2);
    expect(t2.accountId, isNot(wallet.id));
    final categories = CategoryController(w.services);
    addTearDown(categories.dispose);
    await _idle(categories);
    expect(await categories.remove(w.groceries.id!), isTrue);
    await w.services.accounts.delete(wallet.id!);
    await d.forgetAccount(wallet.id!);
    final after = await d.load();
    expect(after.categoryByKind.containsKey('expense'), isFalse);
    expect(after.accountByKind.containsKey('expense'), isFalse);
    expect(after.accountByKind[DefaultKind.tax], w.bank.id);
  });

  test('categories store an icon and an upper-case hex color', () async {
    final w = await _World.create();
    addTearDown(w.services.close);
    final saved = await w.services.categories.create(
      const Category(
        name: 'Coffee',
        type: CategoryType.expense,
        icon: 'local_cafe',
        color: '#a1b2c3',
      ),
    );
    final loaded = await w.services.categories.getById(saved.id!);
    expect(loaded!.icon, 'local_cafe');
    expect(loaded.color, '#A1B2C3');
    for (final bad in ['red', '#12345', '#GGGGGG', '123456']) {
      await expectLater(
        w.services.categories.create(
          Category(name: 'Bad', type: CategoryType.expense, color: bad),
        ),
        throwsArgumentError,
        reason: bad,
      );
    }

    // Activity rows and report totals carry the look.
    await w.add(
      TransactionType.expense,
      500,
      loaded,
      w.cash,
      DateTime(2026, 11, 3),
    );
    final row = (await w.services.activity.history()).single;
    expect((row.categoryIcon, row.categoryColor), ('local_cafe', '#A1B2C3'));
    final total = (await w.services.dashboard.categoryTotals(
      DateTime(2026, 11),
    )).single;
    expect((total.icon, total.color), ('local_cafe', '#A1B2C3'));
  });

  test('category color and icon helpers', () {
    expect(colorFromHex('#3F5BD9'), const Color(0xFF3F5BD9));
    expect(colorFromHex('3f5bd9'), const Color(0xFF3F5BD9));
    expect(colorFromHex('#12345'), isNull);
    expect(colorToHex(const Color(0xFF0A0B0C)), '#0A0B0C');
    expect(categoryColor('Food', hex: '#112233'), const Color(0xFF112233));
    // Automatic colors are stable and come from the swatches.
    expect(categoryColor('Food'), categoryColor(' food '));
    expect(categorySwatches, contains(categoryColor('Rent')));
    expect(categoryIcon('Anything', iconKey: 'pets'), Icons.pets_outlined);
    expect(categoryIcon('Food', iconKey: 'unknown'), Icons.restaurant_outlined);
    expect(isCategoryIconKey('local_cafe'), isTrue);
  });

  group('two-way owes', () {
    Future<MoneyTransaction> owe(
      _World w,
      TransactionType type,
      int amount, {
      Account? via,
      OweItem? item,
      int? id,
    }) => w.services.transactions.saveWithTax(
      MoneyTransaction(
        id: id,
        type: type,
        amountMinor: amount,
        categoryId: type == TransactionType.oweIn ? w.salary.id! : w.food.id!,
        occurredAt: DateTime(2026, 11, 10),
        oweStatus: OweStatus.pending,
        party: 'Ali',
        exchangeAccountId: via?.id,
      ),
      item: item,
    );

    test(
      'money lent leaves a wallet now and comes back when received',
      () async {
        final w = await _World.create();
        addTearDown(w.services.close);
        final s = w.services;
        final loan = await owe(w, TransactionType.oweIn, 500000, via: w.cash);
        expect(await s.accounts.balanceMinor(w.cash.id!), 500000);

        var item = (await s.activity.history()).single;
        expect(item.linkLabel, 'Lent from Cash');
        expect(item.netEffectMinor, -500000);
        expect(item.effectOn(w.cash.id!), -500000);
        expect(item.accountIds, {w.cash.id});

        await s.transactions.completeOwe(
          loan.id!,
          w.bank.id!,
          at: DateTime(2026, 11, 20),
        );
        expect(await s.accounts.balanceMinor(w.cash.id!), 500000);
        expect(await s.accounts.balanceMinor(w.bank.id!), 500000);
        item = (await s.activity.history()).single;
        expect(item.netEffectMinor, 0);
        expect(item.effectOn(w.bank.id!), 500000);

        final report = await ReportService(s.database)
            .build(DateTime(2026, 11), DateTime(2026, 12));
        expect(report.lentMinor, 500000);
        expect((report.incomeMinor, report.expenseMinor), (0, 0));
        final cash = report.accounts.firstWhere(
          (f) => f.account.id == w.cash.id,
        );
        final bank = report.accounts.firstWhere(
          (f) => f.account.id == w.bank.id,
        );
        expect((cash.outMinor, bank.inMinor), (500000, 500000));
      },
    );

    test('money borrowed arrives now and leaves when repaid', () async {
      final w = await _World.create();
      addTearDown(w.services.close);
      final s = w.services;
      final debt = await owe(w, TransactionType.oweOut, 300000, via: w.bank);
      expect(await s.accounts.balanceMinor(w.bank.id!), 300000);
      expect(
        (await s.activity.history()).single.linkLabel,
        'Borrowed into Bank',
      );
      await s.transactions.completeOwe(debt.id!, w.bank.id!);
      expect(await s.accounts.balanceMinor(w.bank.id!), 0);
      // Deleting it undoes both sides; the wallet can then be deleted.
      await s.transactions.delete(debt.id!);
      await s.accounts.delete(w.bank.id!);
    });

    test('only owes carry an exchange, and money or item, not both', () async {
      final w = await _World.create();
      addTearDown(w.services.close);
      await expectLater(
        w.services.transactions.saveWithTax(
          MoneyTransaction(
            type: TransactionType.income,
            amountMinor: 100,
            categoryId: w.salary.id!,
            accountId: w.cash.id,
            occurredAt: DateTime(2026, 11, 1),
            exchangeAccountId: w.bank.id,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        owe(
          w,
          TransactionType.oweOut,
          100,
          via: w.cash,
          item: const OweItem.received('Phone'),
        ),
        throwsArgumentError,
      );
    });

    test(
      'an item given away leaves your assets until the entry goes',
      () async {
        final w = await _World.create();
        addTearDown(w.services.close);
        final s = w.services;
        final ring = await s.assets.create(
          Asset(
            name: 'Ring',
            acquiredOn: DateTime(2026),
            purchaseAmountMinor: 200000,
            currentValueMinor: 250000,
          ),
        );
        final sale = await owe(
          w,
          TransactionType.oweIn,
          250000,
          item: OweItem.given(ring.id!),
        );
        expect((await s.assets.getById(ring.id!))!.givenTransactionId, sale.id);
        var summary = await s.dashboard.currentMonth(now: DateTime(2026, 11));
        expect((summary.assetValueMinor, summary.oweInMinor), (0, 250000));
        expect(await s.accounts.balanceMinor(w.cash.id!), 1000000);
        expect((await s.activity.history()).single.linkLabel, 'Gave Ring');

        // The same item can't be given twice.
        await expectLater(
          owe(w, TransactionType.oweIn, 1, item: OweItem.given(ring.id!)),
          throwsArgumentError,
        );
        // Clearing the item in an edit brings it back.
        await owe(w, TransactionType.oweIn, 250000, id: sale.id);
        expect((await s.assets.getById(ring.id!))!.isGivenAway, isFalse);
        await owe(
          w,
          TransactionType.oweIn,
          250000,
          id: sale.id,
          item: OweItem.given(ring.id!),
        );
        await s.transactions.delete(sale.id!);
        expect((await s.assets.getById(ring.id!))!.isGivenAway, isFalse);
        summary = await s.dashboard.currentMonth(now: DateTime(2026, 11));
        expect(summary.assetValueMinor, 250000);
      },
    );

    test('an item received is kept as an asset in step with the owe', () async {
      final w = await _World.create();
      addTearDown(w.services.close);
      final s = w.services;
      final debt = await owe(
        w,
        TransactionType.oweOut,
        8000000,
        item: const OweItem.received('Laptop'),
      );
      var laptop = (await s.assets.purchasedWith(debt.id!))!;
      expect((laptop.name, laptop.purchaseAmountMinor), ('Laptop', 8000000));
      expect(laptop.currentValueMinor, 8000000);
      expect(await s.accounts.balanceMinor(w.cash.id!), 1000000);
      expect((await s.activity.history()).single.linkLabel, 'Got Laptop');

      await owe(
        w,
        TransactionType.oweOut,
        9000000,
        id: debt.id,
        item: const OweItem.received('Laptop Pro'),
      );
      laptop = (await s.assets.getById(laptop.id!))!;
      expect(
        (laptop.name, laptop.purchaseAmountMinor, laptop.currentValueMinor),
        ('Laptop Pro', 9000000, 9000000),
      );
      expect(await s.assets.getAll(), hasLength(1));

      // Deleting the owe keeps the asset, unlinked.
      await s.transactions.delete(debt.id!);
      laptop = (await s.assets.getById(laptop.id!))!;
      expect(laptop.purchaseTransactionId, isNull);
    });

    test('owe form records money or an item and loads it back', () async {
      final w = await _World.create();
      addTearDown(w.services.close);
      final s = w.services;
      final form = TransactionController(s, initialKind: EntryKind.oweIn);
      addTearDown(form.dispose);
      await _idle(form);
      form
        ..setAmount('1000')
        ..setCategory(w.salary.id)
        ..setExchange(OweExchange.money);
      expect(await form.save(), isFalse);
      expect(form.error, 'Choose the wallet the money left');
      form.setExchangeAccount(w.cash.id);
      expect(await form.save(), isTrue);
      expect(await s.accounts.balanceMinor(w.cash.id!), 1000000 - 100000);

      final saved = (await s.transactions.pendingOwes()).single;
      final edit = TransactionController(s, existing: saved);
      addTearDown(edit.dispose);
      await _idle(edit);
      expect(edit.exchange, OweExchange.money);
      expect(edit.exchangeAccountId, w.cash.id);
      // Switching to "None" undoes the money movement.
      edit.setExchange(OweExchange.none);
      expect(await edit.save(), isTrue);
      expect(await s.accounts.balanceMinor(w.cash.id!), 1000000);

      final got = TransactionController(s, initialKind: EntryKind.oweOut);
      addTearDown(got.dispose);
      await _idle(got);
      got
        ..setAmount('500')
        ..setCategory(w.food.id)
        ..setExchange(OweExchange.item)
        ..setReceivedItem('Bicycle');
      expect(await got.save(), isTrue);
      final bike = (await s.assets.getAll()).single;
      expect((bike.name, bike.purchaseAmountMinor), ('Bicycle', 50000));
      final again = TransactionController(
        s,
        existing: await s.transactions.getById(bike.purchaseTransactionId!),
      );
      addTearDown(again.dispose);
      await _idle(again);
      expect(again.exchange, OweExchange.item);
      expect(again.receivedItem, 'Bicycle');
    });

    test(
      'assets can be paid from a wallet, bought on credit or just owned',
      () async {
        final w = await _World.create();
        addTearDown(w.services.close);
        final s = w.services;
        final c = AssetController(s);
        addTearDown(c.dispose);
        await _idle(c);

        Future<bool> save(
          String name,
          String price, {
          int? id,
          AssetSource source = AssetSource.owned,
          int? accountId,
          String party = '',
        }) => c.save(
          id: id,
          name: name,
          purchaseAmount: price,
          currentValue: price,
          acquiredOn: DateTime(2026, 11, 2),
          source: source,
          accountId: accountId,
          categoryId: source == AssetSource.owned ? null : w.food.id,
          party: party,
        );

        expect(await save('Watch', '300', source: AssetSource.paid), isFalse);
        expect(c.error, 'Choose the wallet you paid from');
        expect(
          await save(
            'Watch',
            '300',
            source: AssetSource.paid,
            accountId: w.cash.id,
          ),
          isTrue,
        );
        expect(await s.accounts.balanceMinor(w.cash.id!), 1000000 - 30000);
        await _idle(c);
        final watch = c.items.single;
        expect(c.sourceOf(watch), AssetSource.paid);
        expect((await s.activity.history()).single.linkLabel, 'Bought Watch');

        // Editing the price keeps the expense in step.
        expect(
          await save(
            'Watch',
            '350',
            id: watch.id,
            source: AssetSource.paid,
            accountId: w.cash.id,
          ),
          isTrue,
        );
        expect(await s.accounts.balanceMinor(w.cash.id!), 1000000 - 35000);

        expect(
          await save(
            'Sofa',
            '900',
            source: AssetSource.owed,
            party: 'Furniture shop',
          ),
          isTrue,
        );
        final debt = (await s.transactions.pendingOwes()).single;
        expect(
          (debt.type, debt.amountMinor, debt.party),
          (TransactionType.oweOut, 90000, 'Furniture shop'),
        );
        expect(await s.accounts.balanceMinor(w.cash.id!), 1000000 - 35000);
        await _idle(c);
        expect(c.ownedValueMinor, 35000 + 90000);

        // "Had it": no entry is created.
        expect(await save('Old chair', '50'), isTrue);
        expect(await s.transactions.getAll(), hasLength(2));
      },
    );

    test('version 5 databases gain the owe link columns', () async {
      final dir = await Directory.systemTemp.createTemp('money_tracker_v5_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/v5.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE accounts (id INTEGER PRIMARY KEY, name TEXT NOT NULL,
                type TEXT NOT NULL, opening_balance_minor INTEGER NOT NULL DEFAULT 0,
                is_archived INTEGER NOT NULL DEFAULT 0)
            ''');
            await db.execute('''
              CREATE TABLE transactions (id INTEGER PRIMARY KEY, type TEXT NOT NULL,
                amount_minor INTEGER NOT NULL, category_id INTEGER NOT NULL,
                account_id INTEGER, occurred_at TEXT NOT NULL, note TEXT,
                party TEXT, due_at TEXT, owe_status TEXT, completed_at TEXT)
            ''');
            await db.execute('''
              CREATE TABLE assets (id INTEGER PRIMARY KEY, name TEXT NOT NULL,
                acquired_on TEXT NOT NULL, purchase_amount_minor INTEGER NOT NULL,
                current_value_minor INTEGER NOT NULL,
                purchase_transaction_id INTEGER UNIQUE, notes TEXT)
            ''');
            await db.insert('accounts', {'name': 'Cash', 'type': 'cash'});
          },
        ),
      );
      await legacy.close();

      final storage = LocalDatabase(factory: databaseFactoryFfi, path: path);
      addTearDown(storage.close);
      final db = await storage.database;
      Future<List<Object?>> columns(String table) async =>
          (await db.rawQuery('PRAGMA table_info($table)'))
              .map((c) => c['name'])
              .toList();
      expect(await columns('transactions'), contains('exchange_account_id'));
      expect(await columns('assets'), contains('given_transaction_id'));
      // The column check keeps money lent/borrowed on owes only.
      await expectLater(
        db.insert('transactions', {
          'type': 'income',
          'amount_minor': 1,
          'category_id': 1,
          'account_id': 1,
          'occurred_at': '2026-11-01',
          'exchange_account_id': 1,
        }),
        throwsA(anything),
      );
    });
  });
}
