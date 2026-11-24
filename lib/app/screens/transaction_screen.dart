import 'package:flutter/material.dart';

import '../../data/models/model_types.dart';
import '../../data/models/money_transaction.dart';
import '../../data/models/tax_payment.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import 'owe_settle_sheet.dart';
import '../controllers/transaction_controller.dart';
import '../widgets/app_widgets.dart';
import '../../data/models/tax_rate.dart';
import 'category_screen.dart';
import 'tax_screen.dart';

/// Add or edit an income, expense, owe or tax payment. Income and expense
/// can also record tax paid with them.
class TransactionScreen extends StatefulWidget {
  const TransactionScreen({
    super.key,
    required this.services,
    this.existing,
    this.existingTax,
    this.initialKind = EntryKind.expense,
  });
  final AppServices services;
  final MoneyTransaction? existing;

  /// A standalone tax payment to edit.
  final TaxPayment? existingTax;
  final EntryKind initialKind;
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

const _kindLabels = {
  EntryKind.expense: 'Expense',
  EntryKind.income: 'Income',
  EntryKind.oweIn: 'Owed to me',
  EntryKind.oweOut: 'I owe',
  EntryKind.tax: 'Tax',
};

class _TransactionScreenState extends State<TransactionScreen> {
  late final TransactionController controller;
  late final TextEditingController amount;
  int _amountRevision = 0;

  bool get _editing => widget.existing != null || widget.existingTax != null;

  @override
  void initState() {
    super.initState();
    controller = TransactionController(
      widget.services,
      existing: widget.existing,
      existingTax: widget.existingTax,
      initialKind: widget.initialKind,
    );
    amount = TextEditingController(text: controller.amountText);
    controller.addListener(_syncAmount);
  }

  /// An edited entry's amount is shown with or without its tax once the
  /// tax has loaded.
  void _syncAmount() {
    if (controller.amountRevision == _amountRevision) return;
    _amountRevision = controller.amountRevision;
    amount.text = controller.amountText;
  }

  @override
  void dispose() {
    amount.dispose();
    controller.dispose();
    super.dispose();
  }

