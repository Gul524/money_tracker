// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Asset _$AssetFromJson(Map<String, dynamic> json) => Asset(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String,
  acquiredOn: DateTime.parse(json['acquiredOn'] as String),
  purchaseAmountMinor: (json['purchaseAmountMinor'] as num).toInt(),
  currentValueMinor: (json['currentValueMinor'] as num).toInt(),
  purchaseTransactionId: (json['purchaseTransactionId'] as num?)?.toInt(),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$AssetToJson(Asset instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'acquiredOn': instance.acquiredOn.toIso8601String(),
  'purchaseAmountMinor': instance.purchaseAmountMinor,
  'currentValueMinor': instance.currentValueMinor,
  'purchaseTransactionId': instance.purchaseTransactionId,
  'notes': instance.notes,
};
