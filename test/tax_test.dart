import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/app_services.dart';
import 'package:money_tracker/app/controllers/base_controller.dart';
import 'package:money_tracker/app/controllers/tax_rate_controller.dart';
import 'package:money_tracker/app/controllers/transaction_controller.dart';
import 'package:money_tracker/data/models/model_types.dart';
import 'package:money_tracker/data/models/money_transaction.dart';
import 'package:money_tracker/data/models/tax_rate.dart';
import 'package:money_tracker/data/services/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _idle(BaseController c) async {
  await Future<void>.delayed(Duration.zero);
  while (c.busy) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<AppServices> _services() async {
  final s = AppServices.withDatabase(
    LocalDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
  );
  await s.initialize();
  return s;
}

void main() {
  sqfliteFfiInit();

  test('splitTax adds on top or takes out of the amount', () {
    final on = splitTax(100000, 1700, inclusive: false);
    expect(
      (on.subtotalMinor, on.taxMinor, on.totalMinor),
      (100000, 17000, 117000),
    );
    final inside = splitTax(117000, 1700, inclusive: true);
    expect((inside.subtotalMinor, inside.taxMinor), (100000, 17000));
    expect(formatRate(1700), '17%');
    expect(formatRate(1250), '12.5%');
    expect(formatRate(25), '0.25%');
    expect(percentageInputText(1250), '12.5');
  });

  group('tax management', () {
    late AppServices s;
    late int cash;
    late int food;
    late int salary;

    setUp(() async {
      s = await _services();
      cash = (await s.accounts.getAll()).single.id!;
      final categories = await s.categories.getAll();
      food = categories.firstWhere((c) => c.name == 'Food').id!;
      salary = categories.firstWhere((c) => c.name == 'Salary').id!;
    });
    tearDown(() => s.close());

    test(
      'validates name, 3-character code, percentage and unique code',
      () async {
        final c = TaxRateController(s);
        addTearDown(c.dispose);
        await _idle(c);
        Future<bool> save(String name, String code, String pct, {int? id}) =>
            c.save(
              id: id,
              name: name,
              code: code,
              percentage: pct,
              inclusive: false,
            );

        expect(await save('', 'GST', '17'), isFalse);
        expect(await save('Sales tax', 'GS', '17'), isFalse);
        expect(c.error, contains('3 letters'));
        expect(await save('Sales tax', 'GST', '0'), isFalse);
        expect(await save('Sales tax', 'GST', '101'), isFalse);
        expect(await save('Sales tax', 'GST', 'abc'), isFalse);
        expect(await save('Sales tax', 'gst', '17'), isTrue);
        expect(await save('Other', 'GST', '5'), isFalse);
        expect(c.error, contains('already uses'));
        expect(await save('Income tax', 'WHT', '12.5'), isTrue);
        // Read the repo: the list reloads after save() returns.
        expect(
          (await s.taxRates.sorted()).map(
            (t) => (t.name, t.code, t.rateBasisPoints),
          ),
          [('Income tax', 'WHT', 1250), ('Sales tax', 'GST', 1700)],
        );
        final gst = (await s.taxRates.sorted()).last;
        expect(await save('Sales tax', 'GST', '18', id: gst.id), isTrue);
        expect((await s.taxRates.getById(gst.id!))!.rateBasisPoints, 1800);
        expect(await c.remove(gst.id!), isTrue);
        expect(await s.taxRates.getAll(), hasLength(1));
      },
    );

    test(
      'expense tax on top, and editing the tax leaves the entry alone',
      () async {
        final gst = await s.taxRates.create(
          const TaxRate(name: 'Sales tax', code: 'GST', rateBasisPoints: 1700),
        );
        final form = TransactionController(s);
        addTearDown(form.dispose);
        await _idle(form);
        form
          ..setAmount('1000')
          ..setCategory(food)
          ..setAccount(cash)
          ..setTaxRate(gst);
        expect(form.taxLabel, 'GST 17%');
        expect(form.taxSplit.totalMinor, 117000);
        expect(await form.save(), isTrue);

        final tx = (await s.transactions.getAll()).single;
        expect(tx.amountMinor, 100000);
        var tax = (await s.taxes.forTransaction(tx.id!))!;
        expect(
          (tax.amountMinor, tax.taxRateId, tax.taxName, tax.taxCode),
          (17000, gst.id, 'Sales tax', 'GST'),
        );
        expect((tax.rateBasisPoints, tax.inclusive), (1700, false));
        expect(await s.accounts.balanceMinor(cash), -117000);
        final row = (await s.activity.history()).single;
        expect(
          (row.subtotalMinor, row.taxMinor, row.totalMinor, row.taxLabel),
          (100000, 17000, 117000, 'GST'),
        );

        // The managed tax changes; the saved entry keeps 17%.
        await s.taxRates.update(
          gst.copyWith(name: 'GST new', code: 'GSX', rateBasisPoints: 2000),
        );
        final edit = TransactionController(s, existing: tx);
        addTearDown(edit.dispose);
        await _idle(edit);
        expect(edit.taxMode, TaxMode.rate);
        expect(edit.taxLabel, 'GST 17%');
        expect(edit.amountText, '1000');
        expect(edit.taxMinor, 17000);
        edit.setNote('edited');
        expect(await edit.save(), isTrue);
        tax = (await s.taxes.forTransaction(tx.id!))!;
        expect(
          (tax.amountMinor, tax.taxCode, tax.rateBasisPoints),
          (17000, 'GST', 1700),
        );

        // Deleting the managed tax keeps the entry's copy.
        await s.taxRates.delete(gst.id!);
        tax = (await s.taxes.forTransaction(tx.id!))!;
        expect(
          (tax.taxRateId, tax.taxCode, tax.amountMinor),
          (null, 'GST', 17000),
        );
      },
    );

    test('amount including tax, for expense and income', () async {
      final gst = await s.taxRates.create(
        const TaxRate(
          name: 'Sales tax',
          code: 'GST',
          rateBasisPoints: 1700,
          inclusive: true,
        ),
      );
      final form = TransactionController(s);
      addTearDown(form.dispose);
      await _idle(form);
      form
        ..setAmount('1170')
        ..setCategory(food)
        ..setAccount(cash)
        ..setTaxRate(gst);
      expect(form.taxInclusive, isTrue);
      expect(await form.save(), isTrue);
      final expense = (await s.transactions.getAll()).single;
      expect(expense.amountMinor, 100000);
      expect(await s.accounts.balanceMinor(cash), -117000);

      // Income: the wallet keeps the subtotal; the stored amount is the total.
      final income = TransactionController(s, initialKind: EntryKind.income);
      addTearDown(income.dispose);
      await _idle(income);
      income
        ..setAmount('1170')
        ..setCategory(salary)
        ..setAccount(cash)
        ..setTaxRate(gst);
      expect(await income.save(), isTrue);
      final saved = (await s.transactions.getAll()).firstWhere(
        (t) => t.type == TransactionType.income,
      );
      expect(saved.amountMinor, 117000);
      expect(await s.accounts.balanceMinor(cash), -117000 + 100000);

      // Editing shows the amount as typed (with the tax in it).
      final edit = TransactionController(s, existing: saved);
      addTearDown(edit.dispose);
      await _idle(edit);
      expect(
        (edit.amountText, edit.taxInclusive, edit.taxMinor),
        ('1170', true, 17000),
      );
      // Switching to "added on top" re-works the tax on the same amount.
      edit.setTaxInclusive(false);
      expect(
        (edit.taxSplit.subtotalMinor, edit.taxSplit.taxMinor),
        (117000, 19890),
      );
    });

    test('custom tax amount, included or on top', () async {
      final form = TransactionController(s);
      addTearDown(form.dispose);
      await _idle(form);
      form
        ..setAmount('500')
        ..setCategory(food)
        ..setAccount(cash)
        ..setCustomTax()
        ..setTax('50')
        ..setTaxInclusive(true);
      expect(
        (form.taxSplit.subtotalMinor, form.taxSplit.totalMinor),
        (45000, 50000),
      );
      expect(await form.save(), isTrue);
      final tx = (await s.transactions.getAll()).single;
      expect(tx.amountMinor, 45000);
      final tax = (await s.taxes.forTransaction(tx.id!))!;
      expect(
        (tax.amountMinor, tax.taxCode, tax.rateBasisPoints, tax.inclusive),
        (5000, null, null, true),
      );
      expect(await s.accounts.balanceMinor(cash), -50000);

      final edit = TransactionController(s, existing: tx);
      addTearDown(edit.dispose);
      await _idle(edit);
      expect(
        (edit.taxMode, edit.taxText, edit.amountText),
        (TaxMode.custom, '50', '500'),
      );
      edit.setTax('500');
      expect(await edit.save(), isFalse);
      expect(edit.error, 'Tax must be less than the amount');
    });

    test('tax saved before tax management opens as it was entered', () async {
      // Old income: amount 1000 with 100 tax taken out.
      final income = await s.transactions.saveWithTax(
        MoneyTransaction(
          type: TransactionType.income,
          amountMinor: 100000,
          categoryId: salary,
          accountId: cash,
          occurredAt: DateTime(2026, 11, 1),
        ),
        taxMinor: 10000,
      );
      final edit = TransactionController(s, existing: income);
      addTearDown(edit.dispose);
      await _idle(edit);
      expect(
        (edit.taxMode, edit.taxInclusive, edit.amountText, edit.taxText),
        (TaxMode.custom, true, '1000', '100'),
      );
      expect(await edit.save(), isTrue);
      expect((await s.transactions.getById(income.id!))!.amountMinor, 100000);
      expect(await s.accounts.balanceMinor(cash), 90000);
    });

    test('a standalone tax payment can name its tax', () async {
      final wht = await s.taxRates.create(
        const TaxRate(name: 'Income tax', code: 'WHT', rateBasisPoints: 1000),
      );
      final form = TransactionController(s, initialKind: EntryKind.tax);
      addTearDown(form.dispose);
      await _idle(form);
      form
        ..setAmount('300')
        ..setAccount(cash)
        ..setTaxRate(wht);
      expect(await form.save(), isTrue);
      final paid = (await s.taxes.getAll()).single;
      expect(
        (paid.taxName, paid.taxCode, paid.amountMinor),
        ('Income tax', 'WHT', 30000),
      );
      final row = (await s.activity.history()).single;
      expect((row.title, row.taxLabel), ('Income tax', 'WHT'));
    });
  });

  test('version 6 databases gain tax rates and tax copy columns', () async {
    final dir = await Directory.systemTemp.createTemp('money_tracker_v6_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v6.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE tax_payments (id INTEGER PRIMARY KEY,
              amount_minor INTEGER NOT NULL, paid_at TEXT NOT NULL,
              account_id INTEGER NOT NULL, note TEXT, transaction_id INTEGER)
          ''');
          await db.insert('tax_payments', {
            'amount_minor': 100,
            'paid_at': '2026-11-01',
            'account_id': 1,
          });
        },
      ),
    );
    await legacy.close();

    final storage = LocalDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(storage.close);
    final db = await storage.database;
    final columns = (await db.rawQuery('PRAGMA table_info(tax_payments)'))
        .map((c) => c['name'])
        .toSet();
    expect(
      columns,
      containsAll([
        'tax_rate_id',
        'tax_name',
        'tax_code',
        'rate_bp',
        'inclusive',
      ]),
    );
    final row = (await db.query('tax_payments')).single;
    expect((row['tax_code'], row['inclusive']), (null, null));
    await db.insert('tax_rates', {
      'name': 'GST',
      'code': 'GST',
      'rate_bp': 1700,
    });
    await expectLater(
      db.insert('tax_rates', {'name': 'Bad', 'code': 'GSTX', 'rate_bp': 1}),
      throwsA(anything),
    );
    await expectLater(
      db.insert('tax_rates', {'name': 'Dup', 'code': 'gst', 'rate_bp': 1}),
      throwsA(anything),
    );
  });
}
