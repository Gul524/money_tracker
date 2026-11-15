import 'package:flutter/material.dart';

import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/amount_calculator.dart';
import 'app_widgets.dart';

/// Opens the in-app calculator, seeded with [initialText] (the amount field's
/// current text). Returns the result in minor units when the user taps
/// "Use …", or null when dismissed.
Future<int?> showAmountCalculator(
  BuildContext context, {
  required String currency,
  String initialText = '',
  Color? color,
}) => showAppSheet<int>(
  context,
  builder: (_) => AmountCalculatorSheet(
    currency: currency,
    initialText: initialText,
    color: color,
  ),
);

class AmountCalculatorSheet extends StatefulWidget {
  const AmountCalculatorSheet({
    super.key,
    required this.currency,
    this.initialText = '',
    this.color,
  });
  final String currency;
  final String initialText;
  final Color? color;

  @override
  State<AmountCalculatorSheet> createState() => _AmountCalculatorSheetState();
}

class _AmountCalculatorSheetState extends State<AmountCalculatorSheet> {
  late final AmountCalculator calc = AmountCalculator(widget.initialText);

  void _do(VoidCallback action) => setState(action);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final result = calc.resultMinor;
    final problem = calc.problem;
    final usable = result != null && result > 0;

    String? note;
    if (problem != null) {
      note = problem;
    } else if (result != null && result <= 0) {
      note = 'The amount must be more than 0';
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SpaceSize.gutter,
          0,
          SpaceSize.gutter,
          SpaceSize.large,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Calculator', style: theme.textTheme.titleLarge),
            const SizedBox(height: SpaceSize.medium),
            _Display(
              expression: calc.isEmpty
                  ? 'Type an amount, then + − × ÷'
                  : calc.expression,
              hint: calc.isEmpty,
              result: result == null
                  ? null
                  : '${calc.hasOperation ? '= ' : ''}'
                        '${money(result, widget.currency)}',
              resultColor: result != null && result <= 0
                  ? colors.expense
                  : widget.color,
              note: note,
            ),
            const SizedBox(height: SpaceSize.medium),
            _Keypad(
              onDigit: (d) => _do(() => calc.inputDigit(d)),
              onOperator: (op) => _do(() => calc.inputOperator(op)),
              onBackspace: () => _do(calc.backspace),
              onClear: () => _do(calc.clear),
              onEquals: () => _do(calc.collapse),
            ),
            const SizedBox(height: SpaceSize.large),
            FilledButton(
              onPressed: usable
                  ? () => Navigator.of(context).pop(result)
                  : null,
              child: Text(
                usable ? 'Use ${money(result, widget.currency)}' : 'Use amount',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows what is being calculated and the live result.
class _Display extends StatelessWidget {
  const _Display({
    required this.expression,
    required this.hint,
    required this.result,
    required this.resultColor,
    required this.note,
  });
  final String expression;
  final bool hint;
  final String? result;
  final Color? resultColor;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const tabular = [FontFeature.tabularFigures()];
    return Container(
      padding: const EdgeInsets.all(CardSize.padding),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(RadiusSize.large),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              expression,
              key: const ValueKey('calculator-expression'),
              textAlign: TextAlign.end,
              style: theme.textTheme.titleMedium?.copyWith(
                color: hint ? scheme.outline : scheme.onSurfaceVariant,
                fontWeight: hint ? FontWeight.w400 : FontWeight.w500,
                fontFeatures: tabular,
              ),
            ),
          ),
          const SizedBox(height: SpaceSize.small),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              result ?? ' ',
              key: const ValueKey('calculator-result'),
              style: theme.textTheme.displaySmall?.copyWith(
                fontFeatures: tabular,
                color: resultColor ?? scheme.onSurface,
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: SpaceSize.extraSmall),
            Text(
              note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.of(context).expense,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _KeyStyle { digit, operator, action, equals }

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onOperator,
    required this.onBackspace,
    required this.onClear,
    required this.onEquals,
  });
  final ValueChanged<String> onDigit;
  final ValueChanged<CalcOp> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEquals;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) =>
        _Key(label: d, style: _KeyStyle.digit, onTap: () => onDigit(d));
    Widget op(CalcOp o, String name) => _Key(
      label: o.symbol,
      semanticLabel: name,
      style: _KeyStyle.operator,
      onTap: () => onOperator(o),
    );

    final rows = <List<Widget>>[
      [
        _Key(
          label: 'C',
          semanticLabel: 'Clear',
          style: _KeyStyle.action,
          onTap: onClear,
        ),
        _Key(
          icon: Icons.backspace_outlined,
          semanticLabel: 'Delete',
          style: _KeyStyle.action,
          onTap: onBackspace,
        ),
        op(CalcOp.divide, 'Divide'),
        op(CalcOp.multiply, 'Multiply'),
      ],
      [digit('7'), digit('8'), digit('9'), op(CalcOp.subtract, 'Minus')],
      [digit('4'), digit('5'), digit('6'), op(CalcOp.add, 'Plus')],
      [
        digit('1'),
        digit('2'),
        digit('3'),
        _Key(
          label: '=',
          semanticLabel: 'Equals',
          style: _KeyStyle.equals,
          onTap: onEquals,
        ),
      ],
      [digit('00'), digit('0'), digit('.'), const SizedBox.shrink()],
    ];
    // The last row's empty slot is filled by "=" spanning two rows below.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var col = 0; col < 4; col++) ...[
          if (col > 0) const SizedBox(width: SpaceSize.small),
          Expanded(
            child: Column(
              children: [
                for (var row = 0; row < rows.length; row++)
                  if (!(col == 3 && row == 4)) ...[
                    if (row > 0) const SizedBox(height: SpaceSize.small),
                    SizedBox(
                      height: col == 3 && row == 3
                          ? _Key.height * 2 + SpaceSize.small
                          : _Key.height,
                      child: rows[row][col],
                    ),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.semanticLabel,
    required this.style,
    required this.onTap,
  });
  static const height = 56.0;

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final _KeyStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final (background, foreground) = switch (style) {
      _KeyStyle.digit => (scheme.surface, scheme.onSurface),
      _KeyStyle.operator => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      _KeyStyle.action => (colors.neutralContainer, scheme.onSurface),
      _KeyStyle.equals => (scheme.primary, scheme.onPrimary),
    };
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.medium),
          side: style == _KeyStyle.digit
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: icon != null
                ? Icon(icon, color: foreground, size: IconSize.medium)
                : Text(
                    label!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontWeight: style == _KeyStyle.digit
                          ? FontWeight.w500
                          : FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
