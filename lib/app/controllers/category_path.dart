import '../../data/models/category.dart';

String categoryPath(Category category, List<Category> categories) {
  final byId = {for (final c in categories) c.id: c};
  final names = <String>[category.name];
  var parentId = category.parentId;
  final visited = <int>{};
  while (parentId != null && visited.add(parentId)) {
    final parent = byId[parentId];
    if (parent == null) break;
    names.insert(0, parent.name);
    parentId = parent.parentId;
  }
  return names.join(' / ');
}
