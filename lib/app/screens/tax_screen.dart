import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/tax_rate.dart';
import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/tax_rate_controller.dart';
import '../widgets/app_widgets.dart';

/// Settings › Tax: the taxes picked on income and expense entries.
class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  late final TaxRateController controller;

  @override
  void initState() {
    super.initState();
    controller = TaxRateController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _edit([TaxRate? existing]) =>
      showTaxEditor(context, controller: controller, existing: existing);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Tax')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add tax'),
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
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No taxes yet',
              message:
                  'Add the taxes you pay or charge, like sales tax or income '
                  'tax. Pick one on an entry and it’s worked out for you.',
              actionLabel: 'Add tax',
              onAction: () => _edit(),
            )
          else ...[
            GroupedCard(
              children: [
                for (final t in controller.items)
                  AppTile(
                    leading: TaxCodeBadge(t.code),
                    title: t.name,
                    subtitle:
                        '${formatRate(t.rateBasisPoints)} · '
                        '${t.inclusive ? 'Included in amount' : 'Added on top'}',
                    onTap: () => _edit(t),
                  ),
              ],
            ),
            const InfoNote(
              'Changing or deleting a tax doesn’t change entries you have '
              'already saved.',
            ),
          ],
        ],
      ),
    ),
  );
}

/// The tax code in a tinted rounded square, e.g. `GST`.
class TaxCodeBadge extends StatelessWidget {
  const TaxCodeBadge(
    this.code, {
    super.key,
    this.size = ComponentSize.iconBadge,
  });
  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Text(
        code,
        maxLines: 1,
        style: TextStyle(
          color: colors.warning,
          fontWeight: FontWeight.w700,
          fontSize: size * .28,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

/// Opens the add/edit tax sheet.
Future<void> showTaxEditor(
  BuildContext context, {
  required TaxRateController controller,
  TaxRate? existing,
}) async {
  controller.clearError();
  var name = existing?.name ?? '';
  var code = existing?.code ?? '';
  var percentage = existing == null
      ? ''
      : percentageInputText(existing.rateBasisPoints);
  var inclusive = existing?.inclusive ?? false;

  await showAppSheet<void>(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => SheetScaffold(
          title: existing == null ? 'New tax' : 'Edit tax',
          error: controller.error,
          busy: controller.busy,
          primaryLabel: 'Save',
          onPrimary: () async {
            final ok = await controller.save(
              id: existing?.id,
              name: name,
              code: code,
              percentage: percentage,
              inclusive: inclusive,
            );
            if (ok && sheetContext.mounted) Navigator.pop(sheetContext);
          },
          destructiveLabel: existing == null ? null : 'Delete tax',
          onDestructive: () async {
            final confirmed = await confirmDelete(
              context,
              title: 'Delete ${existing!.name}?',
              message:
                  'Entries already saved with it keep their tax. This can’t '
                  'be undone.',
            );
            if (confirmed &&
                await controller.remove(existing.id!) &&
                sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }
          },
          children: [
            AppTextField(
              label: 'Tax name',
              hint: 'e.g. Sales tax, Income tax',
              value: name,
              capitalization: TextCapitalization.words,
              onChanged: (v) => name = v,
            ),
            const SizedBox(height: SpaceSize.large),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: code,
                    onChanged: (v) => code = v,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      _UpperCaseFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: 'GST',
                      helperText: '3 letters',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: SpaceSize.medium),
                Expanded(
                  child: TextFormField(
                    initialValue: percentage,
                    onChanged: (v) => percentage = v,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,3}\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Percentage',
                      hintText: '17',
                      suffixText: '%',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpaceSize.small),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Amounts include this tax'),
              subtitle: Text(
                inclusive
                    ? 'The amount you type already has the tax in it.'
                    : 'The tax is added on top of the amount you type.',
              ),
              value: inclusive,
              onChanged: (v) => setSheetState(() => inclusive = v ?? false),
            ),
            const InfoNote(
              'You can still change this on each entry. Saved entries keep '
              'the tax they were saved with.',
            ),
          ],
        ),
      ),
    ),
  );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
