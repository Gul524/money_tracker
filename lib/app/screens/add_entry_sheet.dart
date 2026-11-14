import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/transaction_controller.dart';
import '../widgets/app_widgets.dart';
import 'transaction_screen.dart';
import 'transfer_screen.dart';

enum _AddChoice { expense, income, transfer, oweIn, oweOut, tax }

/// Shows the "Add" menu, opens the chosen form, and confirms with a snackbar
/// when something was saved.
Future<void> openAddFlow(BuildContext context, AppServices services) async {
  final choice = await showModalBottomSheet<_AddChoice>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _AddEntrySheet(),
  );
  if (choice == null || !context.mounted) return;

  final Widget page = switch (choice) {
    _AddChoice.transfer => TransferScreen(services: services),
    _AddChoice.expense => TransactionScreen(
      services: services,
      initialKind: EntryKind.expense,
    ),
    _AddChoice.income => TransactionScreen(
      services: services,
      initialKind: EntryKind.income,
    ),
    _AddChoice.oweIn => TransactionScreen(
      services: services,
      initialKind: EntryKind.oweIn,
    ),
    _AddChoice.oweOut => TransactionScreen(
      services: services,
      initialKind: EntryKind.oweOut,
    ),
    _AddChoice.tax => TransactionScreen(
      services: services,
      initialKind: EntryKind.tax,
    ),
  };
  final saved = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => page));
  if (saved == true && context.mounted) showMessage(context, 'Saved');
}

class _AddEntrySheet extends StatelessWidget {
  const _AddEntrySheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    void pick(_AddChoice c) => Navigator.of(context).pop(c);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        SpaceSize.gutter,
        0,
        SpaceSize.gutter,
        SpaceSize.extraLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What would you like to add?',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: SpaceSize.large),
          // The two most frequent actions get the largest targets.
          Row(
            children: [
              Expanded(
                child: _BigChoice(
                  icon: Icons.north_east_rounded,
                  label: 'Expense',
                  caption: 'Money you spent',
                  color: colors.expense,
                  background: colors.expenseContainer,
                  onTap: () => pick(_AddChoice.expense),
                ),
              ),
              const SizedBox(width: SpaceSize.medium),
              Expanded(
                child: _BigChoice(
                  icon: Icons.south_west_rounded,
                  label: 'Income',
                  caption: 'Money you received',
                  color: colors.income,
                  background: colors.incomeContainer,
                  onTap: () => pick(_AddChoice.income),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpaceSize.medium),
          GroupedCard(
            children: [
              AppTile(
                leading: IconBadge(
                  Icons.swap_horiz_rounded,
                  color: colors.transfer,
                  background: colors.transferContainer,
                ),
                title: 'Transfer',
                subtitle: 'Move money between your own accounts',
                onTap: () => pick(_AddChoice.transfer),
              ),
              AppTile(
                leading: IconBadge(
                  Icons.call_received_rounded,
                  color: colors.warning,
                  background: colors.warningContainer,
                ),
                title: 'Someone owes me',
                subtitle: 'Money you lent and expect back',
                onTap: () => pick(_AddChoice.oweIn),
              ),
              AppTile(
                leading: IconBadge(
                  Icons.call_made_rounded,
                  color: colors.warning,
                  background: colors.warningContainer,
                ),
                title: 'I owe someone',
                subtitle: 'Money you borrowed and need to repay',
                onTap: () => pick(_AddChoice.oweOut),
              ),
              AppTile(
                leading: const IconBadge(Icons.account_balance_outlined),
                title: 'Tax payment',
                subtitle: 'Tax you paid from an account',
                onTap: () => pick(_AddChoice.tax),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.background,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CardSize.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon, color: color, background: background),
              const SizedBox(height: SpaceSize.medium),
              Text(label, style: theme.textTheme.titleMedium),
              const SizedBox(height: SpaceSize.tiny),
              Text(caption, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
