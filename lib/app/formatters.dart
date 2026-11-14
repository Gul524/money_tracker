/// Human-friendly formatting for money and dates. No intl dependency.
library;

const _currencySymbols = {'PKR': 'Rs', 'USD': r'$', 'EUR': '€', 'GBP': '£'};

const currencyNames = {
  'PKR': 'Pakistani Rupee',
  'USD': 'US Dollar',
  'EUR': 'Euro',
  'GBP': 'British Pound',
};

String currencySymbol(String code) => _currencySymbols[code] ?? code;

/// Formats minor units, e.g. `Rs 12,345.50`, `$1,200.00`, `−Rs 500.00`.
/// With [signed], positive values get a leading `+`.
String money(int minor, String currency, {bool signed = false}) {
  final sign = minor < 0 ? '−' : (signed && minor > 0 ? '+' : '');
  final absolute = minor.abs();
  final whole = _groupThousands(absolute ~/ 100);
  final cents = (absolute % 100).toString().padLeft(2, '0');
  final symbol = currencySymbol(currency);
  final gap = symbol.length > 1 ? ' ' : '';
  return '$sign$symbol$gap$whole.$cents';
}

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Plain editable text for an amount: `1200` or `1200.5`.
String amountInputText(int minor) {
  final whole = minor ~/ 100;
  final cents = minor % 100;
  if (cents == 0) return '$whole';
  return '$whole.${cents.toString().padLeft(2, '0')}'.replaceFirst(
    RegExp(r'0$'),
    '',
  );
}

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _short(String name) => name.substring(0, 3);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `15 Nov 2026`
String formatDate(DateTime d) =>
    '${d.day} ${_short(monthNames[d.month - 1])} ${d.year}';

/// `November 2026`
String formatMonthYear(DateTime d) => '${monthNames[d.month - 1]} ${d.year}';

/// `Saturday, 15 November`
String formatLongDate(DateTime d) =>
    '${_weekdayNames[d.weekday - 1]}, ${d.day} ${monthNames[d.month - 1]}';

/// `Today`, `Yesterday`, `Mon, 10 Nov`, or `10 Nov 2025` for other years.
String relativeDay(DateTime d, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final day = dateOnly(d);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff == -1) return 'Tomorrow';
  if (day.year == today.year) {
    return '${_short(_weekdayNames[day.weekday - 1])}, ${day.day} '
        '${_short(monthNames[day.month - 1])}';
  }
  return formatDate(day);
}
