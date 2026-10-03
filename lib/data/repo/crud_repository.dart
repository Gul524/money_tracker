import '../services/local_database.dart';

abstract class CrudRepository<T> {
  CrudRepository(this.storage);

  final LocalDatabase storage;
  String get table;
  T fromRow(Map<String, Object?> row);
  Map<String, Object?> toRow(T value);
  T withId(T value, int id);

  Future<void> validate(T value, {int? updatingId}) async {}

  Future<T> create(T value) async {
    if (toRow(value)['id'] != null) {
      throw ArgumentError('New entities must not already have an id');
    }
    await validate(value);
    final db = await storage.database;
    final id = await db.insert(table, toRow(value));
    return withId(value, id);
  }

  Future<T?> getById(int id) async {
    final db = await storage.database;
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : fromRow(rows.first);
  }

  Future<List<T>> getAll() async {
    final db = await storage.database;
    final rows = await db.query(table, orderBy: 'id DESC');
    return rows.map(fromRow).toList();
  }

  Future<T> update(T value) async {
    final id = toRow(value)['id'] as int?;
    if (id == null) {
      throw ArgumentError('Cannot update an entity without an id');
    }
    await validate(value, updatingId: id);
    final db = await storage.database;
    final count = await db.update(
      table,
      toRow(value),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) throw StateError('$table row $id does not exist');
    return value;
  }

  Future<void> delete(int id) async {
    final db = await storage.database;
    final count = await db.delete(table, where: 'id = ?', whereArgs: [id]);
    if (count == 0) throw StateError('$table row $id does not exist');
  }
}
