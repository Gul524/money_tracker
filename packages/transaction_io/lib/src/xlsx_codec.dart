import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'columns.dart';
import 'tx_row.dart';

/// Name of the sheet holding the rows.
const transactionsSheet = 'Transactions';
const _readMeSheet = 'How to import';

/// Builds an .xlsx file. Synchronous and CPU-bound: call it from an isolate.
Uint8List encodeXlsx(List<TxRow> rows) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
  excel.rename(defaultSheet, transactionsSheet);
  final sheet = excel[transactionsSheet];

  sheet.appendRow([for (final c in TxColumn.values) TextCellValue(c.header)]);
  final bold = CellStyle(bold: true);
  for (var i = 0; i < TxColumn.values.length; i++) {
    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle =
        bold;
  }

  var sr = 0;
  for (final r in rows) {
    sr++;
    sheet.appendRow([for (final c in TxColumn.values) _cell(c, r, sr)]);
  }

  const widths = [6.0, 12, 26, 14, 20, 22, 30, 18, 20, 20, 13, 12, 18, 22];
  for (var i = 0; i < widths.length; i++) {
    sheet.setColumnWidth(i, widths[i].toDouble());
  }

  final help = excel[_readMeSheet];
  for (final line in _readMe) {
    help.appendRow([TextCellValue(line)]);
  }
  help.setColumnWidth(0, 110);
  excel.setDefaultSheet(transactionsSheet);

  final bytes = excel.encode();
  if (bytes == null) throw StateError('Could not build the Excel file');
  return Uint8List.fromList(bytes);
}

CellValue? _cell(TxColumn column, TxRow r, int sr) => switch (column) {
  TxColumn.sr => IntCellValue(sr),
  TxColumn.type => TextCellValue(r.type.label),
  TxColumn.category => _text(r.category),
  TxColumn.amount => DoubleCellValue(r.amountMinor / 100),
  TxColumn.date => _dateTime(r.date),
  TxColumn.account => _text(r.account),
  TxColumn.note => _text(r.note),
  TxColumn.owedPerson => _text(r.owedPerson),
  TxColumn.dueDate => r.dueDate == null ? null : _dateTime(r.dueDate!),
  TxColumn.owedCompleted =>
    r.owedCompleted == null ? null : _dateTime(r.owedCompleted!),
  TxColumn.owedStatus =>
    r.owedStatus == null ? null : TextCellValue(r.owedStatus!.label),
  TxColumn.taxPaid =>
    r.taxMinor == 0 ? null : DoubleCellValue(r.taxMinor / 100),
  TxColumn.oweWallet => _text(r.oweWallet),
  TxColumn.item => _text(r.item),
};

CellValue? _text(String s) => s.isEmpty ? null : TextCellValue(s);

/// Date and time of day, to the second (Excel shows `yyyy-mm-dd hh:mm:ss`).
CellValue _dateTime(DateTime d) => DateTimeCellValue(
  year: d.year,
  month: d.month,
  day: d.day,
  hour: d.hour,
  minute: d.minute,
  second: d.second,
);

const _readMe = [
  'Fill the "Transactions" sheet, one entry per row. Keep the header row.',
  'Type: Income, Expense, Owed to me, I owe, Tax or Transfer.',
  'Category: name, or Parent / Child for a subcategory. Missing categories are created. Not used for Tax and Transfer.',
  'Amount: a positive number, e.g. 1250.50.',
  'Date: an Excel date and time, or text like 2026-11-15 14:30, 15/11/2026 2:30 PM or 2026-11-15 (midnight).',
  'Account: wallet name. Missing wallets are created. For a Transfer write From → To (or From -> To).',
  'Owed person, Due date, Owed completed (date and time) and Owed status (Pending or Completed) are for Owed to me / I owe.',
  'Tax paid: optional tax paid with an Income or Expense.',
  'Owe wallet (optional, owes only): the wallet money was lent from (Owed to me) or borrowed into (I owe) when it started.',
  'Item (optional): a thing bought with an Expense, received in an I owe, or given in an Owed to me. Kept with your assets. Use either Owe wallet or Item.',
  'Rows that match an existing entry by type, account, amount and date are skipped as duplicates.',
];

/// Result of reading a file: valid rows and problems with the others.
class ParsedFile {
  const ParsedFile(this.rows, this.issues, this.dataRows);
  final List<TxRow> rows;
  final List<RowIssue> issues;

  /// Non-empty rows below the header.
  final int dataRows;
}

