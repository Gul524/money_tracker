/// Kinds of entries in the exchange file. Labels are what appears in the
/// "Type" column.
enum TxType {
  income('Income'),
  expense('Expense'),
  owedToMe('Owed to me'),
  iOwe('I owe'),
  tax('Tax'),
  transfer('Transfer');

  const TxType(this.label);
  final String label;

  bool get isOwe => this == owedToMe || this == iOwe;
  bool get needsCategory => this == income || this == expense || isOwe;
  bool get isIncomeSide => this == income || this == owedToMe;
}

enum OwedStatus {
  pending('Pending'),
  completed('Completed');

  const OwedStatus(this.label);
  final String label;
}

/// Separator between the two wallets of a transfer in the "Account" column.
const transferArrow = ' → ';

/// Separator between levels in the "Category" column.
const categorySeparator = ' / ';

/// One line of the exchange file. Plain data, so it can cross isolates.
class TxRow {
  const TxRow({
    required this.type,
    required this.amountMinor,
    required this.date,
    this.category = '',
    this.account = '',
    this.note = '',
    this.owedPerson = '',
    this.dueDate,
    this.owedCompleted,
    this.owedStatus,
    this.taxMinor = 0,
    this.sourceRow,
  });

  final TxType type;

  /// Always positive, in minor units (×100).
  final int amountMinor;

  /// When the entry happened, including time of day.
  final DateTime date;

  /// `Parent / Child` path; empty for tax and transfers.
  final String category;

  /// Wallet name. Transfers use `From → To`. May be empty for a pending owe.
  final String account;
  final String note;
  final String owedPerson;

  /// When an owe is due (date and time); owes only.
  final DateTime? dueDate;

  /// When an owe was completed (received / paid back).
  final DateTime? owedCompleted;
  final OwedStatus? owedStatus;

  /// Tax paid together with an income or expense.
  final int taxMinor;

  /// 1-based spreadsheet row this came from (imports only).
  final int? sourceRow;

  /// Category levels, top first.
  List<String> get categoryPath => category
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// The (from, to) wallets of a transfer, or null if [account] isn't a pair.
  (String, String)? get transferAccounts {
    for (final arrow in const ['→', '->', '=>']) {
      final i = account.indexOf(arrow);
      if (i > 0) {
        final from = account.substring(0, i).trim();
        final to = account.substring(i + arrow.length).trim();
        if (from.isNotEmpty && to.isNotEmpty) return (from, to);
      }
    }
    return null;
  }

  @override
  String toString() =>
      'TxRow(${type.label}, $amountMinor, ${date.toIso8601String()}, '
      '$category, $account)';
}

/// A problem with one spreadsheet row.
class RowIssue {
  const RowIssue(this.row, this.message);

  /// 1-based spreadsheet row, or null when not tied to a row.
  final int? row;
  final String message;

  @override
  String toString() => row == null ? message : 'Row $row: $message';
}
