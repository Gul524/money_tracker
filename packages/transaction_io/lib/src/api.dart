import 'dart:isolate';
import 'dart:typed_data';

import 'duplicates.dart';
import 'store.dart';
import 'tx_row.dart';
import 'xlsx_codec.dart';

class ExportResult {
  const ExportResult({
    required this.bytes,
    required this.rowCount,
    required this.fileName,
  });
  final Uint8List bytes;
  final int rowCount;

  /// Suggested name, e.g. `transactions_2026-11-01_to_2026-11-30.xlsx`.
  final String fileName;
}

class ImportSummary {
  const ImportSummary({
    required this.rowsRead,
    required this.imported,
    required this.duplicates,
    required this.issues,
  });

  /// Non-empty rows in the file.
  final int rowsRead;
  final int imported;

  /// Rows skipped because the same entry already exists.
  final int duplicates;

  /// Rows that couldn't be read or saved, plus file-level problems.
  final List<RowIssue> issues;
}

/// Exports entries with `from <= date < to` (null = no limit) to .xlsx.
/// Building the file runs on a background isolate.
Future<ExportResult> exportTransactions(
  TransactionIoStore store, {
  DateTime? from,
  DateTime? to,
}) async {
  final rows = await store.readRows(from: from, to: to);
  final bytes = await Isolate.run(() => encodeXlsx(rows));
  return ExportResult(
    bytes: bytes,
    rowCount: rows.length,
    fileName: exportFileName(from, to),
  );
}

/// An empty file with the header row and instructions, to fill and import.
Future<Uint8List> transactionTemplate() =>
    Isolate.run(() => encodeXlsx(const []));

/// Imports an .xlsx file in the export format. Reading the file and finding
/// duplicates run on a background isolate; saving goes through [store].
Future<ImportSummary> importTransactions(
  TransactionIoStore store,
  Uint8List bytes,
) async {
  final existing = await store.readRows();
  final (parsed, fresh, duplicates) = await Isolate.run(() {
    final parsed = decodeXlsx(bytes);
    final (fresh, duplicates) = splitDuplicates(parsed.rows, existing);
    return (parsed, fresh, duplicates.length);
  });
  final writeIssues = fresh.isEmpty
      ? const <RowIssue>[]
      : await store.writeRows(fresh);
  final issues = [...parsed.issues, ...writeIssues]
    ..sort((a, b) => (a.row ?? 0).compareTo(b.row ?? 0));
  return ImportSummary(
    rowsRead: parsed.dataRows,
    imported: fresh.length - writeIssues.length,
    duplicates: duplicates,
    issues: issues,
  );
}

String exportFileName(DateTime? from, DateTime? to) {
  String day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  if (from == null || to == null) return 'transactions_all.xlsx';
  final last = DateTime(to.year, to.month, to.day - 1);
  return 'transactions_${day(from)}_to_${day(last)}.xlsx';
}
