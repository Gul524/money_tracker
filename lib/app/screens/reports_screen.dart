import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/home_controller.dart';
import '../widgets/app_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final HomeController controller;

  @override
  void initState() {
    super.initState();
    controller = HomeController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final summary = controller.summary;
      final currency = widget.services.currencyCode;
      return ListView(
        children: [
          const PageHeader(
            title: 'Reports',
            subtitle: 'A snapshot of your money',
          ),
          if (controller.busy && summary == null)
            const Center(child: CircularProgressIndicator()),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: AppError(controller.error),
            ),
          if (summary != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This month',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: SpaceSize.extraSmall),
                    Text(
                      '${summary.asOf.year}-${summary.asOf.month.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SpaceSize.medium),
                    AppValue(
                      label: 'Income',
                      value: money(summary.incomeMinor, currency),
                    ),
                    AppValue(
                      label: 'Expenses',
                      value: money(summary.expenseMinor, currency),
                    ),
                    AppValue(
                      label: 'Tax paid',
                      value: money(summary.taxPaidMinor, currency),
                    ),
                    const Divider(),
                    AppValue(
                      label: 'Net after expenses and tax',
                      value: money(
                        summary.incomeMinor -
                            summary.expenseMinor -
                            summary.taxPaidMinor,
                        currency,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SpaceSize.large),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current position',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: SpaceSize.medium),
                    AppValue(
                      label: 'Account balances',
                      value: money(summary.totalBalanceMinor, currency),
                    ),
                    AppValue(
                      label: 'Owed to you',
                      value: money(summary.oweInMinor, currency),
                    ),
                    AppValue(
                      label: 'You owe',
                      value: money(summary.oweOutMinor, currency),
                    ),
                    AppValue(
                      label: 'Asset value',
                      value: money(summary.assetValueMinor, currency),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: SpaceSize.section),
        ],
      );
    },
  );
}
