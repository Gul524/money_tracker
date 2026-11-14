import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/transfer_controller.dart';
import '../widgets/app_widgets.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  late final TransferController controller;
  final amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = TransferController(widget.services);
  }

  @override
  void dispose() {
    amount.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool from}) async {
    final currency = widget.services.currencyCode;
    final picked = await showPickerSheet<int>(
      context,
      title: from ? 'Move money from' : 'Move money to',
      selected: from ? controller.fromAccountId : controller.toAccountId,
      emptyMessage: 'Add an account in Settings › Accounts first.',
      options: [
        for (final a in controller.accounts)
          PickerOption(
            value: a.id!,
            title: a.name,
            subtitle:
                'Balance ${money(controller.balances[a.id] ?? 0, currency)}',
            icon: a.type == AccountType.bank
                ? Icons.account_balance_outlined
                : Icons.payments_outlined,
          ),
      ],
    );
    if (picked == null) return;
    from ? controller.setFrom(picked) : controller.setTo(picked);
  }

  String? _name(int? id) =>
      controller.accounts.where((a) => a.id == id).firstOrNull?.name;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (await controller.save() && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final colors = AppColors.of(context);
      return Scaffold(
        appBar: AppBar(title: const Text('Transfer money')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.gutter,
            SpaceSize.large,
            SpaceSize.gutter,
            SpaceSize.large,
          ),
          children: [
            AmountField(
              controller: amount,
              currency: widget.services.currencyCode,
              color: colors.transfer,
              autofocus: true,
              onChanged: controller.setAmount,
            ),
            const SizedBox(height: SpaceSize.section),
            Stack(
              alignment: Alignment.center,
              children: [
                GroupedCard(
                  dividerIndent: 56,
                  children: [
                    FormRow(
                      icon: Icons.logout_rounded,
                      label: 'From',
                      value: _name(controller.fromAccountId),
                      onTap: () => _pick(from: true),
                    ),
                    FormRow(
                      icon: Icons.login_rounded,
                      label: 'To',
                      value: _name(controller.toAccountId),
                      onTap: () => _pick(from: false),
                    ),
                  ],
                ),
                IconButton.filledTonal(
                  tooltip: 'Swap accounts',
                  onPressed: controller.swap,
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
              ],
            ),
            const SizedBox(height: SpaceSize.medium),
            GroupedCard(
              dividerIndent: 56,
              children: [
                FormRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: relativeDay(controller.occurredAt) == 'Today'
                      ? 'Today'
                      : formatDate(controller.occurredAt),
                  onTap: () async {
                    final d = await pickDate(context, controller.occurredAt);
                    if (d != null) controller.setDate(d);
                  },
                ),
                FormTextRow(
                  icon: Icons.notes_rounded,
                  hint: 'Add a note (optional)',
                  value: controller.note,
                  onChanged: controller.setNote,
                ),
              ],
            ),
            const InfoNote(
              'Transfers move money between your own accounts. They don’t '
              'count as income or expense.',
            ),
            ErrorBanner(controller.error),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: FilledButton(
            onPressed: controller.busy ? null : _save,
            child: const Text('Transfer'),
          ),
        ),
      );
    },
  );
}
