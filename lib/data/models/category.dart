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
    this.icon,
    this.color,
  });

  final int? id;
  final String name;
  final CategoryType type;
  final int? parentId;

  /// Key of a chosen icon (see `categoryIconGroups`); null = automatic.
  final String? icon;

  /// Tag color as `#RRGGBB`; null = automatic.
  final String? color;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);

  Category copyWith({
    Object? id = omitted,
    String? name,
    CategoryType? type,
    Object? parentId = omitted,
    Object? icon = omitted,
    Object? color = omitted,
  }) => Category(
    id: identical(id, omitted) ? this.id : id as int?,
    name: name ?? this.name,
    type: type ?? this.type,
    parentId: identical(parentId, omitted) ? this.parentId : parentId as int?,
    icon: identical(icon, omitted) ? this.icon : icon as String?,
    color: identical(color, omitted) ? this.color : color as String?,
  );
}
