// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_rate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaxRate _$TaxRateFromJson(Map<String, dynamic> json) => TaxRate(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String,
  code: json['code'] as String,
  rateBasisPoints: (json['rateBasisPoints'] as num).toInt(),
  inclusive: json['inclusive'] as bool? ?? false,
);

Map<String, dynamic> _$TaxRateToJson(TaxRate instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'code': instance.code,
  'rateBasisPoints': instance.rateBasisPoints,
  'inclusive': instance.inclusive,
};
