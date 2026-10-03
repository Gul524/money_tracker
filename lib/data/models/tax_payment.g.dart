// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_payment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaxPayment _$TaxPaymentFromJson(Map<String, dynamic> json) => TaxPayment(
  id: (json['id'] as num?)?.toInt(),
  amountMinor: (json['amountMinor'] as num).toInt(),
  paidAt: DateTime.parse(json['paidAt'] as String),
  accountId: (json['accountId'] as num).toInt(),
  note: json['note'] as String?,
);

Map<String, dynamic> _$TaxPaymentToJson(TaxPayment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amountMinor': instance.amountMinor,
      'paidAt': instance.paidAt.toIso8601String(),
      'accountId': instance.accountId,
      'note': instance.note,
    };
