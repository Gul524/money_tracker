/// Pure logic behind the amount calculator: builds an expression from key
/// presses and evaluates it exactly (no floating point) to minor units.
///
/// Operators follow the usual order: × and ÷ before + and −, like a phone
/// calculator. A trailing operator is ignored when previewing the result.
library;

enum CalcOp {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const CalcOp(this.symbol);
  final String symbol;
}

class AmountCalculator {
  /// Starts from an existing amount text such as `1200` or `1250.5`.
  AmountCalculator([String initial = '']) {
    final text = initial.trim();
    if (RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(text)) {
      _tokens.add(_trimLeadingZeros(text));
    }
  }

  static const maxWholeDigits = 10;
  static const maxTokens = 41; // 21 numbers and 20 operators

  /// Numbers are stored as their typed text; operators as [CalcOp].
  final List<Object> _tokens = [];

  bool get isEmpty => _tokens.isEmpty;

  /// True once the expression contains at least one operator and a number
  /// after it, i.e. there is something to calculate.
  bool get hasOperation => _tokens.length >= 3 && _tokens.last is String;

  /// Appends a digit (`0`–`9`), `00` or `.`.
  void inputDigit(String key) {
    assert(RegExp(r'^(\d|00|\.)$').hasMatch(key));
    final last = _tokens.isEmpty ? null : _tokens.last;
    if (last is! String) {
      if (_tokens.length >= maxTokens) return;
      if (key == '00') key = '0';
      _tokens.add(key == '.' ? '0.' : key);
      return;
    }
    final next = _appendToNumber(last, key);
    if (next != null) _tokens[_tokens.length - 1] = next;
  }

  /// Adds an operator. Replaces a trailing operator; ignored when empty.
  void inputOperator(CalcOp op) {
    if (_tokens.isEmpty) return;
    if (_tokens.last is CalcOp) {
      _tokens[_tokens.length - 1] = op;
    } else if (_tokens.length < maxTokens) {
      _tokens.add(op);
    }
  }

  void backspace() {
    if (_tokens.isEmpty) return;
    final last = _tokens.last;
    if (last is String && last.length > 1) {
      _tokens[_tokens.length - 1] = last.substring(0, last.length - 1);
    } else {
      _tokens.removeLast();
    }
  }

  void clear() => _tokens.clear();

  /// Replaces the expression with its result so the user can keep going.
  /// Does nothing when the result is invalid.
  void collapse() {
    final minor = resultMinor;
    if (minor == null || minor < 0) return;
    _tokens
      ..clear()
      ..add(_minorText(minor));
  }

  /// Readable expression, e.g. `1,200 + 350.5 × 2`.
  String get expression => _tokens
      .map((t) => t is CalcOp ? t.symbol : _groupNumber(t as String))
      .join(' ');

  /// Why the expression can't be evaluated, if anything.
  String? get problem {
    final value = _evaluate();
    return value == null && _dividesByZero ? 'Can’t divide by 0' : null;
  }

  /// Result rounded to minor units (half away from zero), or null when the
  /// expression is empty or divides by zero.
  int? get resultMinor {
    final value = _evaluate();
    if (value == null) return null;
    return value.toMinor();
  }

  // -------------------------------------------------------------------------

  bool _dividesByZero = false;

  _Fraction? _evaluate() {
    _dividesByZero = false;
    final tokens = [..._tokens];
    if (tokens.isNotEmpty && tokens.last is CalcOp) tokens.removeLast();
    if (tokens.isEmpty) return null;

    // First pass: fold × and ÷ into terms; keep + and − between terms.
    final terms = <_Fraction>[_Fraction.parse(tokens.first as String)];
    final signs = <CalcOp>[];
    for (var i = 1; i + 1 < tokens.length; i += 2) {
      final op = tokens[i] as CalcOp;
      final value = _Fraction.parse(tokens[i + 1] as String);
      switch (op) {
        case CalcOp.multiply:
          terms.last = terms.last * value;
        case CalcOp.divide:
          if (value.isZero) {
            _dividesByZero = true;
            return null;
          }
          terms.last = terms.last / value;
        case CalcOp.add || CalcOp.subtract:
          signs.add(op);
          terms.add(value);
      }
    }
    var total = terms.first;
    for (var i = 0; i < signs.length; i++) {
      total = signs[i] == CalcOp.add
          ? total + terms[i + 1]
          : total - terms[i + 1];
    }
    return total;
  }

  static String? _appendToNumber(String number, String key) {
    final dot = number.indexOf('.');
    if (key == '.') return dot >= 0 ? null : '$number.';
    if (dot >= 0) {
      final room = 2 - (number.length - dot - 1);
      if (room <= 0) return null;
      return number + key.substring(0, key.length.clamp(0, room));
    }
    if (number == '0') return key == '00' ? null : key;
    final next = number + key;
    return next.length > maxWholeDigits ? null : next;
  }

  static String _trimLeadingZeros(String text) {
    final trimmed = text.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return trimmed.startsWith('.') ? '0$trimmed' : trimmed;
  }

  static String _minorText(int minor) {
    final whole = minor ~/ 100;
    final cents = minor % 100;
    if (cents == 0) return '$whole';
    final text = cents.toString().padLeft(2, '0');
    return '$whole.${text.endsWith('0') ? text[0] : text}';
  }

  static String _groupNumber(String number) {
    final dot = number.indexOf('.');
    final whole = dot >= 0 ? number.substring(0, dot) : number;
    final rest = dot >= 0 ? number.substring(dot) : '';
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '$buffer$rest';
  }
}

/// Exact rational number so `0.1 + 0.2` and `100 ÷ 3 × 3` behave.
class _Fraction {
  _Fraction(BigInt numerator, BigInt denominator)
    : assert(denominator != BigInt.zero),
      numerator = denominator.isNegative ? -numerator : numerator,
      denominator = denominator.abs();

  factory _Fraction.parse(String text) {
    final clean = text.endsWith('.')
        ? text.substring(0, text.length - 1)
        : text;
    final dot = clean.indexOf('.');
    if (dot < 0) return _Fraction(BigInt.parse(clean), BigInt.one);
    final decimals = clean.length - dot - 1;
    return _Fraction(
      BigInt.parse(clean.replaceFirst('.', '')),
      BigInt.from(10).pow(decimals),
    );
  }

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;

  _Fraction operator +(_Fraction o) => _Fraction(
    numerator * o.denominator + o.numerator * denominator,
    denominator * o.denominator,
  );
  _Fraction operator -(_Fraction o) => _Fraction(
    numerator * o.denominator - o.numerator * denominator,
    denominator * o.denominator,
  );
  _Fraction operator *(_Fraction o) =>
      _Fraction(numerator * o.numerator, denominator * o.denominator);
  _Fraction operator /(_Fraction o) =>
      _Fraction(numerator * o.denominator, denominator * o.numerator);

  /// Rounds to hundredths, half away from zero.
  int toMinor() {
    final scaled = numerator.abs() * BigInt.from(100);
    var minor = scaled ~/ denominator;
    if ((scaled % denominator) * BigInt.two >= denominator) {
      minor += BigInt.one;
    }
    return (numerator.isNegative ? -minor : minor).toInt();
  }
}
