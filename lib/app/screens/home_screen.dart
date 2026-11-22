import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../../data/services/dashboard_service.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/home_controller.dart';
import '../widgets/app_widgets.dart';
import 'account_screen.dart';
import 'add_entry_sheet.dart';
import 'asset_screen.dart';
import 'owe_screen.dart';
import 'account_detail_screen.dart';
import 'activity_list.dart';

/// Dashboard. Content is ordered by what people check most: total balance,
/// this month's flow, money owed, accounts, then recent activity.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services, this.onShowHistory});
  final AppServices services;
  final VoidCallback? onShowHistory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController controller;

  @override
  void initState() {
    super.initState();
    controller = HomeController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final summary = controller.summary;
      final theme = Theme.of(context);
      final currency = widget.services.currencyCode;
      final services = widget.services;

      return Scaffold(
        body: RefreshIndicator(
          onRefresh: controller.load,
          child: CustomScrollView(
            slivers: [
              const SliverAppBar.medium(title: Text('Overview')),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  SpaceSize.gutter,
                  0,
                  SpaceSize.gutter,
                  SpaceSize.fabClearance,
                ),
                sliver: SliverList.list(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: SpaceSize.extraSmall,
                        bottom: SpaceSize.large,
                      ),
                      child: Text(
                        formatLongDate(DateTime.now()),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (controller.busy && summary == null)
                      const Padding(
                        padding: EdgeInsets.all(SpaceSize.huge),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ErrorBanner(controller.error),
                    if (summary != null) ...[
                      _BalanceCard(
                        summary: summary,
                        currency: currency,
                        onTap: () => _open(AccountScreen(services: services)),
                      ),
                      if (controller.recentActivity.isEmpty) ...[
                        const SizedBox(height: SpaceSize.medium),
                        _WelcomeCard(
                          onStart: () => openAddFlow(context, services),
                        ),
                      ],
                      const SectionHeader('This month'),
                      _MonthFlow(summary: summary, currency: currency),
                      const SectionHeader('Money owed'),
                      _OweSummary(
                        summary: summary,
                        currency: currency,
                        onTap: () => _open(OweScreen(services: services)),
                      ),
                      SectionHeader(
                        'Accounts',
                        actionLabel: 'Manage',
                        onAction: () =>
                            _open(AccountScreen(services: services)),
                      ),
                      _AccountsCard(
                        summary: summary,
                        currency: currency,
                        onOpen: (id) => _open(
                          AccountDetailScreen(
                            services: services,
                            accountId: id,
                          ),
                        ),
                      ),
                      SectionHeader(
                        'Recent activity',
                        actionLabel: 'See all',
                        onAction: widget.onShowHistory,
                      ),
                      if (controller.recentActivity.isEmpty)
                        const Card(
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No activity yet',
                            message: 'Your latest expenses, income and transfers will show here.',
                          ),
                        )
                      else
                        GroupedCard(
                          children: [
                            for (final item in controller.recentActivity)
                              ActivityTile(
                                item: item,
                                currency: currency,
                                onSettle: settleAction(context, services, item),
                                onTap: () =>
                                    openActivity(context, services, item),
                              ),
                          ],
                        ),
                      const SectionHeader('Assets and tax'),
                      GroupedCard(
                        children: [
                          AppTile(
                            leading: const IconBadge(
                              Icons.inventory_2_outlined,
                            ),
                            title: 'Assets',
                            subtitle: 'Current value of things you own',
                            trailing: AmountText(
                              summary.assetValueMinor,
                              currency: currency,
                            ),
                            onTap: () => _open(AssetScreen(services: services)),
                          ),
                          AppTile(
                            leading: const IconBadge(
                              Icons.account_balance_outlined,
                            ),
                            title: 'Tax paid',
                            subtitle: 'This month',
                            trailing: AmountText(
                              summary.taxPaidMinor,
                              currency: currency,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The single high-emphasis surface on the screen.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.summary,
    required this.currency,
    required this.onTap,
  });
  final DashboardSummary summary;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final net =
        summary.incomeMinor - summary.expenseMinor - summary.taxPaidMinor;
    // In dark mode a bright card glares; use the deep brand container instead.
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? scheme.primaryContainer : scheme.primary;
    final foreground = dark ? scheme.onPrimaryContainer : scheme.onPrimary;
    final onPrimaryMuted = foreground.withValues(alpha: .78);
    final count = summary.accounts.where((a) => !a.account.isArchived).length;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(RadiusSize.extraLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CardSize.heroPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total balance',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onPrimaryMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: SpaceSize.extraSmall),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(summary.totalBalanceMinor, currency),
                  maxLines: 1,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: SpaceSize.extraSmall),
              Text(
                'Across $count ${count == 1 ? 'account' : 'accounts'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onPrimaryMuted,
                ),
              ),
              const SizedBox(height: SpaceSize.large),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpaceSize.medium,
                  vertical: SpaceSize.small,
                ),
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(RadiusSize.small),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      net >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: IconSize.small,
                      color: foreground,
                    ),
                    const SizedBox(width: SpaceSize.small),
                    Flexible(
                      child: Text(
                        '${money(net, currency, signed: true)} this month',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CardSize.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Money Tracker',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: SpaceSize.extraSmall),
            Text(
              'Start by recording something you spent or received today. '
              'Your balance and reports update automatically.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SpaceSize.medium),
            FilledButton.tonalIcon(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, ComponentSize.minTouchTarget),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first entry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthFlow extends StatelessWidget {
  const _MonthFlow({required this.summary, required this.currency});
  final DashboardSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.south_west_rounded,
            label: 'Income',
            amount: summary.incomeMinor,
            currency: currency,
            color: colors.income,
            background: colors.incomeContainer,
          ),
        ),
        const SizedBox(width: SpaceSize.medium),
        Expanded(
          child: _StatCard(
            icon: Icons.north_east_rounded,
            label: 'Spent',
            amount: summary.expenseMinor,
            currency: currency,
            color: colors.expense,
            background: colors.expenseContainer,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.background,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final int amount;
  final String currency;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

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
              Row(
                children: [
                  IconBadge(
                    icon,
                    size: 28,
                    color: color,
                    background: background,
                  ),
                  const SizedBox(width: SpaceSize.small),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpaceSize.medium),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AmountText(
                  amount,
                  currency: currency,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OweSummary extends StatelessWidget {
  const _OweSummary({
    required this.summary,
    required this.currency,
    required this.onTap,
  });
  final DashboardSummary summary;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.call_received_rounded,
            label: 'Owed to you',
            amount: summary.oweInMinor,
            currency: currency,
            color: colors.warning,
            background: colors.warningContainer,
            onTap: onTap,
          ),
        ),
        const SizedBox(width: SpaceSize.medium),
        Expanded(
          child: _StatCard(
            icon: Icons.call_made_rounded,
            label: 'You owe',
            amount: summary.oweOutMinor,
            currency: currency,
            color: colors.warning,
            background: colors.warningContainer,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _AccountsCard extends StatelessWidget {
  const _AccountsCard({
    required this.summary,
    required this.currency,
    required this.onOpen,
  });
  final DashboardSummary summary;
  final String currency;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final active = summary.accounts.where((a) => !a.account.isArchived);
    if (active.isEmpty) {
      return const Card(
        child: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No accounts',
          message: 'Add a cash or bank account to start tracking.',
        ),
      );
    }
    return GroupedCard(
      children: [
        for (final a in active)
          AppTile(
            leading: IconBadge(
              a.account.type == AccountType.bank
                  ? Icons.account_balance_outlined
                  : Icons.payments_outlined,
            ),
            title: a.account.name,
            subtitle: a.account.type == AccountType.bank ? 'Bank' : 'Cash',
            trailing: AmountText(
              a.balanceMinor,
              currency: currency,
              tone: a.balanceMinor < 0
                  ? AmountTone.expense
                  : AmountTone.neutral,
            ),
            onTap: () => onOpen(a.account.id!),
          ),
      ],
    );
  }
}
