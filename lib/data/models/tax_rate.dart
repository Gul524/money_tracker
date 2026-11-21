import 'package:json_annotation/json_annotation.dart';

import 'model_types.dart';

part 'tax_rate.g.dart';

/// A tax the user manages in Settings › Tax, e.g. "Sales tax" (GST, 17%).
///
/// Entries copy the tax's name, code, rate and inclusive flag when they are
/// saved, so changing or deleting a tax never changes old entries.
@JsonSerializable()
class TaxRate {
  const TaxRate({
    this.id,
    required this.name,
    required this.code,
    required this.rateBasisPoints,
    this.inclusive = false,
  });

  final int? id;
  final String name;

  /// Three letters or digits, stored upper-case, e.g. `GST`.
  final String code;

  /// Percentage in hundredths: 1700 = 17%, 1250 = 12.5%.
  final int rateBasisPoints;

  /// Whether amounts typed on entries usually already include this tax.
  final bool inclusive;

  factory TaxRate.fromJson(Map<String, dynamic> json) =>
      _$TaxRateFromJson(json);
  Map<String, dynamic> toJson() => _$TaxRateToJson(this);

  TaxRate copyWith({
    Object? id = omitted,
    String? name,
    String? code,
    int? rateBasisPoints,
    bool? inclusive,
  }) => TaxRate(
    id: identical(id, omitted) ? this.id : id as int?,
    name: name ?? this.name,
    code: code ?? this.code,
    rateBasisPoints: rateBasisPoints ?? this.rateBasisPoints,
    inclusive: inclusive ?? this.inclusive,
  );
}

/// An amount split into what it is before tax and the tax on it.
class TaxSplit {
  const TaxSplit(this.subtotalMinor, this.taxMinor);
  final int subtotalMinor;
  final int taxMinor;
  int get totalMinor => subtotalMinor + taxMinor;
}

/// Tax at [rateBasisPoints] on [amountMinor]. When [inclusive], the amount
/// already contains the tax (total); otherwise tax is added on top of it.
TaxSplit splitTax(
  int amountMinor,
  int rateBasisPoints, {
  required bool inclusive,
}) {
  if (inclusive) {
    final tax = (amountMinor * rateBasisPoints / (10000 + rateBasisPoints))
        .round();
    return TaxSplit(amountMinor - tax, tax);
  }
  return TaxSplit(amountMinor, (amountMinor * rateBasisPoints / 10000).round());
}

/// `17%`, `12.5%`, `0.25%`.
String formatRate(int basisPoints) {
  final whole = basisPoints ~/ 100;
  final cents = basisPoints % 100;
  if (cents == 0) return '$whole%';
  final decimals = cents % 10 == 0
      ? '${cents ~/ 10}'
      : cents.toString().padLeft(2, '0');
  return '$whole.$decimals%';
}
