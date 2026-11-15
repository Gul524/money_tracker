import 'dart:typed_data';

import 'package:transaction_io/transaction_io.dart';

import '../../data/services/transaction_io_store.dart';
import '../date_range.dart';
import 'base_controller.dart';

/// Settings › Import and export. Thin wrapper over the `transaction_io`
/// module: picks the period and calls the module's functions.
class ImportExportController extends BaseController {
  ImportExportController(
    super.services, {
    DateTime? now,
    TransactionIoStore? store,
  }) : _now = now,
       store = store ?? AppTransactionIoStore(services.database),
       range = DateRange.month(now ?? DateTime.now()) {
    refresh();
  }

  final DateTime? _now;
  final TransactionIoStore store;
  ReportPeriod period = ReportPeriod.month;
  DateRange range;

  /// Entries in [range] (what an export would contain).
  int? entryCount;

  /// What the last import did, shown until the next one.
  ImportSummary? lastImport;

  DateTime get _today => _now ?? DateTime.now();

  @override
  void refresh() {
    run(() async {
      entryCount = (await store.readRows(
        from: range.start,
        to: range.end,
      )).length;
    });
  }

  void setPeriod(ReportPeriod value) {
    if (value == ReportPeriod.custom) return;
    period = value;
    range = DateRange.current(value, _today)!;
    refresh();
  }

  void setCustomRange(DateRange value) {
    period = ReportPeriod.custom;
    range = value;
    refresh();
  }

  bool get canStep => period != ReportPeriod.custom;
  bool get canGoNext => range.canStepForward(period, _today);

  void previous() {
    if (!canStep) return;
    range = range.step(period, -1);
    refresh();
  }

  void next() {
    if (!canGoNext) return;
    range = range.step(period, 1);
    refresh();
  }

  /// Builds the .xlsx for [range] on a background isolate.
  Future<ExportResult?> export() =>
      run(() => exportTransactions(store, from: range.start, to: range.end));

  Future<Uint8List?> template() => run(transactionTemplate);

  /// Imports [bytes]; refreshes every screen when something was added.
  Future<ImportSummary?> import(Uint8List bytes) async {
    final summary = await run(() => importTransactions(store, bytes));
    if (summary != null) {
      lastImport = summary;
      if (summary.imported > 0) services.changed();
      changed();
    }
    return summary;
  }
}
