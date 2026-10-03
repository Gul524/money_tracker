import 'package:flutter/material.dart';

import '../../data/models/account.dart';
import '../../data/models/model_types.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/account_controller.dart';
import '../widgets/app_widgets.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.services,
    this.isViewOnly = false,
  });
  final AppServices services;
  final bool isViewOnly;
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
    var name = existing?.name ?? '';
    var type = existing?.type ?? AccountType.cash;
    var opening = existing == null
        ? '0.00'
        : (existing.openingBalanceMinor / 100).toStringAsFixed(2);
    var archived = existing?.isArchived ?? false;
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
                    existing == null ? 'New account' : 'Edit account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: SpaceSize.header),
                  AppInput(
                    label: 'Name',
                    value: name,
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: SpaceSize.medium),
                  AppSelect<AccountType>(
                    label: 'Account type',
                    value: type,
                    items: const {
                      AccountType.cash: 'Cash',
                      AccountType.bank: 'Bank',
                    },
                    onChanged: (v) {
                      if (v != null) setSheetState(() => type = v);
                    },
                  ),
                  const SizedBox(height: SpaceSize.medium),
                  AppInput(
                    label: 'Opening balance (${widget.services.currencyCode})',
                    value: opening,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => opening = v,
                  ),
                  if (existing != null)
                    SwitchListTile(
                      title: const Text('Archived'),
                      value: archived,
                      onChanged: (v) => setSheetState(() => archived = v),
                    ),
                  AppError(controller.error),
                  FilledButton(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            if (await controller.save(
                                  id: existing?.id,
                                  name: name,
                                  type: type,
                                  openingBalance: opening,
                                  isArchived: archived,
                                ) &&
                                sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                    child: const Text('Save account'),
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
          title: 'Accounts',
          subtitle: 'Your cash and financial accounts',
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
              ? const AppEmpty('Add your first account')
              : AppPanel(
                  child: Column(
                    children: [
                      for (final a in controller.items)
                        AppListItem(
                          title: a.name,
                          subtitle:
                              '${a.type.name}${a.isArchived ? ' · Archived' : ''}',
                          icon: Icons.account_balance_wallet_outlined,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                money(
                                  controller.balances[a.id] ?? 0,
                                  widget.services.currencyCode,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (!widget.isViewOnly)
                                PopupMenuButton<String>(
                                  tooltip: 'Account actions',
                                  onSelected: (action) async {
                                    if (action == 'delete' &&
                                        await confirmDelete(context, a.name)) {
                                      await controller.remove(a.id!);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete account'),
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
