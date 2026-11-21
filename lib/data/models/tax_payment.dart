import 'package:json_annotation/json_annotation.dart';

import 'model_types.dart';

part 'tax_payment.g.dart';

@JsonSerializable()
class TaxPayment {
  const TaxPayment({
    this.id,
    required this.amountMinor,
    required this.paidAt,
    required this.accountId,
    this.note,
    this.transactionId,
    this.taxRateId,
    this.taxName,
    this.taxCode,
    this.rateBasisPoints,
    this.inclusive,
  });

  final int? id;
  final int amountMinor;
  final DateTime paidAt;
  final int accountId;
  final String? note;

  /// Set when this tax was paid as part of an income/expense transaction.
  final int? transactionId;

  /// The managed tax this was worked out from (null once it is deleted, or
  /// for a custom amount).
  final int? taxRateId;

  /// Copies of the tax as it was when saved, so later edits of the tax
  /// don't change this entry. Null on entries saved before tax management,
  /// and for custom amounts ([rateBasisPoints]).
  final String? taxName;
  final String? taxCode;
  final int? rateBasisPoints;

  /// Whether the entry's typed amount included this tax. Null on entries
  /// saved before tax management.
  final bool? inclusive;

  /// Short name for lists: the code, else the name, else null.
  String? get label => (taxCode ?? '').isNotEmpty
      ? taxCode
      : (taxName ?? '').isNotEmpty
      ? taxName
      : null;

  factory TaxPayment.fromJson(Map<String, dynamic> json) =>
      _$TaxPaymentFromJson(json);
  Map<String, dynamic> toJson() => _$TaxPaymentToJson(this);

  TaxPayment copyWith({
    Object? id = omitted,
    int? amountMinor,
    DateTime? paidAt,
    int? accountId,
    Object? note = omitted,
    Object? transactionId = omitted,
    Object? taxRateId = omitted,
    Object? taxName = omitted,
    Object? taxCode = omitted,
    Object? rateBasisPoints = omitted,
    Object? inclusive = omitted,
  }) => TaxPayment(
    id: identical(id, omitted) ? this.id : id as int?,
    amountMinor: amountMinor ?? this.amountMinor,
    paidAt: paidAt ?? this.paidAt,
    accountId: accountId ?? this.accountId,
    note: identical(note, omitted) ? this.note : note as String?,
    transactionId: identical(transactionId, omitted)
        ? this.transactionId
        : transactionId as int?,
    taxRateId: identical(taxRateId, omitted)
        ? this.taxRateId
        : taxRateId as int?,
    taxName: identical(taxName, omitted) ? this.taxName : taxName as String?,
    taxCode: identical(taxCode, omitted) ? this.taxCode : taxCode as String?,
    rateBasisPoints: identical(rateBasisPoints, omitted)
        ? this.rateBasisPoints
        : rateBasisPoints as int?,
    inclusive: identical(inclusive, omitted)
        ? this.inclusive
        : inclusive as bool?,
  );
}

/// How a linked tax was worked out, copied onto the tax payment row.
class TaxDetails {
  const TaxDetails({
    this.taxRateId,
    this.name,
    this.code,
    this.rateBasisPoints,
    this.inclusive = false,
  });

  /// A custom amount typed by the user.
  const TaxDetails.custom({this.inclusive = false})
    : taxRateId = null,
      name = null,
      code = null,
      rateBasisPoints = null;

  final int? taxRateId;
  final String? name;
  final String? code;
  final int? rateBasisPoints;
  final bool inclusive;

  /// Columns for a tax saved without details.
  static const Map<String, Object?> none = {
    'tax_rate_id': null,
    'tax_name': null,
    'tax_code': null,
    'rate_bp': null,
    'inclusive': null,
  };

  Map<String, Object?> toRow() => {
    'tax_rate_id': taxRateId,
    'tax_name': name,
    'tax_code': code,
    'rate_bp': rateBasisPoints,
    'inclusive': inclusive ? 1 : 0,
  };
}
