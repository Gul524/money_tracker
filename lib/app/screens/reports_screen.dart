import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../../data/services/dashboard_service.dart';
import '../../data/services/report_service.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/history_controller.dart';
import '../controllers/reports_controller.dart';
import '../date_range.dart';
import '../widgets/app_widgets.dart';
import 'account_detail_screen.dart';
import 'history_screen.dart';

const _periodLabels = {
  ReportPeriod.month: 'Month',
  ReportPeriod.sixMonths: '6 months',
  ReportPeriod.year: 'Year',
  ReportPeriod.custom: 'Custom',
};

/// Income, spending, tax and account movement for a chosen period.
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

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: controller.range.start,
        end: controller.range.lastDay,
      ),
      helpText: 'Choose report dates',
      saveText: 'Show report',
    );
    if (picked != null) {
      controller.setCustomRange(DateRange.days(picked.start, picked.end));
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _openHistory({
    required String title,
    int? categoryId,
    int? accountId,
    ActivityFilter filter = ActivityFilter.all,
  }) => _open(
    HistoryScreen(
      services: widget.services,
      title: title,
      categoryId: categoryId,
      accountId: accountId,
      range: controller.range,
      initialFilter: filter,
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final report = controller.report;
      final position = controller.position;
      final currency = widget.services.currencyCode;
      final rangeLabel = controller.range.label;
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
                  SegmentedButton<ReportPeriod>(
                    showSelectedIcon: false,
                    segments: [
                      for (final e in _periodLabels.entries)
                        ButtonSegment(value: e.key, label: Text(e.value)),
                    ],
                    selected: {controller.period},
                    onSelectionChanged: (value) {
                      if (value.first == ReportPeriod.custom) {
                        _pickCustomRange();
                      } else {
                        controller.setPeriod(value.first);
                      }
                    },
                  ),
                  const SizedBox(height: SpaceSize.medium),
                  _RangeBar(
                    controller: controller,
                    onChangeDates: _pickCustomRange,
                  ),
                  const SizedBox(height: SpaceSize.medium),
                  ErrorBanner(controller.error),
                  if (report == null && controller.busy)
                    const Padding(
                      padding: EdgeInsets.all(SpaceSize.huge),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (report != null) ...[
                    _Summary(report: report, currency: currency),
                    if (report.months.length > 1) ...[
                      const SectionHeader('Month by month'),
                      _TrendChart(months: report.months, currency: currency),
                    ],
                    const SectionHeader('Spending by category'),
                    _Breakdown(
                      groups: controller.spending,
                      currency: currency,
                      emptyText: 'No spending in this period.',
                      onOpen: (g) => _openHistory(
                        title: g.name,
                        categoryId: g.categoryId,
                        filter: ActivityFilter.expense,
                      ),
                    ),
                    const SectionHeader('Income by category'),
                    _Breakdown(
                      groups: controller.earning,
                      currency: currency,
                      income: true,
                      emptyText: 'No income in this period.',
                      onOpen: (g) => _openHistory(
                        title: g.name,
                        categoryId: g.categoryId,
                        filter: ActivityFilter.income,
                      ),
                    ),
                    SectionHeader(
                      'Tax paid',
                      actionLabel: report.taxMinor > 0 ? 'See entries' : null,
                      onAction: () => _openHistory(
                        title: 'Tax · $rangeLabel',
                        filter: ActivityFilter.tax,
                      ),
                    ),
                    _TaxSection(report: report, currency: currency),
                    const SectionHeader('Accounts'),
                    _AccountFlows(
                      report: report,
                      currency: currency,
                      onOpen: (flow) => _open(
                        AccountDetailScreen(
                          services: widget.services,
                          accountId: flow.account.id!,
                        ),
                      ),
                    ),
                    if (report.oweReceivedMinor > 0 ||
                        report.oweRepaidMinor > 0 ||
                        report.lentMinor > 0 ||
                        report.borrowedMinor > 0) ...[
                      const SectionHeader('Money owed'),
                      GroupedCard(
                        children: [
                          if (report.lentMinor > 0)
                            AppTile(
                              leading: const IconBadge(
                                Icons.north_east_rounded,
                              ),
                              title: 'Lent out',
                              trailing: AmountText(
                                report.lentMinor,
                                currency: currency,
                              ),
                            ),
                          if (report.borrowedMinor > 0)
                            AppTile(
                              leading: const IconBadge(
                                Icons.south_west_rounded,
                              ),
                              title: 'Borrowed',
                              trailing: AmountText(
                                report.borrowedMinor,
                                currency: currency,
                              ),
                            ),
                          if (report.oweReceivedMinor > 0)
                            AppTile(
                              leading: const IconBadge(
                                Icons.call_received_rounded,
                              ),
                              title: 'Received back',
                              trailing: AmountText(
                                report.oweReceivedMinor,
                                currency: currency,
                              ),
                            ),
                          if (report.oweRepaidMinor > 0)
                            AppTile(
                              leading: const IconBadge(Icons.call_made_rounded),
                              title: 'Paid back',
                              trailing: AmountText(
                                report.oweRepaidMinor,
                                currency: currency,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                  if (position != null) ...[
                    const SectionHeader('Where you stand today'),
                    _Position(summary: position, currency: currency),
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

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.controller, required this.onChangeDates});
  final ReportsController controller;
  final VoidCallback onChangeDates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      controller.range.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium,
    );
    if (!controller.canStep) {
      return Card(
        child: InkWell(
          onTap: onChangeDates,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpaceSize.large,
              vertical: SpaceSize.medium,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: SpaceSize.medium),
                Expanded(child: label),
                const SizedBox(width: SpaceSize.medium),
                Text(
                  'Change',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpaceSize.extraSmall),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous period',
              onPressed: controller.previous,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(child: label),
            IconButton(
              tooltip: 'Next period',
              onPressed: controller.canGoNext ? controller.next : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.report, required this.currency});
  final PeriodReport report;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final net = report.netMinor;
    final outflow = report.outflowMinor;
    final total = report.incomeMinor + outflow;

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
            Text('Net for this period', style: theme.textTheme.bodySmall),
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
                    if (report.incomeMinor > 0)
                      Expanded(
                        flex: report.incomeMinor,
                        child: Container(height: 8, color: colors.income),
                      ),
                    if (report.incomeMinor > 0 && outflow > 0)
                      const SizedBox(width: 2),
                    if (report.expenseMinor > 0)
                      Expanded(
                        flex: report.expenseMinor,
                        child: Container(height: 8, color: colors.expense),
                      ),
                    if (report.taxMinor > 0)
                      Expanded(
                        flex: report.taxMinor,
                        child: Container(height: 8, color: colors.warning),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: SpaceSize.medium),
            ],
            row('Income', report.incomeMinor, colors.income),
            row('Expenses', report.expenseMinor, colors.expense),
            row('Tax paid', report.taxMinor, colors.warning),
            const SizedBox(height: SpaceSize.small),
            Text(
              report.entryCount == 1
                  ? '1 entry'
                  : '${report.entryCount} entries',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Grouped bars: income vs. spending (expenses + tax) per month.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.months, required this.currency});
  final List<MonthBucket> months;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final peak = months.fold<int>(
      0,
      (m, b) => [
        m,
        b.incomeMinor,
        b.expenseMinor + b.taxMinor,
      ].reduce((a, c) => a > c ? a : c),
    );
    final spansYears = months.first.month.year != months.last.month.year;
    const chartHeight = 120.0;

    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: SpaceSize.small),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );

    Widget bar(int value, Color color) => Flexible(
      child: FractionallySizedBox(
        widthFactor: .8,
        child: Container(
          height: peak == 0
              ? 0
              : (value / peak * chartHeight).clamp(
                  value > 0 ? 2.0 : 0.0,
                  chartHeight,
                ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CardSize.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: SpaceSize.large,
              runSpacing: SpaceSize.extraSmall,
              children: [
                legend(colors.income, 'Income'),
                legend(colors.expense, 'Spending incl. tax'),
              ],
            ),
            const SizedBox(height: SpaceSize.large),
            if (peak == 0)
              Text(
                'No income or spending in this period.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Semantics(
                label: [
                  for (final b in months)
                    '${formatMonthYear(b.month)}: income '
                        '${money(b.incomeMinor, currency)}, spending '
                        '${money(b.expenseMinor + b.taxMinor, currency)}',
                ].join('. '),
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final b in months)
                      Expanded(
                        child: Column(
                          children: [
                            SizedBox(
                              height: chartHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  bar(b.incomeMinor, colors.income),
                                  bar(
                                    b.expenseMinor + b.taxMinor,
                                    colors.expense,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: SpaceSize.small),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                spansYears && b.month.month == 1
                                    ? '${shortMonth(b.month)}\n${b.month.year % 100}'
                                    : shortMonth(b.month),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.groups,
    required this.currency,
    required this.emptyText,
    required this.onOpen,
    this.income = false,
  });
  final List<CategoryGroup> groups;
  final String currency;
  final String emptyText;
  final bool income;
  final ValueChanged<CategoryGroup> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (groups.isEmpty) return _EmptyCard(emptyText);
    final sum = groups.fold<int>(0, (s, g) => s + g.totalMinor);
    return GroupedCard(
      children: [
        for (final g in groups)
          InkWell(
            onTap: () => onOpen(g),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.large,
                vertical: SpaceSize.medium,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryBadge(
                    name: g.name,
                    iconKey: g.icon,
                    colorHex: g.color,
                    income: income,
                  ),
                  const SizedBox(width: SpaceSize.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            AmountText(g.totalMinor, currency: currency),
                          ],
                        ),
                        const SizedBox(height: SpaceSize.small),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: g.totalMinor / sum,
                                  minHeight: 6,
                                  color: readableCategoryColor(
                                    categoryColor(g.name, hex: g.color),
                                    theme.brightness,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: SpaceSize.medium),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${(g.totalMinor * 100 / sum).round()}%',
                                textAlign: TextAlign.end,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        for (final (name, total) in g.parts)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: SpaceSize.small,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                AmountText(
                                  total,
                                  currency: currency,
                                  tone: AmountTone.muted,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TaxSection extends StatelessWidget {
  const _TaxSection({required this.report, required this.currency});
  final PeriodReport report;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (report.taxMinor == 0) {
      return const _EmptyCard('No tax paid in this period.');
    }
    final colors = AppColors.of(context);
    final share = report.incomeMinor == 0
        ? null
        : '${(report.taxMinor * 100 / report.incomeMinor).toStringAsFixed(1)}% of income';
    return GroupedCard(
      children: [
        AppTile(
          leading: IconBadge(
            Icons.receipt_long_outlined,
            color: colors.warning,
            background: colors.warningContainer,
          ),
          title: 'Total tax paid',
          subtitle: share,
          trailing: AmountText(
            report.taxMinor,
            currency: currency,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final flow in report.accounts.where((f) => f.taxMinor > 0))
          AppTile(
            leading: IconBadge(_accountIcon(flow.account.type)),
            title: 'From ${flow.account.name}',
            trailing: AmountText(flow.taxMinor, currency: currency),
          ),
      ],
    );
  }
}

class _AccountFlows extends StatelessWidget {
  const _AccountFlows({
    required this.report,
    required this.currency,
    required this.onOpen,
  });
  final PeriodReport report;
  final String currency;
  final ValueChanged<AccountFlow> onOpen;

  @override
  Widget build(BuildContext context) {
    if (report.accounts.isEmpty) return const _EmptyCard('No accounts yet.');
    return GroupedCard(
      children: [
        for (final flow in report.accounts)
          AppTile(
            leading: IconBadge(_accountIcon(flow.account.type)),
            title: flow.account.name,
            subtitle:
                'In ${money(flow.inMinor, currency)} · '
                'Out ${money(flow.outMinor, currency)}',
            trailing: AmountText(
              flow.netMinor,
              currency: currency,
              signed: true,
              tone: flow.netMinor > 0
                  ? AmountTone.income
                  : flow.netMinor < 0
                  ? AmountTone.neutral
                  : AmountTone.muted,
            ),
            onTap: () => onOpen(flow),
          ),
      ],
    );
  }
}

IconData _accountIcon(AccountType type) => type == AccountType.bank
    ? Icons.account_balance_outlined
    : Icons.payments_outlined;

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CardSize.padding),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
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
