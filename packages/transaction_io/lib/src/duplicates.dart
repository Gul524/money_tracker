import 'tx_row.dart';

/// Rows are duplicates when type, account, amount and calendar day match.
/// Account names compare case-insensitively.
String duplicateKey(TxRow r) {
  final d = r.date;
  final day =
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final account = r.type == TxType.transfer
      ? () {
          final pair = r.transferAccounts;
          return pair == null
              ? r.account.toLowerCase()
              : '${pair.$1.toLowerCase()}>${pair.$2.toLowerCase()}';
        }()
      : r.account.trim().toLowerCase();
  return '${r.type.name}|$account|${r.amountMinor}|$day';
}

/// Splits [incoming] into rows to import and rows already present in
/// [existing]. Counting is one-for-one: if the app has one matching entry and
/// the file has two, one is skipped and one is imported, so legitimate repeats
/// (two equal coffees on the same day) survive an export → import round trip.
(List<TxRow> fresh, List<TxRow> duplicates) splitDuplicates(
  List<TxRow> incoming,
  List<TxRow> existing,
) {
  final remaining = <String, int>{};
  for (final r in existing) {
    final k = duplicateKey(r);
    remaining[k] = (remaining[k] ?? 0) + 1;
  }
  final fresh = <TxRow>[];
  final duplicates = <TxRow>[];
  for (final r in incoming) {
    final k = duplicateKey(r);
    final left = remaining[k] ?? 0;
    if (left > 0) {
      remaining[k] = left - 1;
      duplicates.add(r);
    } else {
      fresh.add(r);
    }
  }
  return (fresh, duplicates);
}
