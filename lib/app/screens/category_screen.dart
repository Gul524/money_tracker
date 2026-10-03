import 'package:flutter/material.dart';

import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/category_controller.dart';
import '../widgets/app_widgets.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.services,
    this.isViewOnly = false,
  });
  final AppServices services;
  final bool isViewOnly;
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

  Future<void> _edit([Category? existing]) async {
    var name = existing?.name ?? '';
    var type = existing?.type ?? CategoryType.expense;
    int? parentId = existing?.parentId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          SpaceSize.extraLarge,
          SpaceSize.extraLarge,
          SpaceSize.extraLarge,
          MediaQuery.viewInsetsOf(sheetContext).bottom + SpaceSize.section,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => AnimatedBuilder(
            animation: controller,
            builder: (context, _) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'New category' : 'Edit category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: SpaceSize.header),
                  AppInput(
                    label: 'Name',
                    value: name,
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: SpaceSize.medium),
                  AppSelect<CategoryType>(
                    label: 'Used for',
                    value: type,
                    items: const {
                      CategoryType.expense: 'Expense',
                      CategoryType.income: 'Income',
                      CategoryType.both: 'Both',
                    },
                    onChanged: (v) {
                      if (v != null) setSheetState(() => type = v);
                    },
                  ),
                  const SizedBox(height: SpaceSize.medium),
                  AppSelect<int>(
                    label: 'Parent (optional)',
                    value: parentId,
                    allowClear: true,
                    items: {
                      for (final c in controller.items)
                        if (c.id != existing?.id) c.id!: controller.pathFor(c),
                    },
                    onChanged: (v) => setSheetState(() => parentId = v),
                  ),
                  const SizedBox(height: SpaceSize.compact),
                  AppError(controller.error),
                  FilledButton(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            if (await controller.save(
                                  id: existing?.id,
                                  name: name,
                                  type: type,
                                  parentId: parentId,
                                ) &&
                                sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                    child: const Text('Save category'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: widget.isViewOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Category'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SpaceSize.extraLarge,
          SpaceSize.medium,
          SpaceSize.extraLarge,
          SpaceSize.listBottom,
        ),
        children: [
          Text(
            'Organize transactions with categories at any depth.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpaceSize.header),
          if (controller.items.isEmpty)
            const AppEmpty('No categories yet')
          else
            AppPanel(
              child: Column(
                children: [
                  for (final c in controller.items)
                    AppListItem(
                      title: c.name,
                      subtitle: '${c.type.name} · ${controller.pathFor(c)}',
                      icon: Icons.category_outlined,
                      onTap: () => _edit(c),
                      isViewOnly: widget.isViewOnly,
                      trailing: widget.isViewOnly
                          ? null
                          : IconButton(
                              tooltip: 'Delete ${c.name}',
                              icon: const Icon(Icons.more_horiz),
                              onPressed: () => _showActions(c),
                            ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: SpaceSize.medium),
          AppError(controller.error),
        ],
      ),
    ),
  );

  void _showActions(Category c) => showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ListTile(
        leading: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Delete category'),
        onTap: () async {
          Navigator.of(context).pop();
          if (mounted && await confirmDelete(this.context, c.name)) {
            await controller.remove(c.id!);
          }
        },
      ),
    ),
  );
}
