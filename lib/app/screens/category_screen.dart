import 'package:flutter/material.dart';

import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/category_controller.dart';
import '../widgets/app_widgets.dart';

const _typeLabels = {
  CategoryType.expense: 'Expense',
  CategoryType.income: 'Income',
  CategoryType.both: 'Both',
};

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late final CategoryController controller;

  @override
  void initState() {
    super.initState();
    controller = CategoryController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Categories of [type] in tree order, each with its depth.
  List<(Category, int)> _tree(CategoryType type) {
    final items = controller.items.where((c) => c.type == type).toList()
      ..sort(
        (a, b) => controller
            .pathFor(a)
            .toLowerCase()
            .compareTo(controller.pathFor(b).toLowerCase()),
      );
    return [
      for (final c in items)
        (c, ' / '.allMatches(controller.pathFor(c)).length),
    ];
  }

  Future<void> _edit([Category? existing]) async {
    controller.clearError();
    var name = existing?.name ?? '';
    var type = existing?.type ?? CategoryType.expense;
    int? parentId = existing?.parentId;

    await showAppSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final parent = controller.items
                .where((c) => c.id == parentId)
                .firstOrNull;
            return SheetScaffold(
              title: existing == null ? 'New category' : 'Edit category',
              error: controller.error,
              busy: controller.busy,
              primaryLabel: 'Save',
              onPrimary: () async {
                final ok = await controller.save(
                  id: existing?.id,
                  name: name,
                  type: type,
                  parentId: parentId,
                );
                if (ok && sheetContext.mounted) Navigator.pop(sheetContext);
              },
              destructiveLabel: existing == null ? null : 'Delete category',
              onDestructive: () async {
                if (await confirmDelete(
                      context,
                      title: 'Delete ${existing!.name}?',
                      message:
                          'Categories that are used by entries or have '
                          'subcategories can’t be deleted.',
                    ) &&
                    await controller.remove(existing.id!) &&
                    sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }
              },
              children: [
                AppTextField(
                  label: 'Name',
                  hint: 'e.g. Groceries, Rent, Freelance',
                  value: name,
                  capitalization: TextCapitalization.words,
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: SpaceSize.large),
                Text('Used for', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: SpaceSize.small),
                SegmentedButton<CategoryType>(
                  showSelectedIcon: false,
                  segments: [
                    for (final e in _typeLabels.entries)
                      ButtonSegment(value: e.key, label: Text(e.value)),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) =>
                      setSheetState(() => type = v.first),
                ),
                const SizedBox(height: SpaceSize.large),
                GroupedCard(
                  children: [
                    FormRow(
                      icon: Icons.account_tree_outlined,
                      label: 'Inside',
                      value: parent == null ? null : controller.pathFor(parent),
                      placeholder: 'Top level',
                      onTap: () async {
                        final picked = await showPickerSheet<int>(
                          context,
                          title: 'Put inside',
                          selected: parentId ?? -1,
                          options: [
                            const PickerOption(
                              value: -1,
                              title: 'Top level',
                              subtitle: 'Not inside another category',
                            ),
                            for (final c in controller.items)
                              if (c.id != existing?.id)
                                PickerOption(
                                  value: c.id!,
                                  title: controller.pathFor(c),
                                  icon: categoryIcon(
                                    c.name,
                                    income: c.type == CategoryType.income,
                                  ),
                                ),
                          ],
                        );
                        if (picked != null) {
                          setSheetState(
                            () => parentId = picked == -1 ? null : picked,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: SpaceSize.small),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String title, CategoryType type) {
    final tree = _tree(type);
    if (tree.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title),
        GroupedCard(
          children: [
            for (final (c, depth) in tree)
              Padding(
                padding: EdgeInsets.only(left: depth * 24.0),
                child: AppTile(
                  leading: IconBadge(
                    categoryIcon(c.name, income: type == CategoryType.income),
                    size: depth == 0 ? 40 : 32,
                  ),
                  title: c.name,
                  onTap: () => _edit(c),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SpaceSize.gutter,
          0,
          SpaceSize.gutter,
          SpaceSize.fabClearance,
        ),
        children: [
          ErrorBanner(controller.error),
          if (controller.items.isEmpty && !controller.busy)
            EmptyState(
              icon: Icons.sell_outlined,
              title: 'No categories yet',
              message: 'Categories group your spending and income in reports.',
              actionLabel: 'Add category',
              onAction: () => _edit(),
            )
          else ...[
            const InfoNote(
              'Tap a category to rename it or move it inside another one.',
            ),
            _section('Expenses', CategoryType.expense),
            _section('Income', CategoryType.income),
            _section('Used for both', CategoryType.both),
          ],
        ],
      ),
    ),
  );
}