  String get _title {
    final verb = _editing ? 'Edit' : 'Add';
    return switch (controller.kind) {
      EntryKind.expense => '$verb expense',
      EntryKind.income => '$verb income',
      EntryKind.oweIn =>
        _editing ? 'Edit money owed to you' : 'Someone owes me',
      EntryKind.oweOut => _editing ? 'Edit money you owe' : 'I owe someone',
      EntryKind.tax => '$verb tax payment',
    };
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (await controller.save() && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final linkedTax = controller.canHaveTax && controller.taxMinor > 0;
    final hasItem = controller.exchange == OweExchange.item;
    final item = controller.kind == EntryKind.oweIn
        ? controller.givenAsset?.name
        : controller.receivedItem.trim();
    final itemNote = !hasItem || (item ?? '').isEmpty
        ? ''
        : controller.kind == EntryKind.oweIn
        ? '$item comes back to your assets. '
        : '$item stays in your assets. ';
    if (!await confirmDelete(
      context,
      title: 'Delete this entry?',
      message: linkedTax
          ? 'The tax recorded with it is deleted too. This can’t be undone.'
          : '${itemNote}This can’t be undone.',
    )) {
      return;
    }
    if (await controller.remove() && mounted) Navigator.of(context).pop(true);
  }

  /// Explains how the tax changes the account, e.g. "Rs 1,170.00 leaves
  /// Cash: Rs 1,000.00 plus Rs 170.00 tax."
  String _taxSummary(String currency) {
    final split = controller.taxSplit;
    final account = controller.selectedAccount?.name ?? 'the account';
    if (controller.kind == EntryKind.income) {
      return '$account receives ${money(split.subtotalMinor, currency)}: '
          '${money(split.totalMinor, currency)} minus '
          '${money(split.taxMinor, currency)} tax.';
    }
    return '${money(split.totalMinor, currency)} leaves $account: '
        '${money(split.subtotalMinor, currency)} plus '
        '${money(split.taxMinor, currency)} tax.';
  }

  static const _noTax = -1;
  static const _customTax = -2;

  /// Picks a managed tax, a custom amount or no tax. For a standalone tax
  /// payment it only names the tax.
  Future<void> _pickTax() async {
    final standalone = controller.isTax;
    final selected = switch (controller.taxMode) {
      _ when standalone => controller.selectedTax?.taxRateId ?? _noTax,
      TaxMode.none => _noTax,
      TaxMode.custom => _customTax,
      TaxMode.rate => controller.selectedTax?.taxRateId,
    };
    final picked = await showPickerSheet<int>(
      context,
      title: standalone ? 'Which tax?' : 'Tax',
      selected: selected,
      options: [
        PickerOption(
          value: _noTax,
          title: standalone ? 'Not specified' : 'No tax',
          icon: Icons.block_rounded,
        ),
        for (final t in controller.taxRates)
          PickerOption(
            value: t.id!,
            title: t.name,
            subtitle:
                '${formatRate(t.rateBasisPoints)} · '
                '${t.inclusive ? 'Included in amount' : 'Added on top'}',
            leading: TaxCodeBadge(t.code),
          ),
        if (!standalone)
          const PickerOption(
            value: _customTax,
            title: 'Custom amount',
            subtitle: 'Type the tax yourself',
            icon: Icons.edit_outlined,
          ),
      ],
      footerLabel: 'Manage taxes',
      onFooter: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TaxScreen(services: widget.services),
          ),
        );
        controller.refresh();
      },
    );
    if (picked == null) return;
    if (picked == _noTax) {
      controller.clearTax();
    } else if (picked == _customTax) {
      controller.setCustomTax();
    } else {
      final rate = controller.taxRates.where((t) => t.id == picked).firstOrNull;
      if (rate != null) controller.setTaxRate(rate);
    }
  }

  List<Widget> _taxSection(String currency) {
    final hasTax = controller.taxMode != TaxMode.none;
    final split = controller.taxSplit;
    return [
      GroupedCard(
        dividerIndent: 56,
        children: [
          FormRow(
            icon: Icons.receipt_long_outlined,
            label: 'Tax',
            placeholder: 'None',
            value: switch (controller.taxMode) {
              TaxMode.none => null,
              TaxMode.custom => 'Custom amount',
              TaxMode.rate => controller.taxLabel,
            },
            onTap: _pickTax,
            onClear: hasTax ? controller.clearTax : null,
          ),
          if (controller.taxMode == TaxMode.custom)
            FormTextRow(
              // Rebuild once an edited entry's saved tax has loaded.
              key: ValueKey('tax-${controller.taxLoaded}'),
              icon: Icons.edit_outlined,
              hint: 'Tax amount',
              value: controller.taxText,
              onChanged: controller.setTax,
              amount: true,
              prefixText: '${currencySymbol(currency)} ',
              suffixText: 'tax',
            ),
          if (hasTax)
            CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Amount includes tax'),
              subtitle: Text(
                controller.taxInclusive
                    ? 'Tax is taken out of the amount'
                    : 'Tax is added on top of the amount',
              ),
              value: controller.taxInclusive,
              onChanged: (v) => controller.setTaxInclusive(v ?? false),
            ),
        ],
      ),
      if (hasTax) ...[
        const SizedBox(height: SpaceSize.medium),
        GroupedCard(
          children: [
            _TotalRow(
              label: 'Subtotal',
              minor: split.subtotalMinor,
              currency: currency,
            ),
            _TotalRow(
              label: switch (controller.taxMode) {
                TaxMode.rate => 'Tax (${controller.taxLabel})',
                _ => 'Tax',
              },
              minor: split.taxMinor,
              currency: currency,
            ),
            _TotalRow(
              label: 'Total',
              minor: split.totalMinor,
              currency: currency,
              strong: true,
            ),
          ],
        ),
      ],
      const SizedBox(height: SpaceSize.medium),
    ];
  }

  Future<void> _pickCategory() async {
    final picked = await showPickerSheet<int>(
      context,
      title: 'Category',
      selected: controller.categoryId,
      emptyMessage: 'No categories for this type yet.',
      options: [
        for (final c
            in controller.availableCategories..sort(
              (a, b) => controller.pathFor(a).compareTo(controller.pathFor(b)),
            ))
          PickerOption(
            value: c.id!,
            title: c.name,
            subtitle: c.parentId == null
                ? null
                : controller.pathFor(c).replaceFirst(RegExp(r' / [^/]+$'), ''),
            leading: CategoryBadge(
              name: c.name,
              iconKey: c.icon,
              colorHex: c.color,
              income: controller.isIncome,
            ),
          ),
      ],
      footerLabel: 'Manage categories',
      onFooter: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoryScreen(services: widget.services),
          ),
        );
        controller.refresh();
      },
    );
    if (picked != null) controller.setCategory(picked);
  }

  Future<void> _pickAccount({bool exchange = false}) async {
    final picked = await showPickerSheet<int>(
      context,
      title: exchange
          ? (controller.kind == EntryKind.oweIn
                ? 'Money left which wallet?'
                : 'Money went into which wallet?')
          : 'Account',
      selected: exchange ? controller.exchangeAccountId : controller.accountId,
      emptyMessage: 'Add an account in Settings › Accounts first.',
      options: [
        for (final a in controller.accounts)
          PickerOption(
            value: a.id!,
            title: a.name,
            subtitle:
                'Balance ${money(controller.balances[a.id] ?? 0, widget.services.currencyCode)}',
            icon: a.type == AccountType.bank
                ? Icons.account_balance_outlined
                : Icons.payments_outlined,
          ),
      ],
    );
    if (picked == null) return;
    if (exchange) {
      controller.setExchangeAccount(picked);
    } else {
      controller.setAccount(picked);
    }
  }

  Future<void> _pickGivenAsset() async {
    final currency = widget.services.currencyCode;
    final picked = await showPickerSheet<int>(
      context,
      title: 'Which item did you give?',
      selected: controller.givenAssetId,
      emptyMessage:
          'You have no assets yet. Add the item in Settings › Assets first.',
      options: [
        for (final a in controller.assets)
          PickerOption(
            value: a.id!,
            title: a.name,
            subtitle: 'Worth ${money(a.currentValueMinor, currency)}',
            icon: Icons.inventory_2_outlined,
          ),
      ],
    );
    if (picked != null) controller.setGivenAsset(picked);
  }

  /// Plain-language effect of an owe, by what was exchanged.
  String _oweNote(String currency) {
    final amount = money(controller.amountMinor ?? 0, currency);
    final incoming = controller.kind == EntryKind.oweIn;
    switch (controller.exchange) {
      case OweExchange.money:
        final wallet = controller.exchangeAccount?.name ?? 'the wallet';
        return incoming
            ? '$amount leaves $wallet now and comes back when you mark it as received.'
            : '$amount is added to $wallet now and leaves when you mark it as paid.';
      case OweExchange.item:
        if (incoming) {
          final item = controller.givenAsset?.name ?? 'The item';
          return '$item leaves your assets now. You get $amount when it’s '
              'paid back.';
        }
        final item = controller.receivedItem.trim().isEmpty
            ? 'The item'
            : controller.receivedItem.trim();
        return '$item is added to your assets worth $amount. The money '
            'leaves when you mark it as paid.';
      case OweExchange.none:
        return 'Owed money doesn’t change your balance until you mark it as '
            'paid from the Money owed screen.';
    }
  }

  List<Widget> _exchangeSection(String currency) {
    final incoming = controller.kind == EntryKind.oweIn;
    return [
      SectionHeader(
        incoming
            ? 'What did you give them? (optional)'
            : 'What did you get from them? (optional)',
        padding: const EdgeInsets.fromLTRB(
          SpaceSize.extraSmall,
          SpaceSize.small,
          0,
          SpaceSize.small,
        ),
      ),
      SegmentedButton<OweExchange>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: OweExchange.none, label: Text('None')),
          ButtonSegment(value: OweExchange.money, label: Text('Money')),
          ButtonSegment(value: OweExchange.item, label: Text('Item')),
        ],
        selected: {controller.exchange},
        onSelectionChanged: (v) => controller.setExchange(v.first),
      ),
      if (controller.exchange != OweExchange.none) ...[
        const SizedBox(height: SpaceSize.medium),
        GroupedCard(
          dividerIndent: 56,
          children: [
            if (controller.exchange == OweExchange.money)
              FormRow(
                icon: incoming
                    ? Icons.north_east_rounded
                    : Icons.south_west_rounded,
                label: incoming ? 'Lent from' : 'Borrowed into',
                value: controller.exchangeAccount?.name,
                onTap: () => _pickAccount(exchange: true),
              )
            else if (incoming)
              FormRow(
                icon: Icons.inventory_2_outlined,
                label: 'Item given',
                value: controller.givenAsset?.name,
                onTap: _pickGivenAsset,
              )
            else
              FormTextRow(
                // Rebuild once an edited entry's item has loaded.
                key: ValueKey('item-${controller.itemLoaded}'),
                icon: Icons.inventory_2_outlined,
                hint: 'What did you get? e.g. Laptop',
                value: controller.receivedItem,
                onChanged: controller.setReceivedItem,
                capitalization: TextCapitalization.sentences,
              ),
          ],
        ),
      ],
      const SizedBox(height: SpaceSize.medium),
    ];
  }

  /// Pay/receive button and the part payments of the owe being edited.
  List<Widget> _payments(String currency) {
    final owe = widget.existing;
    if (owe == null || owe.parentId != null) return const [];
    final incoming = owe.type == TransactionType.oweIn;
    final pending = owe.oweStatus == OweStatus.pending;
    final paid = controller.parts.fold<int>(0, (s, p) => s + p.amountMinor);
    return [
      if (pending)
        Padding(
          padding: const EdgeInsets.only(top: SpaceSize.section),
          child: FilledButton.tonalIcon(
            icon: Icon(
              incoming ? Icons.call_received_rounded : Icons.call_made_rounded,
            ),
            label: Text(incoming ? 'Receive money' : 'Pay money'),
            onPressed: () async {
              if (await showOweSettleSheet(context, widget.services, owe) &&
                  mounted) {
                // The form still holds the old amount; saving it would undo the payment.
                Navigator.of(context).pop(false);
              }
            },
          ),
        ),
      if (controller.parts.isNotEmpty) ...[
        SectionHeader(
          incoming
              ? 'Received so far · ${money(paid, currency)}'
              : 'Paid so far · ${money(paid, currency)}',
        ),
        OwePaymentsCard(payments: controller.parts, currency: currency),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final colors = AppColors.of(context);
      final currency = widget.services.currencyCode;
      final category = controller.selectedCategory;
      final amountColor = switch (controller.kind) {
        EntryKind.income => colors.income,
        _ => theme.colorScheme.onSurface,
      };

      return Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: [
            if (_editing)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: controller.busy ? null : _delete,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.gutter,
            SpaceSize.small,
            SpaceSize.gutter,
            SpaceSize.large,
          ),
          children: [
            if (!_editing) ...[
              _KindSelector(
                value: controller.kind,
                onChanged: controller.setKind,
              ),
              const SizedBox(height: SpaceSize.section),
            ] else
              const SizedBox(height: SpaceSize.large),
            AmountField(
              controller: amount,
              currency: currency,
              color: amountColor,
              autofocus: !_editing,
              onChanged: controller.setAmount,
            ),
            const SizedBox(height: SpaceSize.section),
            GroupedCard(
              dividerIndent: 56,
              children: [
                if (!controller.isTax)
                  FormRow(
                    icon: Icons.sell_outlined,
                    leading: category == null
                        ? null
                        : CategoryBadge(
                            name: category.name,
                            iconKey: category.icon,
                            colorHex: category.color,
                            income: controller.isIncome,
                            size: 28,
                          ),
                    label: 'Category',
                    value: category?.name,
                    onTap: _pickCategory,
                  ),
                FormRow(
                  icon: Icons.account_balance_wallet_outlined,
                  // For owes: where the repayment lands / comes from;
                  // optional, so it reads "Later" until chosen.
                  label: switch (controller.kind) {
                    EntryKind.oweIn => 'Repaid into',
                    EntryKind.oweOut => 'Repay from',
                    _ => 'Account',
                  },
                  placeholder: controller.isOwe ? 'Later' : 'Choose',
                  value: controller.selectedAccount?.name,
                  onTap: _pickAccount,
                  onClear: controller.isOwe
                      ? () => controller.setAccount(null)
                      : null,
                ),
                FormRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: relativeDay(controller.occurredAt) == 'Today'
                      ? 'Today'
                      : formatDate(controller.occurredAt),
                  onTap: () async {
                    final d = await pickDay(context, controller.occurredAt);
                    if (d != null) controller.setDate(d);
                  },
                ),
                FormRow(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value: formatTime(controller.occurredAt),
                  onTap: () async {
                    final d = await pickTime(context, controller.occurredAt);
                    if (d != null) controller.setDate(d);
                  },
                ),
                if (controller.isOwe)
                  FormRow(
                    icon: Icons.event_outlined,
                    label: 'Due date',
                    value: controller.dueAt == null
                        ? null
                        : formatDate(controller.dueAt!),
                    placeholder: 'None',
                    onTap: () async {
                      final d = await pickDate(context, controller.dueAt);
                      if (d != null) controller.setDueDate(d);
                    },
                    onClear: () => controller.setDueDate(null),
                  ),
              ],
            ),
            const SizedBox(height: SpaceSize.medium),
            if (controller.isOwe) ..._exchangeSection(currency),
            if (controller.canHaveTax) ..._taxSection(currency),
            if (controller.isTax) ...[
              GroupedCard(
                dividerIndent: 56,
                children: [
                  FormRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Tax type',
                    placeholder: 'Optional',
                    value: controller.selectedTax?.name,
                    onTap: _pickTax,
                    onClear: controller.selectedTax == null
                        ? null
                        : controller.clearTax,
                  ),
                ],
              ),
              const SizedBox(height: SpaceSize.medium),
            ],
            GroupedCard(
              dividerIndent: 56,
              children: [
                if (controller.isOwe)
                  FormTextRow(
                    icon: Icons.person_outline_rounded,
                    hint: controller.kind == EntryKind.oweIn
                        ? 'Who owes you?'
                        : 'Who do you owe?',
                    value: controller.party,
                    onChanged: controller.setParty,
                    capitalization: TextCapitalization.words,
                  ),
                FormTextRow(
                  icon: Icons.notes_rounded,
                  hint: 'Add a note (optional)',
                  value: controller.note,
                  onChanged: controller.setNote,
                  maxLines: 3,
                ),
              ],
            ),
            if (controller.isOwe) ..._payments(currency),
            if (controller.isOwe) InfoNote(_oweNote(currency)),
            if (controller.canHaveTax && controller.taxMinor > 0)
              InfoNote(_taxSummary(currency)),
            if (controller.isTax)
              const InfoNote(
                'Tax is deducted from the chosen account and shown separately '
                'from your expenses.',
              ),
            ErrorBanner(controller.error),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: FilledButton(
            onPressed: controller.busy ? null : _save,
            child: Text(controller.busy ? 'Saving…' : 'Save'),
          ),
        ),
      );
    },
  );
}

/// One line of the Subtotal / Tax / Total breakdown.
class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.minor,
    required this.currency,
    this.strong = false,
  });
  final String label;
  final int minor;
  final String currency;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = strong
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpaceSize.large,
        vertical: SpaceSize.medium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: SpaceSize.medium),
          AmountText(minor, currency: currency, style: style),
        ],
      ),
    );
  }
}

class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.value, required this.onChanged});
  final EntryKind value;
  final ValueChanged<EntryKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in _kindLabels.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: entry.key == value,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: scheme.onSurface,
              labelStyle: TextStyle(
                color: entry.key == value ? scheme.surface : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: SpaceSize.small),
          ],
        ],
      ),
    );
  }
}
