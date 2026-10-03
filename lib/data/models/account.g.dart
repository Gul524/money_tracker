// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Account _$AccountFromJson(Map<String, dynamic> json) => Account(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$AccountTypeEnumMap, json['type']),
  openingBalanceMinor: (json['openingBalanceMinor'] as num?)?.toInt() ?? 0,
  isArchived: json['isArchived'] as bool? ?? false,
);

Map<String, dynamic> _$AccountToJson(Account instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$AccountTypeEnumMap[instance.type]!,
  'openingBalanceMinor': instance.openingBalanceMinor,
  'isArchived': instance.isArchived,
};

const _$AccountTypeEnumMap = {
  AccountType.cash: 'cash',
  AccountType.bank: 'bank',
  AccountType.microfinance: 'microfinance',
};
