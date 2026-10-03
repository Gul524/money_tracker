import 'package:json_annotation/json_annotation.dart';

import 'model_types.dart';

part 'account_transfer.g.dart';

@JsonSerializable()
class AccountTransfer {
  const AccountTransfer({
    this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountMinor,
    required this.occurredAt,
    this.note,
  });
  final int? id;
  final int fromAccountId;
  final int toAccountId;
  final int amountMinor;
  final DateTime occurredAt;
  final String? note;

  factory AccountTransfer.fromJson(Map<String, dynamic> json) =>
      _$AccountTransferFromJson(json);
  Map<String, dynamic> toJson() => _$AccountTransferToJson(this);

  AccountTransfer copyWith({
    Object? id = omitted,
    int? fromAccountId,
    int? toAccountId,
    int? amountMinor,
    DateTime? occurredAt,
    Object? note = omitted,
  }) => AccountTransfer(
    id: identical(id, omitted) ? this.id : id as int?,
    fromAccountId: fromAccountId ?? this.fromAccountId,
    toAccountId: toAccountId ?? this.toAccountId,
    amountMinor: amountMinor ?? this.amountMinor,
    occurredAt: occurredAt ?? this.occurredAt,
    note: identical(note, omitted) ? this.note : note as String?,
  );
}
