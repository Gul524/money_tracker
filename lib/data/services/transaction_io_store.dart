import 'package:transaction_io/transaction_io.dart';

import '../models/account.dart';
import '../models/account_transfer.dart';
import '../models/category.dart';
import '../models/model_types.dart';
import '../models/money_transaction.dart';
import '../models/tax_payment.dart';
import '../repo/account_repository.dart';
import '../repo/category_repository.dart';
import '../repo/tax_repository.dart';
import '../repo/transaction_repository.dart';
import '../repo/transfer_repository.dart';
import 'local_database.dart';

/// Connects the self-contained `transaction_io` module to this app's data.
/// It only maps between the module's [TxRow] and the app's records; file
/// format, threading and duplicate rules live in the module.
class AppTransactionIoStore implements TransactionIoStore {
  AppTransactionIoStore(LocalDatabase storage)
    : _accounts = AccountRepository(storage),
      _categories = CategoryRepository(storage),
      _transactions = TransactionRepository(storage),
      _taxes = TaxRepository(storage),
      _transfers = TransferRepository(storage);

  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final TransactionRepository _transactions;
  final TaxRepository _taxes;
  final TransferRepository _transfers;

  @override
  Future<List<TxRow>> readRows({DateTime? from, DateTime? to}) async {
    bool inRange(DateTime d) =>
        (from == null || !d.isBefore(from)) && (to == null || d.isBefore(to));
    final accounts = {for (final a in await _accounts.getAll()) a.id!: a.name};
    final categories = await _categories.getAll();
    final byId = {for (final c in categories) c.id!: c};
    String path(int id) {
      final names = <String>[];
      final seen = <int>{};
      Category? c = byId[id];
      while (c != null && seen.add(c.id!)) {
        names.insert(0, c.name);
        c = c.parentId == null ? null : byId[c.parentId];
      }
      return names.join(categorySeparator);
    }

    final taxes = await _taxes.getAll();
    final linkedTax = {
      for (final t in taxes)
        if (t.transactionId != null) t.transactionId!: t.amountMinor,
    };
    final rows = <TxRow>[
      for (final t in await _transactions.getAll())
        if (inRange(t.occurredAt))
          TxRow(
            type: switch (t.type) {
              TransactionType.income => TxType.income,
              TransactionType.expense => TxType.expense,
              TransactionType.oweIn => TxType.owedToMe,
              TransactionType.oweOut => TxType.iOwe,
            },
            amountMinor: t.amountMinor,
            date: t.occurredAt,
            category: path(t.categoryId),
            account: t.accountId == null ? '' : accounts[t.accountId] ?? '',
            note: t.note ?? '',
            owedPerson: t.party ?? '',
            dueDate: t.dueAt,
            owedStatus: switch (t.oweStatus) {
              null => null,
              OweStatus.pending => OwedStatus.pending,
              OweStatus.completed => OwedStatus.completed,
            },
            owedCompleted: t.completedAt,
            taxMinor: linkedTax[t.id] ?? 0,
          ),
      for (final t in taxes)
        if (t.transactionId == null && inRange(t.paidAt))
          TxRow(
            type: TxType.tax,
            amountMinor: t.amountMinor,
            date: t.paidAt,
            account: accounts[t.accountId] ?? '',
            note: t.note ?? '',
          ),
      for (final t in await _transfers.getAll())
        if (inRange(t.occurredAt))
          TxRow(
            type: TxType.transfer,
            amountMinor: t.amountMinor,
            date: t.occurredAt,
            account:
                '${accounts[t.fromAccountId] ?? ''}$transferArrow'
                '${accounts[t.toAccountId] ?? ''}',
            note: t.note ?? '',
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return rows;
  }

  @override
  Future<List<RowIssue>> writeRows(List<TxRow> rows) async {
    final accounts = {
      for (final a in await _accounts.getAll()) a.name.trim().toLowerCase(): a,
    };
    final categories = await _categories.getAll();
    final issues = <RowIssue>[];

    Future<int> account(String name) async {
      final key = name.trim().toLowerCase();
      final found = accounts[key];
      if (found != null) return found.id!;
      final created = await _accounts.create(
        Account(
          name: name.trim(),
          type: key.contains('bank') ? AccountType.bank : AccountType.cash,
        ),
      );
      accounts[key] = created;
      return created.id!;
    }

    Future<int> category(List<String> path, TxType type) async {
      final needed = type.isIncomeSide
          ? CategoryType.income
          : CategoryType.expense;
      int? parentId;
      Category? current;
      for (final name in path) {
        current = categories
            .where(
              (c) =>
                  c.parentId == parentId &&
                  c.name.trim().toLowerCase() == name.toLowerCase(),
            )
            .firstOrNull;
        if (current == null) {
          current = await _categories.create(
            Category(name: name, type: needed, parentId: parentId),
          );
          categories.add(current);
        }
        parentId = current.id;
      }
      if (current!.type != CategoryType.both && current.type != needed) {
        throw ArgumentError(
          'Category "${path.join(categorySeparator)}" is for '
          '${current.type.name}, not ${type.label}',
        );
      }
      return current.id!;
    }

    for (final r in rows) {
      try {
        switch (r.type) {
          case TxType.tax:
            await _taxes.create(
              TaxPayment(
                amountMinor: r.amountMinor,
                paidAt: r.date,
                accountId: await account(r.account),
                note: r.note,
              ),
            );
          case TxType.transfer:
            final (from, to) = r.transferAccounts!;
            await _transfers.create(
              AccountTransfer(
                fromAccountId: await account(from),
                toAccountId: await account(to),
                amountMinor: r.amountMinor,
                occurredAt: r.date,
                note: r.note,
              ),
            );
          case TxType.income ||
              TxType.expense ||
              TxType.owedToMe ||
              TxType.iOwe:
            final completed = r.owedStatus == OwedStatus.completed;
            await _transactions.saveWithTax(
              MoneyTransaction(
                type: switch (r.type) {
                  TxType.income => TransactionType.income,
                  TxType.expense => TransactionType.expense,
                  TxType.owedToMe => TransactionType.oweIn,
                  _ => TransactionType.oweOut,
                },
                amountMinor: r.amountMinor,
                categoryId: await category(r.categoryPath, r.type),
                accountId: r.account.isEmpty ? null : await account(r.account),
                occurredAt: r.date,
                note: r.note,
                party: r.type.isOwe ? r.owedPerson : null,
                dueAt: r.type.isOwe ? r.dueDate : null,
                oweStatus: r.type.isOwe
                    ? (completed ? OweStatus.completed : OweStatus.pending)
                    : null,
                completedAt: completed ? (r.owedCompleted ?? r.date) : null,
              ),
              taxMinor: r.taxMinor,
            );
        }
      } catch (e) {
        issues.add(
          RowIssue(
            r.sourceRow,
            e.toString().replaceFirst('Invalid argument(s): ', ''),
          ),
        );
      }
    }
    return issues;
  }
}
