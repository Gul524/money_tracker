import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/account_controller.dart';
import '../controllers/history_controller.dart';
import '../date_range.dart';
import '../widgets/app_widgets.dart';
import 'account_screen.dart';
import 'activity_list.dart';
import 'history_screen.dart';

/// One account (wallet): its balance, this month's money in and out, and
/// everything that touched it.
class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({
    super.key,
    required this.services,
    required this.accountId,
  });
  final AppServices services;
  final int accountId;

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late final AccountController accounts;
  late final HistoryController history;

  @override
  void initState() {
    super.initState();
    accounts = AccountController(widget.services);
    history = HistoryController(widget.services, accountId: widget.accountId);
  }

  @override
  void dispose() {
    accounts.dispose();
    history.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    final account = accounts.items
        .where((a) => a.id == widget.accountId)
        .firstOrNull;
    if (account == null) return;
    final deleted = await showAccountEditor(
      context,
      services: widget.services,
      controller: accounts,
      existing: account,
    );
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([accounts, history]),
    builder: (context, _) {
      final theme = Theme.of(context);
      final currency = widget.services.currencyCode;
      final account = accounts.items
          .where((a) => a.id == widget.accountId)
          .firstOrNull;
      final items = history.visibleItems;
      final month = DateRange.month(DateTime.now());
      var monthIn = 0;
      var monthOut = 0;
      for (final item in items.where((i) => month.contains(i.date))) {
        final effect = item.effectOn(widget.accountId);
        if (effect > 0) {
          monthIn += effect;
        } else {
          monthOut -= effect;
        }
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(account?.name ?? 'Account'),
          actions: [
            if (account != null)
              IconButton(
                tooltip: 'Edit account',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _edit,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.gutter,
            SpaceSize.small,
            SpaceSize.gutter,
            SpaceSize.huge,
          ),
          children: [
            ErrorBanner(accounts.error ?? history.error),
            if (account == null && (accounts.busy || history.busy))
              const Padding(
                padding: EdgeInsets.all(SpaceSize.huge),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (account != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(CardSize.heroPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              account.type == AccountType.bank
                                  ? 'Bank account balance'
                                  : 'Cash balance',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          if (account.isArchived)
                            StatusPill(
                              'Archived',
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      const SizedBox(height: SpaceSize.extraSmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AmountText(
                          accounts.balances[account.id] ?? 0,
                          currency: currency,
                          tone: (accounts.balances[account.id] ?? 0) < 0
                              ? AmountTone.expense
                              : AmountTone.neutral,
                          style: theme.textTheme.displaySmall,
                        ),
                      ),
                      const SizedBox(height: SpaceSize.small),
                      Text(
                        'Starting balance '
                        '${money(account.openingBalanceMinor, currency)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeader('This month · ${formatMonthYear(month.start)}'),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Money in',
                      amount: monthIn,
                      currency: currency,
                      color: AppColors.of(context).income,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  const SizedBox(width: SpaceSize.medium),
                  Expanded(
                    child: _Stat(
                      label: 'Money out',
                      amount: monthOut,
                      currency: currency,
                      color: theme.colorScheme.onSurface,
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
              SectionHeader(
                'Activity',
                actionLabel: items.isEmpty ? null : 'Search',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HistoryScreen(
                      services: widget.services,
                      title: account.name,
                      accountId: account.id,
                    ),
                  ),
                ),
              ),
              if (items.isEmpty && !history.busy)
                const Card(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nothing here yet',
                    message:
                        'Income, expenses, tax and transfers for this account '
                        'will show here.',
                  ),
                )
              else
                ActivityDayGroups(
                  items: items,
                  services: widget.services,
                  accountId: widget.accountId,
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
  });
  final String label;
  final int amount;
  final String currency;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CardSize.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: IconSize.small, color: color),
                const SizedBox(width: SpaceSize.extraSmall),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: SpaceSize.small),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(amount, currency),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
