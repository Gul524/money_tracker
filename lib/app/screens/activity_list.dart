import 'package:flutter/material.dart';

import '../../data/services/activity_service.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../widgets/app_widgets.dart';
import 'owe_settle_sheet.dart';
import 'transaction_screen.dart';
import 'transfer_screen.dart';

/// Opens the editor for any activity row: transactions (and their linked
/// tax), standalone tax payments and transfers.
Future<void> openActivity(
  BuildContext context,
  AppServices services,
  ActivityItem item,
) async {
  final Widget page = switch (item.kind) {
    ActivityKind.transaction => TransactionScreen(
      services: services,
      existing: item.transaction,
    ),
    ActivityKind.tax => TransactionScreen(
      services: services,
      existingTax: item.tax,
    ),
    ActivityKind.transfer => TransferScreen(
      services: services,
      existing: item.transfer,
    ),
  };
  final saved = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => page));
  if (saved == true && context.mounted) showMessage(context, 'Saved');
}

/// The one-click pay/receive action for a pending owe row (null otherwise).
VoidCallback? settleAction(
  BuildContext context,
  AppServices services,
  ActivityItem item,
) => item.isPending && item.transaction != null
    ? () => showOweSettleSheet(context, services, item.transaction!)
    : null;

/// Activity grouped by day (Today, Yesterday, …) with each day's net.
class ActivityDayGroups extends StatelessWidget {
  const ActivityDayGroups({
    super.key,
    required this.items,
    required this.services,
    this.accountId,
  });
  final List<ActivityItem> items;
  final AppServices services;

  /// Shows amounts from this account's point of view.
  final int? accountId;

  @override
  Widget build(BuildContext context) {
    final groups = <(DateTime, List<ActivityItem>)>[];
    for (final item in items) {
      final day = dateOnly(item.date);
      if (groups.isEmpty || groups.last.$1 != day) groups.add((day, []));
      groups.last.$2.add(item);
    }
    final currency = services.currencyCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (day, dayItems) in groups) ...[
          _DayHeader(
            day: day,
            net: dayItems.fold<int>(
              0,
              (sum, i) =>
                  sum +
                  (accountId == null
                      ? i.netEffectMinor
                      : i.effectOn(accountId!)),
            ),
            currency: currency,
          ),
          GroupedCard(
            children: [
              for (final item in dayItems)
                ActivityTile(
                  item: item,
                  currency: currency,
                  showDate: false,
                  accountId: accountId,
                  onSettle: settleAction(context, services, item),
                  onTap: () => openActivity(context, services, item),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.net,
    required this.currency,
  });
  final DateTime day;
  final int net;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
