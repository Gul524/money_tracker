// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$CategoryTypeEnumMap, json['type']),
  parentId: (json['parentId'] as num?)?.toInt(),
  icon: json['icon'] as String?,
  color: json['color'] as String?,
);

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$CategoryTypeEnumMap[instance.type]!,
  'parentId': instance.parentId,
  'icon': instance.icon,
  'color': instance.color,
};

const _$CategoryTypeEnumMap = {
  CategoryType.income: 'income',
  CategoryType.expense: 'expense',
  CategoryType.both: 'both',
};
