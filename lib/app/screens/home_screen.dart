import 'package:flutter/material.dart';

import '../../data/services/activity_service.dart';
import '../../data/services/dashboard_service.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/home_controller.dart';
import '../widgets/app_widgets.dart';
import 'account_screen.dart';
import 'asset_screen.dart';
import 'owe_screen.dart';
import 'transaction_screen.dart';

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

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) controller.refresh();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final summary = controller.summary;
      final colors = Theme.of(context).colorScheme;
      final currency = widget.services.currencyCode;
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, SpaceSize.listBottom),
          children: [
            Text('YOUR MONEY', style: _eyebrow(context)),
            const SizedBox(height: 5),
            Text('Overview', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              summary == null
                  ? 'Your financial picture'
                  : '${_month(summary.asOf.month)} ${summary.asOf.day}, ${summary.asOf.year} · This month',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            if (controller.busy && summary == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Loading overview…')),
              ),
            if (controller.error != null) AppError(controller.error),
            if (summary != null) ...[
              _BalanceHero(summary: summary, currency: currency),
              const SizedBox(height: 28),
              _SectionHeading(title: 'This month', caption: 'Cash flow'),
              const SizedBox(height: 12),
              _CashFlow(summary: summary, currency: currency),
              const SizedBox(height: 30),
              _SectionHeading(
                title: 'Your position',
                caption: 'Across all records',
              ),
              const SizedBox(height: 12),
              _PositionList(
                summary: summary,
                currency: currency,
                onOwe: () => _open(OweScreen(services: widget.services)),
                onAssets: () => _open(AssetScreen(services: widget.services)),
              ),
              const SizedBox(height: 30),
              _SectionHeading(
                title: 'Accounts',
                caption: '${summary.accounts.length} total',
                onTap: () => _open(AccountScreen(services: widget.services)),
              ),
              const SizedBox(height: 12),
              if (summary.accounts.isEmpty)
                const _PlainEmpty(
                  'No accounts yet',
                  'Add an account to start tracking your balance.',
                )
              else
                ...summary.accounts.map(
                  (account) =>
                      _AccountRow(account: account, currency: currency),
                ),
              const SizedBox(height: 28),
              _SectionHeading(
                title: 'Recent activity',
                caption: 'See all',
                onTap: widget.onShowHistory,
              ),
              const SizedBox(height: 10),
              if (controller.recentActivity.isEmpty)
                const _PlainEmpty(
                  'No activity yet',
                  'Transactions and transfers will appear here.',
                )
              else
                ...controller.recentActivity.map(
                  (item) => _ActivityRow(
                    item: item,
                    currency: currency,
                    onTap: item.transaction == null
                        ? null
                        : () => _open(
                            TransactionScreen(
                              services: widget.services,
                              existing: item.transaction,
                            ),
                          ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

String _month(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

TextStyle _eyebrow(BuildContext context) => TextStyle(
  color: Theme.of(context).colorScheme.onSurfaceVariant,
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.5,
);

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.summary, required this.currency});
  final DashboardSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final net =
        summary.incomeMinor - summary.expenseMinor - summary.taxPaidMinor;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: colors.onPrimary.withValues(alpha: .8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'TOTAL IN ACCOUNTS',
                style: TextStyle(
                  color: colors.onPrimary.withValues(alpha: .8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(summary.totalBalanceMinor, currency),
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Divider(color: colors.onPrimary.withValues(alpha: .22), height: 1),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: Text(
                  'NET THIS MONTH',
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: .8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                money(net, currency),
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.caption,
    this.onTap,
  });
  final String title;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (onTap == null)
          Text(
            caption,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          )
        else
          TextButton(onPressed: onTap, child: Text(caption)),
      ],
    );
  }
}

class _CashFlow extends StatelessWidget {
  const _CashFlow({required this.summary, required this.currency});
  final DashboardSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = summary.incomeMinor + summary.expenseMinor;
    final incomeShare = total == 0 ? 0 : summary.incomeMinor / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FlowValue(
                  label: 'INCOME',
                  amount: summary.incomeMinor,
                  currency: currency,
                  icon: Icons.south_west_rounded,
                  color: colors.tertiary,
                ),
              ),
              Container(height: 48, width: 1, color: colors.outlineVariant),
              const SizedBox(width: 16),
              Expanded(
                child: _FlowValue(
                  label: 'EXPENSES',
                  amount: summary.expenseMinor,
                  currency: currency,
                  icon: Icons.north_east_rounded,
                  color: colors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  if (summary.incomeMinor > 0)
                    Expanded(
                      flex: (incomeShare * 100).round().clamp(1, 100),
                      child: Container(height: 7, color: colors.tertiary),
                    ),
                  if (summary.expenseMinor > 0)
                    Expanded(
                      flex: (100 - (incomeShare * 100).round()).clamp(1, 100),
                      child: Container(
                        height: 7,
                        color: colors.error.withValues(alpha: .7),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FlowValue extends StatelessWidget {
  const _FlowValue({
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.color,
  });
  final String label;
  final int amount;
  final String currency;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(label, style: _eyebrow(context)),
        ],
      ),
      const SizedBox(height: 8),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          money(amount, currency),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _PositionList extends StatelessWidget {
  const _PositionList({
    required this.summary,
    required this.currency,
    required this.onOwe,
    required this.onAssets,
  });
  final DashboardSummary summary;
  final String currency;
  final VoidCallback onOwe;
  final VoidCallback onAssets;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _MetricRow(
        icon: Icons.call_received_rounded,
        label: 'Owed to you',
        value: money(summary.oweInMinor, currency),
        onTap: onOwe,
      ),
      _MetricRow(
        icon: Icons.call_made_rounded,
        label: 'You owe',
        value: money(summary.oweOutMinor, currency),
        onTap: onOwe,
      ),
      _MetricRow(
        icon: Icons.inventory_2_outlined,
        label: 'Assets',
        value: money(summary.assetValueMinor, currency),
        onTap: onAssets,
      ),
      _MetricRow(
        icon: Icons.receipt_long_outlined,
        label: 'Tax paid this month',
        value: money(summary.taxPaidMinor, currency),
      ),
    ],
  );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.currency});
  final AccountOverview account;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 19,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.account.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  account.account.type.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            money(account.balanceMinor, currency),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.currency, this.onTap});
  final ActivityItem item;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (item.kind) {
      ActivityKind.transaction =>
        item.amountMinor >= 0
            ? Icons.south_west_rounded
            : Icons.north_east_rounded,
      ActivityKind.tax => Icons.receipt_long_outlined,
      ActivityKind.transfer => Icons.swap_horiz_rounded,
    };
    final positive =
        item.amountMinor > 0 &&
        !item.isPending &&
        item.kind != ActivityKind.transfer;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primary.withValues(alpha: .09),
                  child: Icon(icon, color: colors.primary, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.subtitle} · ${item.date.day}/${item.date.month}/${item.date.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  money(item.amountMinor, currency),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: positive ? colors.tertiary : colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
      ],
    );
  }
}

class _PlainEmpty extends StatelessWidget {
  const _PlainEmpty(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
