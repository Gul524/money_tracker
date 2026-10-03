import 'package:flutter/material.dart';

import '../../data/models/asset.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/asset_controller.dart';
import '../widgets/app_widgets.dart';

class AssetScreen extends StatefulWidget {
  const AssetScreen({
    super.key,
    required this.services,
    this.isViewOnly = false,
  });
  final AppServices services;
  final bool isViewOnly;
  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen> {
  late final AssetController controller;
  @override
  void initState() {
    super.initState();
    controller = AssetController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _edit([Asset? existing]) async {
    var name = existing?.name ?? '';
    var purchase = existing == null
        ? ''
        : (existing.purchaseAmountMinor / 100).toStringAsFixed(2);
    var current = existing == null
        ? ''
        : (existing.currentValueMinor / 100).toStringAsFixed(2);
    var date = existing?.acquiredOn ?? DateTime.now();
    var notes = existing?.notes ?? '';
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
                    existing == null ? 'New asset' : 'Edit asset',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: SpaceSize.header),
                  AppInput(
                    label: 'Asset name',
                    value: name,
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: SpaceSize.medium),
                  AppInput(
                    label: 'Purchase amount (${widget.services.currencyCode})',
                    value: purchase,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => purchase = v,
                  ),
                  const SizedBox(height: SpaceSize.medium),
                  AppInput(
                    label: 'Current value (${widget.services.currencyCode})',
                    value: current,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => current = v,
                  ),
                  AppDateField(
                    label: 'Acquired on',
                    value: date,
                    onChanged: (v) {
                      if (v != null) setSheetState(() => date = v);
                    },
                  ),
                  AppInput(
                    label: 'Notes',
                    value: notes,
                    onChanged: (v) => notes = v,
                  ),
                  AppError(controller.error),
                  FilledButton(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            if (await controller.save(
                                  id: existing?.id,
                                  name: name,
                                  purchaseAmount: purchase,
                                  currentValue: current,
                                  acquiredOn: date,
                                  notes: notes,
                                  purchaseTransactionId:
                                      existing?.purchaseTransactionId,
                                ) &&
                                sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                    child: const Text('Save asset'),
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
    builder: (context, _) => ListView(
      padding: const EdgeInsets.only(bottom: SpaceSize.listBottom),
      children: [
        PageHeader(
          title: 'Assets',
          subtitle: 'Things you own and hold',
          actions: widget.isViewOnly
              ? []
              : [
                  IconButton(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpaceSize.extraLarge),
          child: controller.items.isEmpty
              ? const AppEmpty('Add an asset to track its value')
              : AppPanel(
                  child: Column(
                    children: [
                      for (final a in controller.items)
                        AppListItem(
                          title: a.name,
                          subtitle:
                              'Bought for ${money(a.purchaseAmountMinor, widget.services.currencyCode)}',
                          icon: Icons.inventory_2_outlined,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                money(
                                  a.currentValueMinor,
                                  widget.services.currencyCode,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (!widget.isViewOnly)
                                PopupMenuButton<String>(
                                  tooltip: 'Asset actions',
                                  onSelected: (action) async {
                                    if (action == 'delete' &&
                                        await confirmDelete(context, a.name)) {
                                      await controller.remove(a.id!);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete asset'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          onTap: () => _edit(a),
                          isViewOnly: widget.isViewOnly,
                        ),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(SpaceSize.extraLarge),
          child: AppError(controller.error),
        ),
      ],
    ),
  );
}