/// Reads an .xlsx file. Synchronous and CPU-bound: call it from an isolate.
ParsedFile decodeXlsx(Uint8List bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (_) {
    return const ParsedFile([], [
      RowIssue(null, 'This file is not a readable Excel (.xlsx) file.'),
    ], 0);
  }
  final sheet =
      excel.tables[transactionsSheet] ??
      excel.tables.values.where((t) => t.maxRows > 0).firstOrNull;
  if (sheet == null) {
    return const ParsedFile([], [RowIssue(null, 'The file has no rows.')], 0);
  }

  final table = sheet.rows;
  var headerIndex = -1;
  final columns = <TxColumn, int>{};
  for (var i = 0; i < table.length && headerIndex < 0; i++) {
    final found = <TxColumn, int>{};
    for (var j = 0; j < table[i].length; j++) {
      final c = TxColumn.match(_asText(table[i][j]?.value));
      if (c != null) found.putIfAbsent(c, () => j);
    }
    if (TxColumn.required.every(found.containsKey)) {
      headerIndex = i;
      columns.addAll(found);
    }
  }
  if (headerIndex < 0) {
    return ParsedFile(const [], [
      RowIssue(
        null,
        'Header row not found. It needs at least '
        '${TxColumn.required.map((c) => c.header).join(', ')}.',
      ),
    ], 0);
  }

  final rows = <TxRow>[];
  final issues = <RowIssue>[];
  var dataRows = 0;
  for (var i = headerIndex + 1; i < table.length; i++) {
    final line = table[i];
    CellValue? at(TxColumn c) {
      final j = columns[c];
      return j == null || j >= line.length ? null : line[j]?.value;
    }

    final relevant = TxColumn.values
        .where((c) => c != TxColumn.sr)
        .map((c) => _asText(at(c)));
    if (relevant.every((s) => s.trim().isEmpty)) continue;
    dataRows++;
    try {
      rows.add(_parseRow(at, i + 1));
    } on FormatException catch (e) {
      issues.add(RowIssue(i + 1, e.message));
    }
  }
  return ParsedFile(rows, issues, dataRows);
}

TxRow _parseRow(CellValue? Function(TxColumn) at, int rowNumber) {
  final type = _parseType(_asText(at(TxColumn.type)));
  final amount = _parseAmount(at(TxColumn.amount), 'Amount');
  if (amount == null || amount == 0) {
    throw const FormatException('Amount is missing or zero');
  }
  final date = _parseDate(at(TxColumn.date));
  if (date == null) throw const FormatException('Date is missing or invalid');

  final category = _asText(at(TxColumn.category)).trim();
  final account = _asText(at(TxColumn.account)).trim();
  final tax = _parseAmount(at(TxColumn.taxPaid), 'Tax paid') ?? 0;
  final completed = _parseDate(at(TxColumn.owedCompleted));
  final due = _parseDate(at(TxColumn.dueDate));
  final statusText = _asText(at(TxColumn.owedStatus)).trim().toLowerCase();
  final oweWallet = type.isOwe ? _asText(at(TxColumn.oweWallet)).trim() : '';
  final item = type.isOwe || type == TxType.expense
      ? _asText(at(TxColumn.item)).trim()
      : '';
  if (oweWallet.isNotEmpty && item.isNotEmpty) {
    throw const FormatException('Use either Owe wallet or Item, not both');
  }

  if (type.needsCategory && category.isEmpty) {
    throw FormatException('Category is required for ${type.label}');
  }
  OwedStatus? status;
  if (type.isOwe) {
    status = statusText.startsWith('c') || statusText.startsWith('paid')
        ? OwedStatus.completed
        : statusText.isEmpty && completed != null
        ? OwedStatus.completed
        : OwedStatus.pending;
    if (status == OwedStatus.completed && account.isEmpty) {
      throw const FormatException('A completed owe needs an Account');
    }
  } else if (account.isEmpty) {
    throw FormatException('Account is required for ${type.label}');
  }
  final row = TxRow(
    type: type,
    amountMinor: amount.abs(),
    date: date,
    category: type.needsCategory ? category : '',
    account: account,
    note: _asText(at(TxColumn.note)).trim(),
    owedPerson: type.isOwe ? _asText(at(TxColumn.owedPerson)).trim() : '',
    dueDate: type.isOwe ? due : null,
    owedCompleted: status == OwedStatus.completed ? (completed ?? date) : null,
    owedStatus: status,
    taxMinor: type == TxType.income || type == TxType.expense ? tax.abs() : 0,
    oweWallet: oweWallet,
    item: item,
    sourceRow: rowNumber,
  );
  if (type == TxType.transfer) {
    final pair = row.transferAccounts;
    if (pair == null) {
      throw const FormatException('Transfer Account must look like From → To');
    }
    if (pair.$1.toLowerCase() == pair.$2.toLowerCase()) {
      throw const FormatException('Transfer needs two different accounts');
    }
  }
  return row;
}

