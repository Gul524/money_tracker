import 'package:flutter/material.dart';

import '../../data/models/account.dart';
import '../../data/models/model_types.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/account_controller.dart';
import '../widgets/app_widgets.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final AccountController controller;

  @override
  void initState() {
    super.initState();
    controller = AccountController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _edit([Account? existing]) async {
    controller.clearError();
    var name = existing?.name ?? '';
    var type = existing?.type ?? AccountType.cash;
    final openingMinor = existing?.openingBalanceMinor ?? 0;
    var opening = openingMinor == 0
        ? ''
        : '${openingMinor < 0 ? '-' : ''}${amountInputText(openingMinor.abs())}';
    var archived = existing?.isArchived ?? false;

    await showAppSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) => SheetScaffold(
            title: existing == null ? 'New account' : 'Edit account',
            error: controller.error,
            busy: controller.busy,
            primaryLabel: 'Save',
            onPrimary: () async {
              final ok = await controller.save(
                id: existing?.id,
                name: name,
                type: type,
                openingBalance: opening.trim().isEmpty ? '0' : opening,
                isArchived: archived,
              );
              if (ok && sheetContext.mounted) Navigator.pop(sheetContext);
            },
            destructiveLabel: existing == null ? null : 'Delete account',
            onDestructive: () async {
              final confirmed = await confirmDelete(
                context,
                title: 'Delete ${existing!.name}?',
                message:
                    'Accounts with recorded activity can’t be deleted. '
                    'Archive them instead to hide them.',
              );
              if (confirmed &&
                  await controller.remove(existing.id!) &&
                  sheetContext.mounted) {
                Navigator.pop(sheetContext);
              }
            },
            children: [
              AppTextField(
                label: 'Account name',
                hint: 'e.g. Wallet, HBL Current',
                value: name,
                capitalization: TextCapitalization.words,
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: SpaceSize.large),
              SegmentedButton<AccountType>(
                segments: const [
                  ButtonSegment(
                    value: AccountType.cash,
                    label: Text('Cash'),
                    icon: Icon(Icons.payments_outlined),
                  ),
                  ButtonSegment(
                    value: AccountType.bank,
                    label: Text('Bank'),
                    icon: Icon(Icons.account_balance_outlined),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (v) => setSheetState(() => type = v.first),
              ),
              const SizedBox(height: SpaceSize.large),
              AppTextField(
                label: 'Starting balance',
                hint: '0',
                prefixText: '${currencySymbol(widget.services.currencyCode)} ',
                helper:
                    'How much was in this account when you started tracking.',
                value: opening,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (v) => opening = v,
              ),
              if (existing != null) ...[
                const SizedBox(height: SpaceSize.small),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Archive account'),
                  subtitle: const Text(
                    'Hide it when adding new entries. History is kept.',
                  ),
                  value: archived,
                  onChanged: (v) => setSheetState(() => archived = v),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(Account a) => AppTile(
    leading: IconBadge(
      a.type == AccountType.bank
          ? Icons.account_balance_outlined
          : Icons.payments_outlined,
    ),
    title: a.name,
    subtitle: a.type == AccountType.bank ? 'Bank' : 'Cash',
    trailing: AmountText(
      controller.balances[a.id] ?? 0,
      currency: widget.services.currencyCode,
      tone: a.isArchived
          ? AmountTone.muted
          : (controller.balances[a.id] ?? 0) < 0
          ? AmountTone.expense
          : AmountTone.neutral,
    ),
    onTap: () => _edit(a),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final active = controller.items.where((a) => !a.isArchived).toList();
      final archived = controller.items.where((a) => a.isArchived).toList();
      final total = active.fold<int>(
        0,
        (s, a) => s + (controller.balances[a.id] ?? 0),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Accounts')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add account'),
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
                icon: Icons.account_balance_wallet_outlined,
                title: 'No accounts yet',
                message: 'Add the places you keep money, like a wallet or a bank account.',
                actionLabel: 'Add account',
                onAction: () => _edit(),
              )
            else ...[
              GroupedCard(
                children: [
                  AppTile(
                    title: 'Total in active accounts',
                    trailing: AmountText(
                      total,
                      currency: widget.services.currencyCode,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SectionHeader('Active'),
              if (active.isEmpty)
                const InfoNote('All accounts are archived.')
              else
                GroupedCard(children: [for (final a in active) _tile(a)]),
              if (archived.isNotEmpty) ...[
                const SectionHeader('Archived'),
                GroupedCard(children: [for (final a in archived) _tile(a)]),
              ],
            ],
          ],
        ),
      );
    },
  );
}
