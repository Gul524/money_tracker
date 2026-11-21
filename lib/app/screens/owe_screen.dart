import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/money_amount.dart';
import '../controllers/owe_controller.dart';
import '../widgets/app_widgets.dart';
import 'add_entry_sheet.dart';
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

  Future<void> _settle(MoneyTransaction t) async {
    controller.clearError();
    final incoming = t.type == TransactionType.oweIn;
    final currency = widget.services.currencyCode;
    final accounts = controller.accounts.where((a) => !a.isArchived).toList();
    int? accountId =
        t.accountId ?? (accounts.length == 1 ? accounts.first.id : null);
    final amount = TextEditingController(text: amountInputText(t.amountMinor));
    final paid = controller.parts[t.id] ?? const <MoneyTransaction>[];

    await showAppSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) => SheetScaffold(
            title: incoming ? 'Record a receipt' : 'Record a payment',
            subtitle: paid.isEmpty
                ? '${money(t.amountMinor, currency)} ${incoming ? 'from' : 'to'} ${_who(t)} is still ${incoming ? 'owed to you' : 'owed'}. Enter less to pay in parts.'
                : '${money(t.amountMinor, currency)} left of ${money(controller.totalMinor(t), currency)} ${incoming ? 'from' : 'to'} ${_who(t)}.',
            error: controller.error,
            busy: controller.busy,
            primaryLabel: isAll(amount.text, t)
                ? (incoming ? 'Mark as received' : 'Mark as paid')
                : (incoming ? 'Record receipt' : 'Record payment'),
            onPrimary: accountId == null
                ? null
                : () async {
                    final all = isAll(amount.text, t);
                    if (await controller.pay(t.id!, accountId!, amount.text) &&
                        sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                      if (mounted) {
                        showMessage(
                          this.context,
                          all ? 'Marked as settled' : 'Payment recorded',
                        );
                      }
                    }
                  },
            secondaryLabel: 'Edit details',
            onSecondary: () {
              Navigator.pop(sheetContext);
              Navigator.of(this.context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      TransactionScreen(services: widget.services, existing: t),
                ),
              );
            },
            children: [
              AmountField(
                controller: amount,
                currency: currency,
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: SpaceSize.medium),
              Text(
                incoming ? 'Received in' : 'Paid from',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SpaceSize.small),
              GroupedCard(
                children: [
                  for (final a in accounts)
                    AppTile(
                      leading: IconBadge(
                        a.type == AccountType.bank
                            ? Icons.account_balance_outlined
                            : Icons.payments_outlined,
                      ),
                      title: a.name,
                      showChevron: false,
                      trailing: accountId == a.id
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : Icon(
                              Icons.circle_outlined,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      onTap: () => setSheetState(() => accountId = a.id),
                    ),
                ],
              ),
              const SizedBox(height: SpaceSize.medium),
              if (paid.isNotEmpty) ...[
                Text(
                  incoming ? 'Received so far' : 'Paid so far',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: SpaceSize.small),
                GroupedCard(
                  children: [
                    for (final p in paid)
                      AppTile(
                        title: formatDate(p.occurredAt),
                        showChevron: false,
                        trailing: AmountText(
                          p.amountMinor,
                          currency: currency,
                          tone: AmountTone.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SpaceSize.medium),
              ],
            ],
          ),
        ),
      ),
    );
    amount.dispose();
  }

  /// True when the typed amount covers everything still owed.
  bool isAll(String text, MoneyTransaction t) =>
      MoneyAmount.tryParse(text) == t.amountMinor;

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
