import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import 'base_controller.dart';
import 'category_path.dart';

class CategoryController extends BaseController {
  CategoryController(super.services) {
    refresh();
  }
  List<Category> items = [];

  String pathFor(Category category) => categoryPath(category, items);

  @override
  void refresh() {
    run(() async {
      items = await services.categories.getAll();
    });
  }

  Future<bool> save({
    int? id,
    required String name,
    required CategoryType type,
    int? parentId,
  }) async {
    final result = await run(() async {
      final value = Category(
        id: id,
        name: name,
        type: type,
        parentId: parentId,
      );
      if (id == null) {
        await services.categories.create(value);
      } else {
        await services.categories.update(value);
      }
      services.changed();
      return true;
    });
    return result == true;
  }

  Future<bool> remove(int id) async =>
      await run(() async {
        await services.categories.delete(id);
        services.changed();
        return true;
      }) ==
      true;
}
