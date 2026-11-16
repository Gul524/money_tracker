import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_io/transaction_io.dart';

class _MemoryStore implements TransactionIoStore {
  _MemoryStore([List<TxRow>? rows]) : rows = [...?rows];
  final List<TxRow> rows;

  @override
  Future<List<TxRow>> readRows({DateTime? from, DateTime? to}) async => [
    for (final r in rows)
      if ((from == null || !r.date.isBefore(from)) &&
          (to == null || r.date.isBefore(to)))
        r,
  ];

  @override
  Future<List<RowIssue>> writeRows(List<TxRow> incoming) async {
    final issues = <RowIssue>[];
    for (final r in incoming) {
      if (r.account == 'Broken') {
        issues.add(RowIssue(r.sourceRow, 'cannot save'));
      } else {
        rows.add(r);
      }
    }
    return issues;
  }
}

final _sample = [
  TxRow(
    type: TxType.income,
    amountMinor: 25000000,
    date: DateTime(2026, 11, 1, 9, 15, 42),
    category: 'Salary',
    account: 'HBL Current',
    note: 'November pay',
    taxMinor: 2500000,
  ),
  TxRow(
    type: TxType.expense,
    amountMinor: 125050,
    date: DateTime(2026, 11, 3, 18, 5),
    category: 'Food / Groceries',
    account: 'Cash',
    item: 'Blender',
  ),
  TxRow(
    type: TxType.owedToMe,
    amountMinor: 50000,
    date: DateTime(2026, 11, 4),
    category: 'Salary',
    owedPerson: 'Ali',
    oweWallet: 'Cash',
    dueDate: DateTime(2026, 12, 1, 17, 30),
    owedStatus: OwedStatus.pending,
  ),
  TxRow(
    type: TxType.iOwe,
    amountMinor: 70000,
    date: DateTime(2026, 11, 5),
    category: 'Food',
    account: 'Cash',
    owedPerson: 'Sara',
    owedStatus: OwedStatus.completed,
    owedCompleted: DateTime(2026, 11, 9, 20, 45, 1),
    dueDate: DateTime(2026, 11, 10),
  ),
  TxRow(
    type: TxType.tax,
    amountMinor: 120000,
    date: DateTime(2026, 11, 6),
    account: 'HBL Current',
    note: 'Property tax',
  ),
  TxRow(
    type: TxType.transfer,
    amountMinor: 3000000,
    date: DateTime(2026, 11, 7),
    account: 'HBL Current → Cash',
  ),
];

Uint8List _sheet(List<List<CellValue?>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];
  for (final r in rows) {
    sheet.appendRow(r);
  }
  return Uint8List.fromList(excel.encode()!);
}

