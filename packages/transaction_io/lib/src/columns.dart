/// The fixed column layout used for both export and import.
///
/// Import matches columns by header name (case and spacing ignored), so the
/// order can change and extra columns are ignored. Only Type, Amount and Date
/// are required headers.
enum TxColumn {
  sr('Sr', ['sr', 'srno', 'no', 'serial', '#']),
  type('Type', ['type', 'transactiontype', 'kind']),
  category('Category', ['category', 'categorysubcategory', 'subcategory']),
  amount('Amount', ['amount', 'value']),
  date('Date', ['date', 'day', 'datetime', 'dateandtime']),
  account('Account', ['account', 'wallet']),
  note('Note', ['note', 'notes', 'description', 'memo']),
  owedPerson('Owed person', ['owedperson', 'person', 'party']),
  dueDate('Due date', ['duedate', 'due', 'dueon']),
  owedCompleted('Owed completed', [
    'owedcompleted',
    'completed',
    'completedon',
  ]),
  owedStatus('Owed status', ['owedstatus', 'status']),
  taxPaid('Tax paid', ['taxpaid', 'tax']),
  oweWallet('Owe wallet', [
    'owewallet',
    'lentfrom',
    'borrowedinto',
    'lentborrowedwallet',
  ]),
  item('Item', ['item', 'asset', 'thing']);

  const TxColumn(this.header, this.aliases);
  final String header;
  final List<String> aliases;

  static const required = [type, amount, date];

  /// `"Owed person"` → `owedperson`.
  static String normalize(String header) =>
      header.toLowerCase().replaceAll(RegExp(r'[^a-z#]'), '');

  static TxColumn? match(String header) {
    final n = normalize(header);
    if (n.isEmpty) return null;
    for (final c in values) {
      if (c.aliases.contains(n)) return c;
    }
    return null;
  }
}
