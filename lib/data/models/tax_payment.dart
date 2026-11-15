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
  });

  final int? id;
  final int amountMinor;
  final DateTime paidAt;
  final int accountId;
  final String? note;

  /// Set when this tax was paid as part of an income/expense transaction.
  final int? transactionId;

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
  }) => TaxPayment(
    id: identical(id, omitted) ? this.id : id as int?,
    amountMinor: amountMinor ?? this.amountMinor,
    paidAt: paidAt ?? this.paidAt,
    accountId: accountId ?? this.accountId,
    note: identical(note, omitted) ? this.note : note as String?,
    transactionId: identical(transactionId, omitted)
        ? this.transactionId
        : transactionId as int?,
  );
}
