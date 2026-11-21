import 'package:json_annotation/json_annotation.dart';

import 'model_types.dart';

part 'money_transaction.g.dart';

@JsonSerializable()
class MoneyTransaction {
  const MoneyTransaction({
    this.id,
    required this.type,
    required this.amountMinor,
    required this.categoryId,
    required this.occurredAt,
    this.accountId,
    this.note,
    this.party,
    this.dueAt,
    this.oweStatus,
    this.completedAt,
    this.exchangeAccountId,
    this.parentId,
  });

  final int? id;
  final TransactionType type;
  final int amountMinor;
  final int categoryId;
  final int? accountId;
  final DateTime occurredAt;
  final String? note;
  final String? party;
  final DateTime? dueAt;
  final OweStatus? oweStatus;
  final DateTime? completedAt;

  /// Owes only: the wallet money moved through when the owe started — lent
  /// from it (owed to me) or borrowed into it (I owe). Null when nothing was
  /// recorded or when an item was exchanged instead (see assets).
  final int? exchangeAccountId;

  /// Part payments: the owe this completed entry is a payment of (the owe
  /// itself keeps only what is still unpaid).
  final int? parentId;

  factory MoneyTransaction.fromJson(Map<String, dynamic> json) =>
      _$MoneyTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$MoneyTransactionToJson(this);

  MoneyTransaction copyWith({
    Object? id = omitted,
    TransactionType? type,
    int? amountMinor,
    int? categoryId,
    Object? accountId = omitted,
    DateTime? occurredAt,
    Object? note = omitted,
    Object? party = omitted,
    Object? dueAt = omitted,
    Object? oweStatus = omitted,
    Object? completedAt = omitted,
    Object? exchangeAccountId = omitted,
    Object? parentId = omitted,
  }) => MoneyTransaction(
    id: identical(id, omitted) ? this.id : id as int?,
    type: type ?? this.type,
    amountMinor: amountMinor ?? this.amountMinor,
    categoryId: categoryId ?? this.categoryId,
    accountId: identical(accountId, omitted)
        ? this.accountId
        : accountId as int?,
    occurredAt: occurredAt ?? this.occurredAt,
    note: identical(note, omitted) ? this.note : note as String?,
    party: identical(party, omitted) ? this.party : party as String?,
    dueAt: identical(dueAt, omitted) ? this.dueAt : dueAt as DateTime?,
    oweStatus: identical(oweStatus, omitted)
        ? this.oweStatus
        : oweStatus as OweStatus?,
    completedAt: identical(completedAt, omitted)
        ? this.completedAt
        : completedAt as DateTime?,
    exchangeAccountId: identical(exchangeAccountId, omitted)
        ? this.exchangeAccountId
        : exchangeAccountId as int?,
    parentId: identical(parentId, omitted) ? this.parentId : parentId as int?,
  );
}
