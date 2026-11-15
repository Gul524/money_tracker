/// Excel import/export of money tracker entries.
///
/// Self-contained module: the host app implements [TransactionIoStore] and
/// calls [exportTransactions], [importTransactions] or [transactionTemplate].
/// File building/reading and duplicate detection run on a background isolate.
library;

export 'src/api.dart';
export 'src/columns.dart';
export 'src/duplicates.dart' show duplicateKey, splitDuplicates;
export 'src/store.dart';
export 'src/tx_row.dart';
export 'src/xlsx_codec.dart'
    show decodeXlsx, encodeXlsx, transactionsSheet, ParsedFile;
