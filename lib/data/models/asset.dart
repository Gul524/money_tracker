import 'package:json_annotation/json_annotation.dart';

import 'model_types.dart';

part 'asset.g.dart';

@JsonSerializable()
class Asset {
  const Asset({
    this.id,
    required this.name,
    required this.acquiredOn,
    required this.purchaseAmountMinor,
    required this.currentValueMinor,
    this.purchaseTransactionId,
    this.notes,
  });

  final int? id;
  final String name;
  final DateTime acquiredOn;
  final int purchaseAmountMinor;
  final int currentValueMinor;
  final int? purchaseTransactionId;
  final String? notes;

  factory Asset.fromJson(Map<String, dynamic> json) => _$AssetFromJson(json);
  Map<String, dynamic> toJson() => _$AssetToJson(this);

  Asset copyWith({
    Object? id = omitted,
    String? name,
    DateTime? acquiredOn,
    int? purchaseAmountMinor,
    int? currentValueMinor,
    Object? purchaseTransactionId = omitted,
    Object? notes = omitted,
  }) => Asset(
    id: identical(id, omitted) ? this.id : id as int?,
    name: name ?? this.name,
    acquiredOn: acquiredOn ?? this.acquiredOn,
    purchaseAmountMinor: purchaseAmountMinor ?? this.purchaseAmountMinor,
    currentValueMinor: currentValueMinor ?? this.currentValueMinor,
    purchaseTransactionId: identical(purchaseTransactionId, omitted)
        ? this.purchaseTransactionId
        : purchaseTransactionId as int?,
    notes: identical(notes, omitted) ? this.notes : notes as String?,
  );
}
