import 'package:flutter/material.dart';

import '../../data/models/asset.dart';
import '../../data/models/model_types.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/asset_controller.dart';
import '../controllers/money_amount.dart';
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

  Future<int?> _pickWallet(int? selected) => showPickerSheet<int>(
    context,
    title: 'Paid from',
    selected: selected,
    emptyMessage: 'Add an account in Settings › Accounts first.',
    options: [
      for (final a in controller.accounts)
        if (!a.isArchived || a.id == selected)
          PickerOption(
            value: a.id!,
            title: a.name,
            icon: a.type == AccountType.bank
                ? Icons.account_balance_outlined
                : Icons.payments_outlined,
          ),
    ],
  );

  Future<int?> _pickCategory(int? selected) => showPickerSheet<int>(
    context,
    title: 'Category',
    selected: selected,
    emptyMessage: 'No expense categories yet.',
    options: [
      for (final c in controller.categories)
        PickerOption(
          value: c.id!,
          title: c.name,
          subtitle: c.parentId == null
              ? null
              : controller.pathFor(c).replaceFirst(RegExp(r' / [^/]+$'), ''),
          leading: CategoryBadge(
            name: c.name,
            iconKey: c.icon,
            colorHex: c.color,
          ),
        ),
    ],
  );

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
    final linked = existing == null ? null : controller.purchaseOf(existing);
    final given = existing == null ? null : controller.givenIn(existing);
    var source = controller.sourceOf(existing);
    int? accountId = linked?.accountId ?? controller.defaultAccount;
    int? categoryId = linked?.categoryId;
    var party = linked?.party ?? '';
    final currency = widget.services.currencyCode;
    final symbol = '${currencySymbol(currency)} ';

    String sourceNote() {
      final price = MoneyAmount.tryParse(purchase);
      final amount = price == null ? 'The price paid' : money(price, currency);
      return switch (source) {
        AssetSource.owned =>
          'Nothing changes in your wallets. Use this for things you already '
              'had or were given.',
        AssetSource.paid =>
          '$amount leaves ${controller.accountName(accountId) ?? 'the wallet'} '
              'as an expense.',
        AssetSource.owed =>
          '$amount is added to Money owed. It leaves a wallet when you mark '
              'it as paid.',
      };
    }

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
                source: source,
                accountId: accountId,
                categoryId: categoryId,
                party: party,
              );
              if (ok && sheetContext.mounted) Navigator.pop(sheetContext);
            },
            destructiveLabel: existing == null ? null : 'Delete asset',
            onDestructive: () async {
              if (await confirmDelete(
                    context,
                    title: 'Delete ${existing!.name}?',
                    message: linked == null && given == null
                        ? 'This can’t be undone.'
                        : 'Entries linked to it stay in your history. '
                              'This can’t be undone.',
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
                      onChanged: (v) => setSheetState(() => purchase = v),
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
              const SizedBox(height: SpaceSize.large),
              Text(
                'How did you get it?',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: SpaceSize.small),
              SegmentedButton<AssetSource>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: AssetSource.owned,
                    label: Text('Had it'),
                  ),
                  ButtonSegment(value: AssetSource.paid, label: Text('Paid')),
                  ButtonSegment(
                    value: AssetSource.owed,
                    label: Text('On credit'),
                  ),
                ],
                selected: {source},
                // A linked purchase can't change kind; edit its entry instead.
                onSelectionChanged: linked != null
                    ? null
                    : (v) => setSheetState(() {
                        source = v.first;
                        categoryId ??= controller.defaultCategory(source);
                      }),
              ),
              if (source != AssetSource.owned) ...[
                const SizedBox(height: SpaceSize.medium),
                GroupedCard(
                  dividerIndent: 56,
                  children: [
                    if (source == AssetSource.paid)
                      FormRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Paid from',
                        value: controller.accountName(accountId),
                        onTap: () async {
                          final picked = await _pickWallet(accountId);
                          if (picked != null) {
                            setSheetState(() => accountId = picked);
                          }
                        },
                      )
                    else
                      FormTextRow(
                        icon: Icons.person_outline_rounded,
                        hint: 'Who do you owe?',
                        value: party,
                        onChanged: (v) => party = v,
                        capitalization: TextCapitalization.words,
                      ),
                    FormRow(
                      icon: Icons.sell_outlined,
                      label: 'Category',
                      value: controller.category(categoryId)?.name,
                      onTap: () async {
                        final picked = await _pickCategory(categoryId);
                        if (picked != null) {
                          setSheetState(() => categoryId = picked);
                        }
                      },
                    ),
                  ],
                ),
              ],
              InfoNote(sourceNote()),
              if (given != null)
                InfoNote(
                  'Given to ${(given.party ?? '').trim().isEmpty ? 'someone' : given.party!.trim()} '
                  'on ${formatDate(given.occurredAt)}. It’s no longer counted '
                  'in your assets.',
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(Asset a, String currency) {
    final purchase = controller.purchaseOf(a);
    final given = controller.givenIn(a);
    final parts = [
      'Paid ${money(a.purchaseAmountMinor, currency)}',
      formatDate(a.acquiredOn),
      if (given != null)
        'Given to ${(given.party ?? '').trim().isEmpty ? 'someone' : given.party!.trim()}'
      else if (purchase?.type == TransactionType.expense)
        'from ${controller.accountName(purchase!.accountId) ?? 'a wallet'}'
      else if (purchase != null)
        purchase.oweStatus == OweStatus.pending
            ? 'still owed${(purchase.party ?? '').trim().isEmpty ? '' : ' to ${purchase.party!.trim()}'}'
            : 'paid off',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final currency = widget.services.currencyCode;
      final owned = controller.owned;
      final givenAway = controller.givenAway;
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
                      controller.ownedValueMinor,
                      currency: currency,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              if (owned.isNotEmpty) ...[
                const SectionHeader('Your assets'),
                GroupedCard(
                  children: [
                    for (final a in owned)
                      _AssetTile(
                        asset: a,
                        currency: currency,
                        subtitle: _subtitle(a, currency),
                        onTap: () => _edit(a),
                      ),
                  ],
                ),
              ],
              if (givenAway.isNotEmpty) ...[
                const SectionHeader('Given away'),
                GroupedCard(
                  children: [
                    for (final a in givenAway)
                      _AssetTile(
                        asset: a,
                        currency: currency,
                        subtitle: _subtitle(a, currency),
                        muted: true,
                        onTap: () => _edit(a),
                      ),
                  ],
                ),
              ],
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
    required this.subtitle,
    required this.onTap,
    this.muted = false,
  });
  final Asset asset;
  final String currency;
  final String subtitle;
  final VoidCallback onTap;

  /// Given away: shown for reference, not counted.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final change = asset.currentValueMinor - asset.purchaseAmountMinor;
    return AppTile(
      leading: IconBadge(
        muted ? Icons.redeem_outlined : Icons.inventory_2_outlined,
      ),
      title: asset.name,
      subtitle: subtitle,
      onTap: onTap,
      showChevron: false,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          AmountText(
            asset.currentValueMinor,
            currency: currency,
            tone: muted ? AmountTone.muted : AmountTone.neutral,
          ),
          if (change != 0 && !muted)
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
