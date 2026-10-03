// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_transfer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountTransfer _$AccountTransferFromJson(Map<String, dynamic> json) =>
    AccountTransfer(
      id: (json['id'] as num?)?.toInt(),
      fromAccountId: (json['fromAccountId'] as num).toInt(),
      toAccountId: (json['toAccountId'] as num).toInt(),
      amountMinor: (json['amountMinor'] as num).toInt(),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      note: json['note'] as String?,
    );

Map<String, dynamic> _$AccountTransferToJson(AccountTransfer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromAccountId': instance.fromAccountId,
      'toAccountId': instance.toAccountId,
      'amountMinor': instance.amountMinor,
      'occurredAt': instance.occurredAt.toIso8601String(),
      'note': instance.note,
    };
