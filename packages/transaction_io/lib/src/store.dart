import 'tx_row.dart';

/// What the host app provides so this module can read and write entries.
/// The module never touches the app's database directly.
abstract interface class TransactionIoStore {
  /// Entries with `from <= date < to`; both null means everything. Used for
  /// export and for duplicate checks.
  Future<List<TxRow>> readRows({DateTime? from, DateTime? to});

  /// Saves [rows], creating missing wallets and categories as needed.
  /// Returns a problem for each row that couldn't be saved; the others are
  /// saved.
  Future<List<RowIssue>> writeRows(List<TxRow> rows);
}