TxType _parseType(String text) {
  final t = text.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  return switch (t) {
    'income' || 'in' || 'incoming' || 'credit' => TxType.income,
    'expense' || 'out' || 'outgoing' || 'spent' || 'debit' => TxType.expense,
    'owedtome' || 'owein' || 'someoneowesme' || 'lent' => TxType.owedToMe,
    'iowe' || 'oweout' || 'iowesomeone' || 'borrowed' => TxType.iOwe,
    'tax' || 'taxpayment' || 'taxpaid' => TxType.tax,
    'transfer' => TxType.transfer,
    _ => throw FormatException(
      text.trim().isEmpty
          ? 'Type is missing'
          : 'Unknown type "$text". Use ${TxType.values.map((t) => t.label).join(', ')}',
    ),
  };
}

int? _parseAmount(CellValue? v, String label) {
  final num? n = switch (v) {
    null => null,
    IntCellValue(:final value) => value,
    DoubleCellValue(:final value) => value,
    _ => () {
      final s = _asText(v).replaceAll(RegExp(r'[^0-9.\-]'), '');
      if (s.isEmpty) return null;
      final parsed = num.tryParse(s);
      if (parsed == null)
        throw FormatException('$label "${_asText(v)}" is not a number');
      return parsed;
    }(),
  };
  return n == null ? null : (n * 100).round();
}

const _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

DateTime? _parseDate(CellValue? v) {
  switch (v) {
    case null:
      return null;
    case DateCellValue():
      return v.asDateTimeLocal();
    case DateTimeCellValue():
      return DateTime(v.year, v.month, v.day, v.hour, v.minute, v.second);
    case IntCellValue(:final value):
      return _fromSerial(value.toDouble());
    case DoubleCellValue(:final value):
      return _fromSerial(value);
    default:
      final s = _asText(v).trim();
      if (s.isEmpty) return null;
      final match = _dateText.firstMatch(s);
      final day = match == null ? null : _datePart(match.group(1)!.trim());
      if (match == null || day == null) {
        throw FormatException(
          'Date "$s" is not recognised. Use 2026-11-15 14:30',
        );
      }
      return _withTime(day, match, s);
  }
}

/// Date part, then an optional time: `14:30`, `14:30:05`, `2:30 PM`,
/// separated by a space, `T`, or `,`. A trailing `Z`/offset is ignored.
final _dateText = RegExp(
  r'^(.+?)(?:[\sT,]+(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?\s*([AaPp]\.?[Mm]\.?)?)?\s*(?:Z|[+\-]\d{2}:?\d{2})?$',
);

DateTime? _datePart(String s) {
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (iso != null) return _date(iso.group(1)!, iso.group(2)!, iso.group(3)!);
  final dmy = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$').firstMatch(s);
  if (dmy != null) return _date(dmy.group(3)!, dmy.group(2)!, dmy.group(1)!);
  final named = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*,?\s+(\d{4})$')
      .firstMatch(s);
  if (named != null) {
    final m = _months.indexOf(named.group(2)!.toLowerCase()) + 1;
    if (m > 0) return _date(named.group(3)!, '$m', named.group(1)!);
  }
  return null;
}

DateTime _withTime(DateTime day, RegExpMatch m, String original) {
  if (m.group(2) == null) return day;
  var hour = int.parse(m.group(2)!);
  final minute = int.parse(m.group(3)!);
  final second = int.parse(m.group(4) ?? '0');
  final meridiem = m.group(5)?.toLowerCase().replaceAll('.', '');
  if (meridiem != null) {
    if (hour < 1 || hour > 12) {
      throw FormatException('Time in "$original" is not valid');
    }
    hour = hour % 12 + (meridiem == 'pm' ? 12 : 0);
  }
  if (hour > 23 || minute > 59 || second > 59) {
    throw FormatException('Time in "$original" is not valid');
  }
  return DateTime(day.year, day.month, day.day, hour, minute, second);
}

DateTime? _date(String y, String m, String d) {
  final year = int.parse(y), month = int.parse(m), day = int.parse(d);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    throw FormatException('Date $y-$m-$d is not a real date');
  }
  return DateTime(year, month, day);
}

/// Excel serial day number (1900 system) → date.
DateTime _fromSerial(double serial) {
  final base = DateTime(1899, 12, 30);
  final days = serial.floor();
  final dayFraction = serial - days;
  return DateTime(
    base.year,
    base.month,
    base.day + days,
    // Excel stores time as a fraction of a day; round to whole seconds.
  ).add(Duration(seconds: (dayFraction * 86400).round()));
}

String _asText(CellValue? v) => switch (v) {
  null => '',
  TextCellValue(:final value) => value.toString(),
  IntCellValue(:final value) => '$value',
  DoubleCellValue(:final value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value',
  BoolCellValue(:final value) => '$value',
  DateCellValue() =>
    '${v.year}-${'${v.month}'.padLeft(2, '0')}-${'${v.day}'.padLeft(2, '0')}',
  _ => v.toString(),
};
