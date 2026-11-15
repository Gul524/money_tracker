import 'package:flutter/material.dart';

import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/model_types.dart';
import '../../data/services/defaults_service.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/defaults_controller.dart';
import '../widgets/app_widgets.dart';

const _none = -1;

/// Settings › Defaults. What is filled in automatically when adding entries.
class DefaultsScreen extends StatefulWidget {
  const DefaultsScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<DefaultsScreen> createState() => _DefaultsScreenState();
}

class _DefaultsScreenState extends State<DefaultsScreen> {
  late final DefaultsController controller;

  @override
  void initState() {
    super.initState();
    controller = DefaultsController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  IconData _walletIcon(Account a) => a.type == AccountType.bank
      ? Icons.account_balance_outlined
      : Icons.payments_outlined;

  Future<int?> _pickWallet(String title, Account? current) =>
      showPickerSheet<int>(
        context,
        title: title,
        selected: current?.id ?? _none,
        options: [
          const PickerOption(
            value: _none,
            title: 'No default',
            icon: Icons.block_rounded,
          ),
          for (final a in controller.accounts)
            PickerOption(value: a.id!, title: a.name, icon: _walletIcon(a)),
        ],
      );

  Future<void> _pickKindWallet(String kind, String title) async {
    final picked = await _pickWallet(title, controller.accountFor(kind));
    if (picked != null) {
      await controller.setAccount(kind, picked == _none ? null : picked);
    }
  }

  Future<void> _pickKindCategory(String kind, String title) async {
    final income = kind == DefaultKind.income || kind == DefaultKind.oweIn;
    final picked = await showPickerSheet<int>(
      context,
      title: title,
      selected: controller.categoryFor(kind)?.id ?? _none,
      emptyMessage: 'Add a category in Settings › Categories first.',
      options: [
        const PickerOption(
          value: _none,
          title: 'No default',
          icon: Icons.block_rounded,
        ),
        for (final c in controller.categoriesFor(kind))
          PickerOption(
            value: c.id!,
            title: c.name,
            icon: categoryIcon(c.name, income: income),
            indent: ' / '.allMatches(controller.pathFor(c)).length,
          ),
      ],
    );
    if (picked != null) {
      await controller.setCategory(kind, picked == _none ? null : picked);
    }
  }

  Future<void> _pickCategoryWallet(Category c) async {
    final picked = await _pickWallet(
      'Wallet for ${c.name}',
      controller.accountForCategory(c.id!),
    );
    if (picked != null) {
      await controller.setCategoryAccount(
        c.id!,
        picked == _none ? null : picked,
      );
    }
  }

  Widget _kindSection(String label, String kind, {bool withCategory = true}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(label),
          GroupedCard(
            dividerIndent: 56,
            children: [
              if (withCategory)
                FormRow(
                  icon: Icons.sell_outlined,
                  label: 'Category',
                  value: controller.categoryFor(kind)?.name,
                  placeholder: 'None',
                  onTap: () => _pickKindCategory(kind, '$label category'),
                  onClear: () => controller.setCategory(kind, null),
                ),
              FormRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Wallet',
                value: controller.accountFor(kind)?.name,
                placeholder: 'None',
                onTap: () => _pickKindWallet(kind, '$label wallet'),
                onClear: () => controller.setAccount(kind, null),
              ),
            ],
          ),
        ],
      );

  Widget _categoryWallets(String label, List<Category> items, bool income) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(label),
        GroupedCard(
          children: [
            for (final c in items)
              Padding(
                padding: EdgeInsets.only(
                  left: 24.0 * ' / '.allMatches(controller.pathFor(c)).length,
                ),
                child: AppTile(
                  leading: IconBadge(categoryIcon(c.name, income: income)),
                  title: c.name,
                  trailing: Text(
                    controller.accountForCategory(c.id!)?.name ?? 'None',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: controller.accountForCategory(c.id!) == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => _pickCategoryWallet(c),
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
    builder: (context, _) {
      final sorted = controller.sortedCategories;
      List<Category> ofType(CategoryType t) =>
          sorted.where((c) => c.type == t).toList();
      return Scaffold(
        appBar: AppBar(title: const Text('Defaults')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.gutter,
            0,
            SpaceSize.gutter,
            SpaceSize.huge,
          ),
          children: [
            const InfoNote(
              'These are filled in for you when you add something. You can '
              'still change them on each entry. A category’s wallet is used '
              'before the entry type’s wallet.',
            ),
            ErrorBanner(controller.error),
            _kindSection('Expense', DefaultKind.expense),
            _kindSection('Income', DefaultKind.income),
            _kindSection('Someone owes me', DefaultKind.oweIn),
            _kindSection('I owe someone', DefaultKind.oweOut),
            _kindSection('Tax payment', DefaultKind.tax, withCategory: false),
            const SectionHeader('Transfer'),
            GroupedCard(
              dividerIndent: 56,
              children: [
                FormRow(
                  icon: Icons.logout_rounded,
                  label: 'From',
                  value: controller.accountFor(DefaultKind.transferFrom)?.name,
                  placeholder: 'None',
                  onTap: () => _pickKindWallet(
                    DefaultKind.transferFrom,
                    'Move money from',
                  ),
                  onClear: () =>
                      controller.setAccount(DefaultKind.transferFrom, null),
                ),
                FormRow(
                  icon: Icons.login_rounded,
                  label: 'To',
                  value: controller.accountFor(DefaultKind.transferTo)?.name,
                  placeholder: 'None',
                  onTap: () =>
                      _pickKindWallet(DefaultKind.transferTo, 'Move money to'),
                  onClear: () =>
                      controller.setAccount(DefaultKind.transferTo, null),
                ),
              ],
            ),
            _categoryWallets(
              'Wallet for expense categories',
              ofType(CategoryType.expense),
              false,
            ),
            _categoryWallets(
              'Wallet for income categories',
              ofType(CategoryType.income),
              true,
            ),
            _categoryWallets(
              'Wallet for shared categories',
              ofType(CategoryType.both),
              false,
            ),
          ],
        ),
      );
    },
  );
}
