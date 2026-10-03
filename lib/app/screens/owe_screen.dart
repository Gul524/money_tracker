import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../app_services.dart';
import '../controllers/owe_controller.dart';
import '../widgets/app_widgets.dart';

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

  Future<void> _complete(int id) async {
    int? accountId;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mark as completed',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the account that received or paid the money.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              AppSelect<int>(
                label: 'Account',
                value: accountId,
                items: {
                  for (final a in controller.accounts.where(
                    (a) => !a.isArchived,
                  ))
                    a.id!: a.name,
                },
                onChanged: (v) => setSheetState(() => accountId = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: accountId == null
                    ? null
                    : () async {
                        if (await controller.complete(id, accountId!) &&
                            sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                child: const Text('Complete owe'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const PageHeader(title: 'Owe', subtitle: 'Money to receive and repay'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: controller.items.isEmpty
              ? const AppEmpty('No pending owes')
              : AppPanel(
                  child: Column(
                    children: [
                      for (final t in controller.items)
                        AppListItem(
                          title: t.party?.isNotEmpty == true
                              ? t.party!
                              : (t.type == TransactionType.oweIn
                                    ? 'Owed to you'
                                    : 'You owe'),
                          subtitle: t.dueAt == null
                              ? 'No due date'
                              : 'Due ${t.dueAt!.day}/${t.dueAt!.month}/${t.dueAt!.year}',
                          icon: t.type == TransactionType.oweIn
                              ? Icons.call_received
                              : Icons.call_made,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                money(
                                  t.amountMinor,
                                  widget.services.currencyCode,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Complete',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _complete(t.id!),
                        ),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: AppError(controller.error),
        ),
      ],
    ),
  );
}
