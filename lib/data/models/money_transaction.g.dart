// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'money_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoneyTransaction _$MoneyTransactionFromJson(Map<String, dynamic> json) =>
    MoneyTransaction(
      id: (json['id'] as num?)?.toInt(),
      type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
      amountMinor: (json['amountMinor'] as num).toInt(),
      categoryId: (json['categoryId'] as num).toInt(),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      accountId: (json['accountId'] as num?)?.toInt(),
      note: json['note'] as String?,
      party: json['party'] as String?,
      dueAt: json['dueAt'] == null
          ? null
          : DateTime.parse(json['dueAt'] as String),
      oweStatus: $enumDecodeNullable(_$OweStatusEnumMap, json['oweStatus']),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );

Map<String, dynamic> _$MoneyTransactionToJson(MoneyTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'amountMinor': instance.amountMinor,
      'categoryId': instance.categoryId,
      'accountId': instance.accountId,
      'occurredAt': instance.occurredAt.toIso8601String(),
      'note': instance.note,
      'party': instance.party,
      'dueAt': instance.dueAt?.toIso8601String(),
      'oweStatus': _$OweStatusEnumMap[instance.oweStatus],
      'completedAt': instance.completedAt?.toIso8601String(),
    };

const _$TransactionTypeEnumMap = {
  TransactionType.income: 'income',
  TransactionType.expense: 'expense',
  TransactionType.oweIn: 'oweIn',
  TransactionType.oweOut: 'oweOut',
};

const _$OweStatusEnumMap = {
  OweStatus.pending: 'pending',
  OweStatus.completed: 'completed',
};