void main() {
  test('export → import round trip keeps every field', () async {
    final source = _MemoryStore(_sample);
    final exported = await exportTransactions(
      source,
      from: DateTime(2026, 11),
      to: DateTime(2026, 12),
    );
    expect(exported.rowCount, 6);
    expect(exported.fileName, 'transactions_2026-11-01_to_2026-11-30.xlsx');

    final parsed = decodeXlsx(exported.bytes);
    expect(parsed.issues, isEmpty);
    expect(parsed.dataRows, 6);
    for (var i = 0; i < _sample.length; i++) {
      final a = _sample[i], b = parsed.rows[i];
      expect(
        (b.type, b.amountMinor, b.date, b.category, b.account, b.note),
        (a.type, a.amountMinor, a.date, a.category, a.account, a.note),
      );
      expect(
        (b.owedPerson, b.owedStatus, b.owedCompleted, b.taxMinor, b.dueDate),
        (a.owedPerson, a.owedStatus, a.owedCompleted, a.taxMinor, a.dueDate),
      );
      expect((b.oweWallet, b.item), (a.oweWallet, a.item));
      expect(b.sourceRow, i + 2);
    }

    // Importing into the same data skips everything; into empty data adds all.
    final again = await importTransactions(source, exported.bytes);
    expect((again.imported, again.duplicates), (0, 6));
    expect(again.issues, isEmpty);
    final empty = _MemoryStore();
    final fresh = await importTransactions(empty, exported.bytes);
    expect((fresh.rowsRead, fresh.imported, fresh.duplicates), (6, 6, 0));
    expect(empty.rows, hasLength(6));
  });

  test('Owe wallet and Item are read only where they apply', () {
    final parsed = decodeXlsx(
      _sheet([
        [
          TextCellValue('Type'),
          TextCellValue('Amount'),
          TextCellValue('Date'),
          TextCellValue('Category'),
          TextCellValue('Account'),
          TextCellValue('Lent from'),
          TextCellValue('Asset'),
        ],
        [
          TextCellValue('Owed to me'),
          IntCellValue(10),
          TextCellValue('2026-11-15'),
          TextCellValue('Gifts'),
          null,
          TextCellValue('Cash'),
          null,
        ],
        [
          TextCellValue('Income'),
          IntCellValue(10),
          TextCellValue('2026-11-15'),
          TextCellValue('Salary'),
          TextCellValue('Cash'),
          TextCellValue('Bank'),
          TextCellValue('Ring'),
        ],
        [
          TextCellValue('I owe'),
          IntCellValue(10),
          TextCellValue('2026-11-15'),
          TextCellValue('Food'),
          null,
          TextCellValue('Cash'),
          TextCellValue('Laptop'),
        ],
      ]),
    );
    expect(parsed.rows, hasLength(2));
    expect((parsed.rows[0].oweWallet, parsed.rows[0].item), ('Cash', ''));
    // Income can't carry either.
    expect((parsed.rows[1].oweWallet, parsed.rows[1].item), ('', ''));
    expect(parsed.issues.single.message, contains('either Owe wallet or Item'));
  });

  test('export filters by period', () async {
    final store = _MemoryStore(_sample);
    final r = await exportTransactions(
      store,
      from: DateTime(2026, 11, 3),
      to: DateTime(2026, 11, 5),
    );
    expect(r.rowCount, 2);
    expect(exportFileName(null, null), 'transactions_all.xlsx');
  });

  test('duplicates match type, account, amount and day, one for one', () {
    final coffee = TxRow(
      type: TxType.expense,
      amountMinor: 500,
      date: DateTime(2026, 1, 1, 9),
      category: 'Food',
      account: 'Cash',
    );
    final sameDayLater = TxRow(
      type: TxType.expense,
      amountMinor: 500,
      date: DateTime(2026, 1, 1, 18),
      category: 'Other',
      account: 'CASH',
      note: 'different note',
    );
    expect(duplicateKey(coffee), duplicateKey(sameDayLater));
    final (fresh, dupes) = splitDuplicates(
      [sameDayLater, sameDayLater],
      [coffee],
    );
    expect((fresh.length, dupes.length), (1, 1));

    final otherDay = TxRow(
      type: TxType.expense,
      amountMinor: 500,
      date: DateTime(2026, 1, 2),
      account: 'Cash',
    );
    final otherType = TxRow(
      type: TxType.income,
      amountMinor: 500,
      date: DateTime(2026, 1, 1),
      account: 'Cash',
    );
    expect(splitDuplicates([otherDay, otherType], [coffee]).$1, hasLength(2));
  });

  test('import reads flexible headers, text dates and amounts', () {
    final bytes = _sheet([
      [TextCellValue('My money')],
      [
        TextCellValue('date'),
        TextCellValue('TYPE'),
        TextCellValue('amount'),
        TextCellValue('Wallet'),
        TextCellValue('Category'),
        TextCellValue('Owed status'),
        TextCellValue('Extra column'),
      ],
      [
        TextCellValue('15/11/2026'),
        TextCellValue('outgoing'),
        TextCellValue('Rs 1,250.50'),
        TextCellValue('Cash'),
        TextCellValue('Food/Groceries'),
        null,
        TextCellValue('ignored'),
      ],
      [
        TextCellValue('2026-11-16'),
        TextCellValue('Owed to me'),
        IntCellValue(300),
        null,
        TextCellValue('Salary'),
        null,
        null,
      ],
      [],
      [
        TextCellValue('3 Mar 2026'),
        TextCellValue('Transfer'),
        DoubleCellValue(10),
        TextCellValue('Bank -> Cash'),
        null,
        null,
        null,
      ],
    ]);
    final parsed = decodeXlsx(bytes);
    expect(parsed.issues, isEmpty);
    expect(parsed.dataRows, 3);
    final [spend, owe, move] = parsed.rows;
    expect(
      (spend.type, spend.amountMinor, spend.date),
      (TxType.expense, 125050, DateTime(2026, 11, 15)),
    );
    expect(spend.categoryPath, ['Food', 'Groceries']);
    expect(spend.sourceRow, 3);
    expect((owe.owedStatus, owe.account), (OwedStatus.pending, ''));
    expect(move.transferAccounts, ('Bank', 'Cash'));
    expect(move.date, DateTime(2026, 3, 3));
  });

  test('import reports bad rows and keeps the good ones', () async {
    final bytes = _sheet([
      [
        TextCellValue('Type'),
        TextCellValue('Amount'),
        TextCellValue('Date'),
        TextCellValue('Account'),
        TextCellValue('Category'),
      ],
      [
        TextCellValue('Gift'),
        IntCellValue(5),
        TextCellValue('2026-01-01'),
        TextCellValue('Cash'),
        TextCellValue('X'),
      ],
      [
        TextCellValue('Expense'),
        IntCellValue(0),
        TextCellValue('2026-01-01'),
        TextCellValue('Cash'),
        TextCellValue('X'),
      ],
      [
        TextCellValue('Expense'),
        IntCellValue(5),
        TextCellValue('yesterday'),
        TextCellValue('Cash'),
        TextCellValue('X'),
      ],
      [
        TextCellValue('Expense'),
        IntCellValue(5),
        TextCellValue('2026-01-01'),
        null,
        TextCellValue('X'),
      ],
      [
        TextCellValue('Income'),
        IntCellValue(5),
        TextCellValue('2026-01-01'),
        TextCellValue('Cash'),
        null,
      ],
      [
        TextCellValue('Transfer'),
        IntCellValue(5),
        TextCellValue('2026-01-01'),
        TextCellValue('Cash'),
        null,
      ],
      [
        TextCellValue('Expense'),
        IntCellValue(5),
        TextCellValue('2026-01-01'),
        TextCellValue('Broken'),
        TextCellValue('X'),
      ],
      [
        TextCellValue('Expense'),
        IntCellValue(7),
        TextCellValue('2026-01-01'),
        TextCellValue('Cash'),
        TextCellValue('X'),
      ],
    ]);
    final store = _MemoryStore();
    final summary = await importTransactions(store, bytes);
    expect(summary.rowsRead, 8);
    expect(summary.imported, 1);
    expect(summary.issues.map((i) => i.row), [2, 3, 4, 5, 6, 7, 8]);
    expect(summary.issues.first.message, contains('Unknown type "Gift"'));
    expect(store.rows.single.amountMinor, 700);
  });

  test('unreadable files and missing headers are explained', () async {
    final notExcel = decodeXlsx(Uint8List.fromList([1, 2, 3]));
    expect(notExcel.issues.single.message, contains('not a readable Excel'));
    final noHeader = decodeXlsx(
      _sheet([
        [TextCellValue('hello'), TextCellValue('world')],
      ]),
    );
    expect(noHeader.issues.single.message, contains('Header row not found'));
    final template = decodeXlsx(await transactionTemplate());
    expect(template.issues, isEmpty);
    expect(template.dataRows, 0);
  });

  test('dates keep their time of day; text times are understood', () {
    final bytes = _sheet([
      [
        TextCellValue('Type'),
        TextCellValue('Amount'),
        TextCellValue('Date'),
        TextCellValue('Account'),
        TextCellValue('Category'),
        TextCellValue('Due date'),
      ],
      for (final text in [
        '2026-11-15 14:30',
        '2026-11-15T14:30:05',
        '2026-11-15T14:30:05.123Z',
        '15/11/2026 2:30 PM',
        '15/11/2026 12:05 am',
        '15 Nov 2026, 9:07',
        '2026-11-15',
      ])
        [
          TextCellValue('Owed to me'),
          IntCellValue(1),
          TextCellValue(text),
          null,
          TextCellValue('Salary'),
          TextCellValue('2026-12-01 17:00'),
        ],
      [
        TextCellValue('Expense'),
        IntCellValue(1),
        const DateTimeCellValue(
          year: 2026,
          month: 1,
          day: 2,
          hour: 3,
          minute: 4,
          second: 5,
        ),
        TextCellValue('Cash'),
        TextCellValue('Food'),
        TextCellValue('2026-12-01'),
      ],
      [
        TextCellValue('Expense'),
        IntCellValue(1),
        DoubleCellValue(46341.75), // Excel serial: 15 Nov 2026 18:00
        TextCellValue('Cash'),
        TextCellValue('Food'),
        null,
      ],
      [
        TextCellValue('Expense'),
        IntCellValue(1),
        TextCellValue('2026-11-15 25:00'),
        TextCellValue('Cash'),
        TextCellValue('Food'),
        null,
      ],
    ]);
    final parsed = decodeXlsx(bytes);
    expect(parsed.rows.map((r) => r.date), [
      DateTime(2026, 11, 15, 14, 30),
      DateTime(2026, 11, 15, 14, 30, 5),
      DateTime(2026, 11, 15, 14, 30, 5),
      DateTime(2026, 11, 15, 14, 30),
      DateTime(2026, 11, 15, 0, 5),
      DateTime(2026, 11, 15, 9, 7),
      DateTime(2026, 11, 15),
      DateTime(2026, 1, 2, 3, 4, 5),
      DateTime(2026, 11, 15, 18),
    ]);
    expect(parsed.rows.first.dueDate, DateTime(2026, 12, 1, 17));
    // Due dates only apply to owes.
    expect(parsed.rows[7].dueDate, isNull);
    expect(parsed.issues.single.row, 11);
    expect(parsed.issues.single.message, contains('Time'));
  });
}
