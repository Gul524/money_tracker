import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_sizes.dart';
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
  @override
  void initState() {
    super.initState();
    controller = TransferController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Transfer money')),
      body: ListView(
        padding: const EdgeInsets.all(SpaceSize.extraLarge),
        children: [
          Text(
            'Move money between your accounts without changing income or expenses.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpaceSize.header),
          AppPanel(
            child: Column(
              children: [
                AppSelect<int>(
                  label: 'From account',
                  value: controller.fromAccountId,
                  items: {for (final a in controller.accounts) a.id!: a.name},
                  onChanged: controller.setFrom,
                ),
                const SizedBox(height: SpaceSize.form),
                AppSelect<int>(
                  label: 'To account',
                  value: controller.toAccountId,
                  items: {for (final a in controller.accounts) a.id!: a.name},
                  onChanged: controller.setTo,
                ),
                const SizedBox(height: SpaceSize.form),
                AppInput(
                  label: 'Amount (${widget.services.currencyCode})',
                  value: controller.amountText,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: controller.setAmount,
                ),
                AppDateField(
                  label: 'Date',
                  value: controller.occurredAt,
                  onChanged: (d) {
                    if (d != null) controller.setDate(d);
                  },
                ),
                AppInput(
                  label: 'Note (optional)',
                  value: controller.note,
                  onChanged: controller.setNote,
                ),
              ],
            ),
          ),
          const SizedBox(height: SpaceSize.large),
          AppError(controller.error),
          FilledButton(
            onPressed: controller.busy
                ? null
                : () async {
                    if (await controller.save() && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
            child: const Padding(
              padding: EdgeInsets.all(SpaceSize.form),
              child: Text('Transfer'),
            ),
          ),
        ],
      ),
    ),
  );
}
