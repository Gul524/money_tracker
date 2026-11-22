import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/owe_controller.dart';
import '../widgets/app_widgets.dart';
import 'add_entry_sheet.dart';
import 'owe_settle_sheet.dart';
import 'transaction_screen.dart';

/// Pending money lent and borrowed, with a "mark as paid" flow.
class OweScreen extends StatefulWidget {
  const OweScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<OweScreen> createState() => _OweScreenState();
}

class _OweScreenState extends State<OweScreen> {
  late final OweController controller;

  @override
  void initState() {
    super.initState();
    controller = OweController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String _who(MoneyTransaction t) => t.party?.trim().isNotEmpty == true
      ? t.party!.trim()
      : (t.type == TransactionType.oweIn ? 'Someone' : 'Someone you owe');

  Future<void> _settle(MoneyTransaction t) {
    controller.clearError();
    return showOweSettleSheet(
      context,
      widget.services,
      t,
      onEdit: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              TransactionScreen(services: widget.services, existing: t),
        ),
      ),
    );
  }

  Widget _tile(MoneyTransaction t) {
    final colors = AppColors.of(context);
    final today = dateOnly(DateTime.now());
    final due = t.dueAt;
    final overdue = due != null && dateOnly(due).isBefore(today);
    final paid = controller.paidMinor(t);
    final total = controller.totalMinor(t);
    final tile = AppTile(
      leading: IconBadge(
        t.type == TransactionType.oweIn
            ? Icons.call_received_rounded
            : Icons.call_made_rounded,
        color: colors.warning,
        background: colors.warningContainer,
      ),
      title: _who(t),
      subtitle: [
        due == null
            ? 'No due date'
            : overdue
            ? 'Overdue since ${formatDate(due).replaceFirst(' ${today.year}', '')}'
            : 'Due ${relativeDay(due) == 'Today' ? 'today' : formatDate(due)}',
        if (paid > 0)
          'Paid ${money(paid, widget.services.currencyCode)} of ${money(total, widget.services.currencyCode)}',
        ?controller.links[t.id],
      ].join(' · '),
      subtitleColor: overdue ? colors.expense : null,
      trailing: AmountText(
        t.amountMinor,
        currency: widget.services.currencyCode,
      ),
      onTap: () => _settle(t),
    );
    if (paid == 0) return tile;
    return Column(
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.gutter,
            0,
            SpaceSize.gutter,
            SpaceSize.small,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RadiusSize.small),
            child: LinearProgressIndicator(value: paid / total, minHeight: 6),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<MoneyTransaction> items) {
    final theme = Theme.of(context);
    final total = items.fold<int>(0, (sum, t) => sum + t.amountMinor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.extraSmall,
            SpaceSize.section,
            SpaceSize.extraSmall,
            SpaceSize.small,
          ),
          child: Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              AmountText(
                total,
                currency: widget.services.currencyCode,
                tone: AmountTone.muted,
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          const InfoNote('Nothing pending.')
        else
          GroupedCard(children: [for (final t in items) _tile(t)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      return Scaffold(
        appBar: AppBar(title: const Text('Money owed')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => openAddFlow(context, widget.services),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.gutter,
            SpaceSize.small,
            SpaceSize.gutter,
            SpaceSize.fabClearance,
          ),
          children: [
            ErrorBanner(controller.error),
            if (controller.items.isEmpty && !controller.busy)
              const EmptyState(
                icon: Icons.handshake_outlined,
                title: 'Nothing owed',
                message:
                    'When you lend or borrow money or things, add it here so '
                    'you never forget who owes what.',
              )
            else ...[
              const InfoNote('Tap an entry to record a full or part payment.'),
              _section('Owed to you', controller.owedToMe),
              _section('You owe', controller.iOwe),
            ],
          ],
        ),
      );
    },
  );
}
