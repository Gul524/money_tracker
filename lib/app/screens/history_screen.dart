import 'package:flutter/material.dart';

import '../app_services.dart';
import '../controllers/history_controller.dart';
import '../widgets/app_widgets.dart';
import 'transaction_screen.dart';

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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const PageHeader(
          title: 'History',
          subtitle: 'Every money movement in one place',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: controller.items.isEmpty
              ? const AppEmpty('No activity yet')
              : AppPanel(
                  child: Column(
                    children: [
                      for (final item in controller.items)
                        AppListItem(
                          title: item.title,
                          subtitle:
                              '${item.subtitle} · ${item.date.day}/${item.date.month}/${item.date.year}',
                          icon: switch (item.kind) {
                            ActivityKind.transaction =>
                              Icons.receipt_long_outlined,
                            ActivityKind.tax => Icons.request_quote_outlined,
                            ActivityKind.transfer => Icons.swap_horiz,
                          },
                          trailing: Text(
                            money(
                              item.amountMinor,
                              widget.services.currencyCode,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  item.isPending ||
                                      item.kind == ActivityKind.transfer
                                  ? Theme.of(context).colorScheme.onSurface
                                  : item.amountMinor < 0
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          isViewOnly: item.transaction == null,
                          onTap: item.transaction == null
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TransactionScreen(
                                        services: widget.services,
                                        existing: item.transaction,
                                      ),
                                    ),
                                  );
                                },
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
