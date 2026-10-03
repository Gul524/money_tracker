import '../models/category.dart';
import '../models/model_types.dart';
import 'crud_repository.dart';

class CategoryRepository extends CrudRepository<Category> {
  CategoryRepository(super.storage);

  @override
  String get table => 'categories';

  @override
  Category fromRow(Map<String, Object?> row) => Category(
    id: row['id'] as int,
    name: row['name'] as String,
    type: CategoryType.values.byName(row['type'] as String),
    parentId: row['parent_id'] as int?,
  );

  @override
  Map<String, Object?> toRow(Category value) => {
    'id': value.id,
    'name': value.name.trim(),
    'type': value.type.name,
    'parent_id': value.parentId,
  };

  @override
  Category withId(Category value, int id) => value.copyWith(id: id);

  @override
  Future<void> validate(Category value, {int? updatingId}) async {
    if (value.name.trim().isEmpty) {
      throw ArgumentError('Category name is required');
    }
    if (updatingId != null) await _checkExistingTransactions(value, updatingId);
    if (value.parentId == null) return;
    final parent = await getById(value.parentId!);
    if (parent == null) throw ArgumentError('Parent category does not exist');
    if (updatingId != null) await _checkNoCycle(updatingId, parent);
  }

  Future<void> _checkExistingTransactions(Category value, int id) async {
    final db = await storage.database;
    final types = await db.rawQuery(
      'SELECT DISTINCT type FROM transactions WHERE category_id = ?',
      [id],
    );
    for (final row in types) {
      final income = row['type'] == 'income' || row['type'] == 'oweIn';
      if (value.type != CategoryType.both &&
          value.type != (income ? CategoryType.income : CategoryType.expense)) {
        throw ArgumentError(
          'Category type conflicts with existing transactions',
        );
      }
    }
  }

  Future<void> _checkNoCycle(int id, Category parent) async {
    Category? current = parent;
    while (current != null) {
      if (current.id == id) {
        throw ArgumentError('Category hierarchy cannot contain a cycle');
      }
      current = current.parentId == null
          ? null
          : await getById(current.parentId!);
    }
  }

  Future<List<Category>> childrenOf(int? parentId) async {
    final db = await storage.database;
    final rows = await db.query(
      table,
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(fromRow).toList();
  }
}
