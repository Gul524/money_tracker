import '../models/tax_rate.dart';
import 'crud_repository.dart';

/// Taxes managed in Settings › Tax (name, 3-character code, percentage).
class TaxRateRepository extends CrudRepository<TaxRate> {
  TaxRateRepository(super.storage);

  static final _code = RegExp(r'^[A-Z0-9]{3}$');

  @override
  String get table => 'tax_rates';

  @override
  TaxRate fromRow(Map<String, Object?> row) => TaxRate(
    id: row['id'] as int,
    name: row['name'] as String,
    code: row['code'] as String,
    rateBasisPoints: row['rate_bp'] as int,
    inclusive: row['inclusive'] == 1,
  );

  @override
  Map<String, Object?> toRow(TaxRate value) => {
    'id': value.id,
    'name': value.name.trim(),
    'code': value.code.trim().toUpperCase(),
    'rate_bp': value.rateBasisPoints,
    'inclusive': value.inclusive ? 1 : 0,
  };

  @override
  TaxRate withId(TaxRate value, int id) => value.copyWith(id: id);

  @override
  Future<void> validate(TaxRate value, {int? updatingId}) async {
    if (value.name.trim().isEmpty) throw ArgumentError('Enter a tax name');
    final code = value.code.trim().toUpperCase();
    if (!_code.hasMatch(code)) {
      throw ArgumentError('Tax code must be 3 letters or digits, e.g. GST');
    }
    if (value.rateBasisPoints <= 0 || value.rateBasisPoints > 10000) {
      throw ArgumentError('Percentage must be more than 0 and at most 100');
    }
    final db = await storage.database;
    final clash = await db.query(
      table,
      columns: ['id'],
      where: 'code = ? COLLATE NOCASE AND id IS NOT ?',
      whereArgs: [code, updatingId],
      limit: 1,
    );
    if (clash.isNotEmpty) {
      throw ArgumentError('Another tax already uses the code $code');
    }
  }

  /// All taxes sorted by name.
  Future<List<TaxRate>> sorted() async {
    final db = await storage.database;
    final rows = await db.query(table, orderBy: 'name COLLATE NOCASE, id');
    return rows.map(fromRow).toList();
  }
}
