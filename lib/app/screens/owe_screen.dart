import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
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

    await showAppSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) => SheetScaffold(
            title: incoming ? 'Mark as received' : 'Mark as paid',
            subtitle: incoming
                ? '${money(t.amountMinor, currency)} from ${_who(t)} will be added to the account you choose.'
                : '${money(t.amountMinor, currency)} to ${_who(t)} will be taken from the account you choose.',
            error: controller.error,
            busy: controller.busy,
            primaryLabel: incoming ? 'Mark as received' : 'Mark as paid',
            onPrimary: accountId == null
                ? null
                : () async {
                    if (await controller.complete(t.id!, accountId!) &&
                        sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                      if (mounted) {
                        showMessage(this.context, 'Marked as settled');
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(MoneyTransaction t) {
    final colors = AppColors.of(context);
    final today = dateOnly(DateTime.now());
    final due = t.dueAt;
    final overdue = due != null && dateOnly(due).isBefore(today);
    return AppTile(
      leading: IconBadge(
        t.type == TransactionType.oweIn
            ? Icons.call_received_rounded
            : Icons.call_made_rounded,
        color: colors.warning,
        background: colors.warningContainer,
      ),
      title: _who(t),
      subtitle: due == null
          ? 'No due date'
          : overdue
          ? 'Overdue since ${formatDate(due).replaceFirst(' ${today.year}', '')}'
          : 'Due ${relativeDay(due) == 'Today' ? 'today' : formatDate(due)}',
      subtitleColor: overdue ? colors.expense : null,
      trailing: AmountText(
        t.amountMinor,
        currency: widget.services.currencyCode,
      ),
      onTap: () => _settle(t),
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
                message: 'When you lend or borrow money, add it here so you never forget who owes what.',
              )
            else ...[
              const InfoNote('Tap an entry when it’s been paid back.'),
              _section('Owed to you', controller.owedToMe),
              _section('You owe', controller.iOwe),
            ],
          ],
        ),
      );
    },
  );
}
