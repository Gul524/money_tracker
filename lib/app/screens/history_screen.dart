import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/history_controller.dart';
import '../date_range.dart';
import '../widgets/app_widgets.dart';
import 'activity_list.dart';

const _typeLabels = {
  ActivityFilter.all: 'All',
  ActivityFilter.expense: 'Expenses',
  ActivityFilter.income: 'Income',
  ActivityFilter.transfer: 'Transfers',
  ActivityFilter.owe: 'Owed',
  ActivityFilter.tax: 'Tax',
};

const _presetLabels = {
  DatePreset.thisMonth: 'This month',
  DatePreset.lastMonth: 'Last month',
  DatePreset.last3Months: 'Last 3 months',
  DatePreset.thisYear: 'This year',
  DatePreset.custom: 'Custom dates…',
};

/// Every money movement, grouped by day, with search and filters for type,
/// account, category and dates. Used as a tab, and pushed pre-filtered from
/// Reports.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.services,
    this.title = 'History',
    this.accountId,
    this.categoryId,
    this.range,
    this.initialFilter = ActivityFilter.all,
  });
  final AppServices services;
  final String title;
  final int? accountId;
  final int? categoryId;
  final DateRange? range;
  final ActivityFilter initialFilter;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryController controller;

  @override
  void initState() {
    super.initState();
    controller = HistoryController(
      widget.services,
      accountId: widget.accountId,
      categoryId: widget.categoryId,
      range: widget.range,
      preset: widget.range == null ? null : DatePreset.custom,
    )..filter = widget.initialFilter;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _openFilters() => showAppSheet<void>(
    context,
    builder: (sheetContext) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _FilterSheet(
        controller: controller,
        onDone: () => Navigator.pop(sheetContext),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final currency = widget.services.currencyCode;
      final visible = controller.visibleItems;
      final hasAny = controller.items.isNotEmpty;
      final (inflow, outflow) = controller.totalsOf(visible);
      final account = controller.selectedAccount;
      final category = controller.selectedCategory;
      final range = controller.range;

      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.medium(title: Text(widget.title)),
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
                          hintText: 'Search name, note or amount',
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
                            _FiltersButton(
                              count: controller.activeFilterCount,
                              onPressed: _openFilters,
                            ),
                            const SizedBox(width: SpaceSize.small),
                            for (final e in _typeLabels.entries) ...[
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
                      if (controller.activeFilterCount > 0) ...[
                        const SizedBox(height: SpaceSize.small),
                        Wrap(
                          spacing: SpaceSize.small,
                          runSpacing: SpaceSize.small,
                          children: [
                            if (account != null)
                              InputChip(
                                avatar: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                label: Text(account.name),
                                onPressed: _openFilters,
                                onDeleted: () => controller.setAccount(null),
                              ),
                            if (category != null)
                              InputChip(
                                avatar: const Icon(Icons.sell_outlined),
                                label: Text(category.name),
                                onPressed: _openFilters,
                                onDeleted: () => controller.setCategory(null),
                              ),
                            if (range != null)
                              InputChip(
                                avatar: const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                                label: Text(range.label),
                                onPressed: _openFilters,
                                onDeleted: () => controller.setRange(null),
                              ),
                          ],
                        ),
                      ],
                      if (controller.isFiltering && visible.isNotEmpty)
                        _ResultSummary(
                          count: visible.length,
                          inflow: inflow,
                          outflow: outflow,
                          currency: currency,
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
                    EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message: 'Try a different search or filter.',
                      actionLabel: controller.activeFilterCount > 0
                          ? 'Clear filters'
                          : null,
                      onAction: controller.clearFilters,
                    )
                  else
                    ActivityDayGroups(
                      items: visible,
                      services: widget.services,
                      accountId: controller.accountId,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.count, required this.onPressed});
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: const Icon(Icons.tune_rounded),
    ),
    label: const Text('Filters'),
    onPressed: onPressed,
  );
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.count,
    required this.inflow,
    required this.outflow,
    required this.currency,
  });
  final int count;
  final int inflow;
  final int outflow;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.only(top: SpaceSize.medium),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpaceSize.large,
            vertical: SpaceSize.medium,
          ),
          child: Wrap(
            spacing: SpaceSize.large,
            runSpacing: SpaceSize.extraSmall,
            children: [
              Text(
                count == 1 ? '1 entry' : '$count entries',
                style: style?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                'In ${money(inflow, currency)}',
                style: style?.copyWith(color: colors.income),
              ),
              Text('Out ${money(outflow, currency)}', style: style),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.controller, required this.onDone});
  final HistoryController controller;
  final VoidCallback onDone;

  static const _all = -1;

  Future<void> _pickAccount(BuildContext context) async {
    final picked = await showPickerSheet<int>(
      context,
      title: 'Account',
      selected: controller.accountId ?? _all,
      options: [
        const PickerOption(
          value: _all,
          title: 'All accounts',
          icon: Icons.all_inclusive_rounded,
        ),
        for (final a in controller.accounts)
          PickerOption(
            value: a.id!,
            title: a.name,
            subtitle: a.isArchived ? 'Archived' : null,
            icon: a.type == AccountType.bank
                ? Icons.account_balance_outlined
                : Icons.payments_outlined,
          ),
      ],
    );
    if (picked != null) controller.setAccount(picked == _all ? null : picked);
  }

  Future<void> _pickCategory(BuildContext context) async {
    final sorted = [...controller.categories]
      ..sort(
        (a, b) => controller
            .pathFor(a)
            .toLowerCase()
            .compareTo(controller.pathFor(b).toLowerCase()),
      );
    final picked = await showPickerSheet<int>(
      context,
      title: 'Category',
      selected: controller.categoryId ?? _all,
      options: [
        const PickerOption(
          value: _all,
          title: 'All categories',
          icon: Icons.all_inclusive_rounded,
        ),
        for (final c in sorted)
          PickerOption(
            value: c.id!,
            title: c.name,
            subtitle: switch (c.type) {
              CategoryType.income => 'Income',
              CategoryType.expense => 'Expense',
              CategoryType.both => 'Income and expense',
            },
            leading: CategoryBadge(
              name: c.name,
              iconKey: c.icon,
              colorHex: c.color,
              income: c.type == CategoryType.income,
            ),
            indent: ' / '.allMatches(controller.pathFor(c)).length,
          ),
      ],
    );
    if (picked != null) controller.setCategory(picked == _all ? null : picked);
  }

  Future<void> _pickDates(BuildContext context) async {
    final current = controller.range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: current == null
          ? null
          : DateTimeRange(start: current.start, end: current.lastDay),
      helpText: 'Show activity between',
      saveText: 'Apply',
    );
    if (picked != null) {
      controller.setRange(DateRange.days(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = controller.range;
    return SheetScaffold(
      title: 'Filter activity',
      primaryLabel: 'Show ${controller.visibleItems.length} results',
      onPrimary: onDone,
      secondaryLabel: controller.activeFilterCount > 0 ? 'Clear filters' : null,
      onSecondary: controller.clearFilters,
      children: [
        GroupedCard(
          dividerIndent: 56,
          children: [
            FormRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Account',
              value: controller.selectedAccount?.name,
              placeholder: 'All',
              onTap: () => _pickAccount(context),
              onClear: () => controller.setAccount(null),
            ),
            FormRow(
              icon: Icons.sell_outlined,
              label: 'Category',
              value: controller.selectedCategory?.name,
              placeholder: 'All',
              onTap: () => _pickCategory(context),
              onClear: () => controller.setCategory(null),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.extraSmall,
            SpaceSize.extraLarge,
            0,
            SpaceSize.small,
          ),
          child: Text('Date', style: theme.textTheme.titleMedium),
        ),
        Wrap(
          spacing: SpaceSize.small,
          runSpacing: SpaceSize.small,
          children: [
            ChoiceChip(
              label: const Text('Any time'),
              selected: range == null,
              onSelected: (_) => controller.setPreset(null),
            ),
            for (final e in _presetLabels.entries)
              ChoiceChip(
                label: Text(
                  e.key == DatePreset.custom &&
                          controller.preset == DatePreset.custom &&
                          range != null
                      ? range.label
                      : e.value,
                ),
                selected: controller.preset == e.key && range != null,
                onSelected: (_) => e.key == DatePreset.custom
                    ? _pickDates(context)
                    : controller.setPreset(e.key),
              ),
          ],
        ),
        const SizedBox(height: SpaceSize.large),
      ],
    );
  }
}
