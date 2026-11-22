import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/money_amount.dart';
import '../controllers/owe_controller.dart';
import '../widgets/app_widgets.dart';

/// "Record a payment / receipt" sheet for a pending owe: pay it all or part of
/// it. Returns true when something was recorded. [onEdit] adds an
/// "Edit details" button.
Future<bool> showOweSettleSheet(
  BuildContext context,
  AppServices services,
  MoneyTransaction owe, {
  VoidCallback? onEdit,
}) async {
  final done = await showAppSheet<bool>(
    context,
    builder: (sheetContext) =>
        _SettleSheet(services: services, owe: owe, onEdit: onEdit),
  );
  if (done == true && context.mounted) {
    showMessage(context, 'Payment recorded');
  }
  return done == true;
}

class _SettleSheet extends StatefulWidget {
  const _SettleSheet({required this.services, required this.owe, this.onEdit});
  final AppServices services;
  final MoneyTransaction owe;
  final VoidCallback? onEdit;
  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  late final OweController controller = OweController(widget.services);
  late final TextEditingController amount = TextEditingController(
    text: amountInputText(widget.owe.amountMinor),
  );
  int? _accountId;

  @override
  void dispose() {
    amount.dispose();
    controller.dispose();
    super.dispose();
  }

  String get _who => widget.owe.party?.trim().isNotEmpty == true
      ? widget.owe.party!.trim()
      : (widget.owe.type == TransactionType.oweIn
            ? 'Someone'
            : 'Someone you owe');

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final t = widget.owe;
      final incoming = t.type == TransactionType.oweIn;
      final currency = widget.services.currencyCode;
      final accounts = controller.accounts.where((a) => !a.isArchived).toList();
      final accountId =
          _accountId ??
          t.accountId ??
          (accounts.length == 1 ? accounts.first.id : null);
      final paid = controller.parts[t.id] ?? const <MoneyTransaction>[];
      final all = MoneyAmount.tryParse(amount.text) == t.amountMinor;
      final scheme = Theme.of(context).colorScheme;
      return SheetScaffold(
        title: incoming ? 'Record a receipt' : 'Record a payment',
        subtitle: paid.isEmpty
            ? '${money(t.amountMinor, currency)} ${incoming ? 'from' : 'to'} $_who is still ${incoming ? 'owed to you' : 'owed'}. Enter less to pay in parts.'
            : '${money(t.amountMinor, currency)} left of ${money(controller.totalMinor(t), currency)} ${incoming ? 'from' : 'to'} $_who.',
        error: controller.error,
        busy: controller.busy,
        primaryLabel: all
            ? (incoming ? 'Mark as received' : 'Mark as paid')
            : (incoming ? 'Record receipt' : 'Record payment'),
        onPrimary: accountId == null
            ? null
            : () async {
                if (await controller.pay(t.id!, accountId, amount.text) &&
                    context.mounted) {
                  Navigator.pop(context, true);
                }
              },
        secondaryLabel: widget.onEdit == null ? null : 'Edit details',
        onSecondary: widget.onEdit == null
            ? null
            : () {
                Navigator.pop(context, false);
                widget.onEdit!();
              },
        children: [
          AmountField(
            controller: amount,
            currency: currency,
            onChanged: (_) => setState(() {}),
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
                      ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                      : Icon(Icons.circle_outlined, color: scheme.outline),
                  onTap: () => setState(() => _accountId = a.id),
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
            OwePaymentsCard(payments: paid, currency: currency),
            const SizedBox(height: SpaceSize.medium),
          ],
        ],
      );
    },
  );
}

/// The part payments of an owe, oldest first.
class OwePaymentsCard extends StatelessWidget {
  const OwePaymentsCard({
    super.key,
    required this.payments,
    required this.currency,
  });
  final List<MoneyTransaction> payments;
  final String currency;

  @override
  Widget build(BuildContext context) => GroupedCard(
    children: [
      for (final p in payments)
        AppTile(
          leading: const IconBadge(Icons.check_rounded),
          title: formatDate(p.occurredAt),
          showChevron: false,
          trailing: AmountText(
            p.amountMinor,
            currency: currency,
            tone: AmountTone.muted,
          ),
        ),
    ],
  );
}
