import 'package:flutter/material.dart';

import '../../data/models/asset.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/asset_controller.dart';
import '../widgets/app_widgets.dart';

class AssetScreen extends StatefulWidget {
  const AssetScreen({super.key, required this.services});
  final AppServices services;
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
    controller.clearError();
    var name = existing?.name ?? '';
    var purchase = existing == null
        ? ''
        : amountInputText(existing.purchaseAmountMinor);
    var current = existing == null
        ? ''
        : amountInputText(existing.currentValueMinor);
    var date = existing?.acquiredOn ?? DateTime.now();
    var notes = existing?.notes ?? '';
    final symbol = '${currencySymbol(widget.services.currencyCode)} ';

    await showAppSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) => SheetScaffold(
            title: existing == null ? 'New asset' : 'Edit asset',
            subtitle: existing == null
                ? 'Track things you own, like gold, a car or property.'
                : null,
            error: controller.error,
            busy: controller.busy,
            primaryLabel: 'Save',
            onPrimary: () async {
              final paid = purchase.trim().isEmpty ? '0' : purchase;
              final ok = await controller.save(
                id: existing?.id,
                name: name,
                purchaseAmount: paid,
                // Blank "worth today" means it's still worth what was paid.
                currentValue: current.trim().isEmpty ? paid : current,
                acquiredOn: date,
                notes: notes.trim().isEmpty ? null : notes.trim(),
                purchaseTransactionId: existing?.purchaseTransactionId,
              );
              if (ok && sheetContext.mounted) Navigator.pop(sheetContext);
            },
            destructiveLabel: existing == null ? null : 'Delete asset',
            onDestructive: () async {
              if (await confirmDelete(
                    context,
                    title: 'Delete ${existing!.name}?',
                  ) &&
                  await controller.remove(existing.id!) &&
                  sheetContext.mounted) {
                Navigator.pop(sheetContext);
              }
            },
            children: [
              AppTextField(
                label: 'Name',
                hint: 'e.g. Gold ring, Honda Civic',
                value: name,
                capitalization: TextCapitalization.words,
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: SpaceSize.medium),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Price paid',
                      prefixText: symbol,
                      value: purchase,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) => purchase = v,
                    ),
                  ),
                  const SizedBox(width: SpaceSize.medium),
                  Expanded(
                    child: AppTextField(
                      label: 'Worth today',
                      prefixText: symbol,
                      value: current,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) => current = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpaceSize.medium),
              GroupedCard(
                dividerIndent: 56,
                children: [
                  FormRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Bought on',
                    value: formatDate(date),
                    onTap: () async {
                      final d = await pickDate(context, date);
                      if (d != null) setSheetState(() => date = d);
                    },
                  ),
                  FormTextRow(
                    icon: Icons.notes_rounded,
                    hint: 'Notes (optional)',
                    value: notes,
                    onChanged: (v) => notes = v,
                  ),
                ],
              ),
              const InfoNote(
                'Assets don’t change your account balances. Record the '
                'purchase as an expense if the money came from an account.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final currency = widget.services.currencyCode;
      final total = controller.items.fold<int>(
        0,
        (s, a) => s + a.currentValueMinor,
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Assets')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add asset'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.gutter,
            SpaceSize.small,
            SpaceSize.gutter,
            SpaceSize.fabClearance,
          ),
          children: [
            ErrorBanner(controller.error),
            if (controller.items.isEmpty && !controller.busy)
              EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No assets yet',
                message:
                    'Add valuable things you own to see your full net worth.',
                actionLabel: 'Add asset',
                onAction: () => _edit(),
              )
            else ...[
              GroupedCard(
                children: [
                  AppTile(
                    title: 'Total value',
                    trailing: AmountText(
                      total,
                      currency: currency,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SectionHeader('Your assets'),
              GroupedCard(
                children: [
                  for (final a in controller.items)
                    _AssetTile(
                      asset: a,
                      currency: currency,
                      onTap: () => _edit(a),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.currency,
    required this.onTap,
  });
  final Asset asset;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final change = asset.currentValueMinor - asset.purchaseAmountMinor;
    return AppTile(
      leading: const IconBadge(Icons.inventory_2_outlined),
      title: asset.name,
      subtitle:
          'Paid ${money(asset.purchaseAmountMinor, currency)} · ${formatDate(asset.acquiredOn)}',
      onTap: onTap,
      showChevron: false,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          AmountText(asset.currentValueMinor, currency: currency),
          if (change != 0)
            AmountText(
              change,
              currency: currency,
              signed: true,
              tone: change > 0 ? AmountTone.income : AmountTone.expense,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
