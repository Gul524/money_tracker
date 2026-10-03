import 'package:json_annotation/json_annotation.dart';

import 'model_types.dart';

part 'category.g.dart';

@JsonSerializable()
class Category {
  const Category({
    this.id,
    required this.name,
    required this.type,
    this.parentId,
  });

  final int? id;
  final String name;
  final CategoryType type;
  final int? parentId;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);

  Category copyWith({
    Object? id = omitted,
    String? name,
    CategoryType? type,
    Object? parentId = omitted,
  }) => Category(
    id: identical(id, omitted) ? this.id : id as int?,
    name: name ?? this.name,
    type: type ?? this.type,
    parentId: identical(parentId, omitted) ? this.parentId : parentId as int?,
  );
}
