class MoneyAmount {
  static int parse(
    String input, {
    bool allowZero = false,
    bool allowNegative = false,
  }) {
    final value = input.trim();
    final pattern = allowNegative
        ? RegExp(r'^-?\d+(?:\.\d{1,2})?$')
        : RegExp(r'^\d+(?:\.\d{1,2})?$');
    if (!pattern.hasMatch(value)) {
      throw ArgumentError('Enter a valid amount with up to 2 decimals');
    }
    final negative = value.startsWith('-');
    final parts = (negative ? value.substring(1) : value).split('.');
    final amount =
        int.parse(parts[0]) * 100 +
        (parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0);
    if (!allowZero && amount == 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
    return negative ? -amount : amount;
  }
}
