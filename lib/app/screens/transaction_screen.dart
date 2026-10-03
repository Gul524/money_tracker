import 'package:flutter/material.dart';

import '../../data/models/money_transaction.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/transaction_controller.dart';
import '../widgets/app_widgets.dart';
import 'category_screen.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({
    super.key,
    required this.services,
    this.existing,
    this.isViewOnly = false,
  });
  final AppServices services;
  final MoneyTransaction? existing;
  final bool isViewOnly;
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  late final TransactionController controller;
  @override
  void initState() {
    super.initState();
    controller = TransactionController(
      widget.services,
      existing: widget.existing,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await controller.save() && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'New transaction'
              : widget.isViewOnly
              ? 'Transaction'
              : 'Edit transaction',
        ),
        actions: widget.existing == null || widget.isViewOnly
            ? null
            : [
                IconButton(
                  tooltip: 'Delete transaction',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!await confirmDelete(context, 'transaction')) return;
                    if (await controller.remove() && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SpaceSize.extraLarge,
          SpaceSize.compact,
          SpaceSize.extraLarge,
          SpaceSize.formBottom,
        ),
        children: [
          Text(
            'Record money clearly',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpaceSize.header),
          AppPanel(
            child: Column(
              children: [
                AppSelect<EntryKind>(
                  label: 'Type',
                  value: controller.kind,
                  items: const {
                    EntryKind.expense: 'Expense',
                    EntryKind.income: 'Income',
                    EntryKind.oweIn: 'Owed to me',
                    EntryKind.oweOut: 'I owe',
                    EntryKind.tax: 'Tax paid',
                  },
                  onChanged: (v) {
                    if (v != null) controller.setKind(v);
                  },
                  isViewOnly: widget.isViewOnly || widget.existing != null,
                ),
                const SizedBox(height: SpaceSize.form),
                AppInput(
                  label: 'Amount (${widget.services.currencyCode})',
                  value: controller.amountText,
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: controller.setAmount,
                  isViewOnly: widget.isViewOnly,
                ),
                if (!controller.isTax) ...[
                  const SizedBox(height: SpaceSize.form),
                  AppSelect<int>(
                    key: ValueKey(controller.kind),
                    label: 'Category',
                    value: controller.categoryId,
                    items: {
                      for (final c in controller.availableCategories)
                        c.id!: controller.pathFor(c),
                    },
                    onChanged: controller.setCategory,
                    isViewOnly: widget.isViewOnly,
                  ),
                  if (!widget.isViewOnly)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CategoryScreen(services: widget.services),
                            ),
                          );
                          controller.refresh();
                        },
                        icon: const Icon(Icons.add, size: IconSize.extraSmall),
                        label: const Text('Manage categories'),
                      ),
                    ),
                ],
                AppSelect<int>(
                  label: controller.isOwe
                      ? 'Settlement account (optional)'
                      : 'Account',
                  value: controller.accountId,
                  allowClear: controller.isOwe,
                  items: {for (final a in controller.accounts) a.id!: a.name},
                  onChanged: controller.setAccount,
                  isViewOnly: widget.isViewOnly,
                ),
                const SizedBox(height: SpaceSize.extraSmall),
                AppDateField(
                  label: 'Date',
                  value: controller.occurredAt,
                  onChanged: (d) {
                    if (d != null) controller.setDate(d);
                  },
                  isViewOnly: widget.isViewOnly,
                ),
                if (controller.isOwe) ...[
                  AppInput(
                    label: 'Person or business',
                    value: controller.party,
                    onChanged: controller.setParty,
                    isViewOnly: widget.isViewOnly,
                  ),
                  AppDateField(
                    label: 'Due date',
                    value: controller.dueAt,
                    onChanged: controller.setDueDate,
                    optional: true,
                    isViewOnly: widget.isViewOnly,
                  ),
                ],
                AppInput(
                  label: 'Note (optional)',
                  value: controller.note,
                  onChanged: controller.setNote,
                  maxLines: 2,
                  isViewOnly: widget.isViewOnly,
                ),
              ],
            ),
          ),
          const SizedBox(height: SpaceSize.form),
          AppError(controller.error),
          if (!widget.isViewOnly)
            FilledButton(
              onPressed: controller.busy ? null : _save,
              child: Padding(
                padding: const EdgeInsets.all(SpaceSize.form),
                child: Text(controller.busy ? 'Saving…' : 'Save transaction'),
              ),
            ),
        ],
      ),
    ),
  );
}
