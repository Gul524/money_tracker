import 'package:flutter/material.dart';

import '../../data/services/activity_service.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/history_controller.dart';
import '../widgets/app_widgets.dart';
import 'transaction_screen.dart';

const _filterLabels = {
  ActivityFilter.all: 'All',
  ActivityFilter.expense: 'Expenses',
  ActivityFilter.income: 'Income',
  ActivityFilter.transfer: 'Transfers',
  ActivityFilter.owe: 'Owed',
  ActivityFilter.tax: 'Tax',
};

/// Every money movement, grouped by day, with search and type filters.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryController controller;

  @override
  void initState() {
    super.initState();
    controller = HistoryController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  List<(DateTime, List<ActivityItem>)> _groupByDay(List<ActivityItem> items) {
    final groups = <(DateTime, List<ActivityItem>)>[];
    for (final item in items) {
      final day = dateOnly(item.date);
      if (groups.isEmpty || groups.last.$1 != day) groups.add((day, []));
      groups.last.$2.add(item);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final currency = widget.services.currencyCode;
      final visible = controller.visibleItems;
      final hasAny = controller.items.isNotEmpty;

      return Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverAppBar.medium(title: Text('History')),
            if (hasAny)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpaceSize.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        onChanged: controller.setQuery,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Search by category, person or note',
                          prefixIcon: Icon(Icons.search_rounded),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: SpaceSize.medium,
                          ),
                        ),
                      ),
                      const SizedBox(height: SpaceSize.medium),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final e in _filterLabels.entries) ...[
                              ChoiceChip(
                                label: Text(e.value),
                                selected: controller.filter == e.key,
                                onSelected: (_) => controller.setFilter(e.key),
                                selectedColor: theme.colorScheme.onSurface,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: controller.filter == e.key
                                      ? theme.colorScheme.surface
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: SpaceSize.small),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                SpaceSize.gutter,
                0,
                SpaceSize.gutter,
                SpaceSize.fabClearance,
              ),
              sliver: SliverList.list(
                children: [
                  ErrorBanner(controller.error),
                  if (!hasAny && !controller.busy)
                    const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No activity yet',
                      message: 'Tap Add to record your first expense, income or transfer.',
                    )
                  else if (visible.isEmpty && hasAny)
                    const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message: 'Try a different search or filter.',
                    )
                  else
                    for (final (day, items) in _groupByDay(visible)) ...[
                      _DayHeader(day: day, items: items, currency: currency),
                      GroupedCard(
                        children: [
                          for (final item in items)
                            ActivityTile(
                              item: item,
                              currency: currency,
                              showDate: false,
                              onTap: item.transaction == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => TransactionScreen(
                                          services: widget.services,
                                          existing: item.transaction,
                                        ),
                                      ),
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
      );
    },
  );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.items,
    required this.currency,
  });
  final DateTime day;
  final List<ActivityItem> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Net of settled income/expense/tax for the day; transfers and pending
    // owes don't change what you have overall.
    final net = items
        .where((i) => i.kind != ActivityKind.transfer && !i.isPending)
        .fold<int>(0, (sum, i) => sum + i.amountMinor);
    final style = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpaceSize.extraSmall,
        SpaceSize.extraLarge,
        SpaceSize.extraSmall,
        SpaceSize.small,
      ),
      child: Row(
        children: [
          Expanded(child: Text(relativeDay(day), style: style)),
          if (net != 0)
            Text(
              money(net, currency, signed: true),
              style: style?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}
