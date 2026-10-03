import 'package:json_annotation/json_annotation.dart';

import 'model_types.dart';

part 'account.g.dart';

@JsonSerializable()
class Account {
  const Account({
    this.id,
    required this.name,
    required this.type,
    this.openingBalanceMinor = 0,
    this.isArchived = false,
  });

  final int? id;
  final String name;
  final AccountType type;

  /// Store money in the smallest currency unit to avoid floating point errors.
  final int openingBalanceMinor;
  final bool isArchived;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
  Map<String, dynamic> toJson() => _$AccountToJson(this);

  Account copyWith({
    Object? id = omitted,
    String? name,
    AccountType? type,
    int? openingBalanceMinor,
    bool? isArchived,
  }) => Account(
    id: identical(id, omitted) ? this.id : id as int?,
    name: name ?? this.name,
    type: type ?? this.type,
    openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
    isArchived: isArchived ?? this.isArchived,
  );
}
