import 'package:flutter/material.dart';

import '../../data/services/dashboard_service.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/reports_controller.dart';
import '../widgets/app_widgets.dart';

/// Month-by-month summary, category breakdown, and overall position.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportsController controller;

  @override
  void initState() {
    super.initState();
    controller = ReportsController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final summary = controller.summary;
      final currency = widget.services.currencyCode;
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverAppBar.medium(title: Text('Reports')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                SpaceSize.gutter,
                0,
                SpaceSize.gutter,
                SpaceSize.huge,
              ),
              sliver: SliverList.list(
                children: [
                  _MonthSwitcher(controller: controller),
                  const SizedBox(height: SpaceSize.medium),
                  ErrorBanner(controller.error),
                  if (summary == null && controller.busy)
                    const Padding(
                      padding: EdgeInsets.all(SpaceSize.huge),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (summary != null) ...[
                    _MonthSummary(summary: summary, currency: currency),
                    const SectionHeader('Spending by category'),
                    _Breakdown(
                      totals: controller.spending,
                      currency: currency,
                      emptyText: 'No spending recorded this month.',
                    ),
                    const SectionHeader('Income by category'),
                    _Breakdown(
                      totals: controller.earning,
                      currency: currency,
                      income: true,
                      emptyText: 'No income recorded this month.',
                    ),
                    const SectionHeader('Where you stand today'),
                    _Position(summary: summary, currency: currency),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.controller});
  final ReportsController controller;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpaceSize.extraSmall),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: controller.previousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              formatMonthYear(controller.month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: controller.isCurrentMonth ? null : controller.nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    ),
  );
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.summary, required this.currency});
  final DashboardSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final net =
        summary.incomeMinor - summary.expenseMinor - summary.taxPaidMinor;
    final outflow = summary.expenseMinor + summary.taxPaidMinor;
    final total = summary.incomeMinor + outflow;

    Widget row(String label, int amount, Color dot) => Padding(
      padding: const EdgeInsets.symmetric(vertical: SpaceSize.small),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: SpaceSize.medium),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          AmountText(amount, currency: currency),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CardSize.heroPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net for the month', style: theme.textTheme.bodySmall),
            const SizedBox(height: SpaceSize.extraSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountText(
                net,
                currency: currency,
                signed: true,
                tone: net < 0 ? AmountTone.expense : AmountTone.income,
                style: theme.textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: SpaceSize.large),
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(RadiusSize.small),
                child: Row(
                  children: [
                    if (summary.incomeMinor > 0)
                      Expanded(
                        flex: summary.incomeMinor,
                        child: Container(height: 8, color: colors.income),
                      ),
                    if (summary.incomeMinor > 0 && outflow > 0)
                      const SizedBox(width: 2),
                    if (outflow > 0)
                      Expanded(
                        flex: outflow,
                        child: Container(height: 8, color: colors.expense),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: SpaceSize.medium),
            ],
            row('Income', summary.incomeMinor, colors.income),
            row('Expenses', summary.expenseMinor, colors.expense),
            row(
              'Tax paid',
              summary.taxPaidMinor,
              colors.expense.withValues(alpha: .5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.totals,
    required this.currency,
    required this.emptyText,
    this.income = false,
  });
  final List<CategoryTotal> totals;
  final String currency;
  final String emptyText;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    if (totals.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(CardSize.padding),
          child: Text(
            emptyText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final sum = totals.fold<int>(0, (s, t) => s + t.totalMinor);
    final barColor = income ? colors.income : theme.colorScheme.primary;
    return GroupedCard(
      children: [
        for (final t in totals)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpaceSize.large,
              vertical: SpaceSize.medium,
            ),
            child: Row(
              children: [
                IconBadge(categoryIcon(t.name, income: income)),
                const SizedBox(width: SpaceSize.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          AmountText(t.totalMinor, currency: currency),
                        ],
                      ),
                      const SizedBox(height: SpaceSize.small),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: t.totalMinor / sum,
                                minHeight: 6,
                                color: barColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: SpaceSize.medium),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${(t.totalMinor * 100 / sum).round()}%',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Position extends StatelessWidget {
  const _Position({required this.summary, required this.currency});
  final DashboardSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final netWorth =
        summary.totalBalanceMinor +
        summary.oweInMinor -
        summary.oweOutMinor +
        summary.assetValueMinor;
    Widget tile(IconData icon, String label, int amount, {String? hint}) =>
        AppTile(
          leading: IconBadge(icon),
          title: label,
          subtitle: hint,
          trailing: AmountText(amount, currency: currency),
        );
    return Column(
      children: [
        GroupedCard(
          children: [
            tile(
              Icons.account_balance_wallet_outlined,
              'Account balances',
              summary.totalBalanceMinor,
            ),
            tile(
              Icons.call_received_rounded,
              'Owed to you',
              summary.oweInMinor,
            ),
            tile(Icons.call_made_rounded, 'You owe', -summary.oweOutMinor),
            tile(Icons.inventory_2_outlined, 'Assets', summary.assetValueMinor),
          ],
        ),
        const SizedBox(height: SpaceSize.medium),
        GroupedCard(
          children: [
            tile(
              Icons.savings_outlined,
              'Net worth',
              netWorth,
              hint: 'Balances + owed to you − you owe + assets',
            ),
          ],
        ),
      ],
    );
  }
}
