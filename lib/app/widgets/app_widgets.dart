import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/model_types.dart';
import '../../data/services/activity_service.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../formatters.dart';
import 'category_icons.dart';

export '../formatters.dart';
export 'category_icons.dart';

const _tabular = [FontFeature.tabularFigures()];

// ---------------------------------------------------------------------------
// Layout building blocks
// ---------------------------------------------------------------------------

/// Title above a grouped section, with an optional trailing text action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      SpaceSize.extraSmall,
      SpaceSize.section,
      0,
      SpaceSize.small,
    ),
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    ),
  );
}

/// An inset-grouped card: rows separated by hairline dividers that align with
/// the row text (the pattern used by iOS Settings and Google Wallet).
class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.children,
    this.dividerIndent = ComponentSize.tileDividerIndent,
  });
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(indent: dividerIndent),
          children[i],
        ],
      ],
    ),
  );
}

/// Rounded-square tinted container for an icon.
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color,
    this.background,
    this.size = ComponentSize.iconBadge,
  });
  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? AppColors.of(context).neutralContainer,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(
        icon,
        size: size * .5,
        color: color ?? scheme.onSurfaceVariant,
      ),
    );
  }
}

/// Standard tappable row: leading, title/subtitle, trailing, chevron.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.subtitleColor,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpaceSize.large,
            vertical: SpaceSize.medium,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: SpaceSize.medium),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: SpaceSize.tiny),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: SpaceSize.small),
                trailing!,
              ],
              if (onTap != null && showChevron) ...[
                const SizedBox(width: SpaceSize.extraSmall),
                Icon(
                  Icons.chevron_right_rounded,
                  size: IconSize.medium,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Form row in the iOS "label ... value >" style used inside a [GroupedCard].
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.placeholder = 'Choose',
    this.onTap,
    this.onClear,
    this.leading,
    this.valueLeading,
  });
  final IconData icon;

  /// Replaces [icon] (e.g. a small [CategoryBadge]).
  final Widget? leading;

  /// Shown just before the value text (e.g. a color swatch).
  final Widget? valueLeading;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpaceSize.large),
          child: Row(
            children: [
              leading ??
                  Icon(
                    icon,
                    size: IconSize.large,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              const SizedBox(width: SpaceSize.large),
              Text(label, style: theme.textTheme.bodyLarge),
              const SizedBox(width: SpaceSize.medium),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (valueLeading != null) ...[
                      valueLeading!,
                      const SizedBox(width: SpaceSize.small),
                    ],
                    Flexible(
                      child: Text(
                        hasValue ? value! : placeholder,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: hasValue
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.primary,
                          fontWeight: hasValue
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasValue && onClear != null)
                IconButton(
                  tooltip: 'Clear $label',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: IconSize.small),
                  onPressed: onClear,
                )
              else if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: SpaceSize.extraSmall),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: IconSize.medium,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Borderless text input row for use inside a [GroupedCard].
class FormTextRow extends StatelessWidget {
  const FormTextRow({
    super.key,
    required this.icon,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.sentences,
    this.amount = false,
    this.prefixText,
    this.suffixText,
  });
  final IconData icon;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextCapitalization capitalization;

  /// Numeric keyboard limited to 2 decimals.
  final bool amount;
  final String? prefixText;

  /// Stays visible after typing, so the row keeps its meaning.
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpaceSize.large),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? SpaceSize.large : 0),
            child: Icon(
              icon,
              size: IconSize.large,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: SpaceSize.large),
          Expanded(
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              minLines: 1,
              maxLines: maxLines,
              textCapitalization: capitalization,
              keyboardType: amount
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : null,
              inputFormatters: amount
                  ? [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ]
                  : null,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: hint,
                prefixText: prefixText,
                suffixText: suffixText,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: SpaceSize.large,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled text field with a floating label, for editor sheets.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.helper,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixText,
    this.capitalization = TextCapitalization.sentences,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? prefixText;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value,
    onChanged: onChanged,
    keyboardType: keyboardType,
    maxLines: maxLines,
    textCapitalization: capitalization,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixText: prefixText,
    ),
  );
}

/// Large, centered amount entry used at the top of money forms — the
/// pattern used by Google Pay and Apple Cash.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.currency,
    required this.onChanged,
    this.color,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final String currency;
  final ValueChanged<String> onChanged;
  final Color? color;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displaySmall?.copyWith(
      fontSize: TextSize.amountInput,
      fontFeatures: _tabular,
      color: color ?? theme.colorScheme.onSurface,
    );
    return Column(
      children: [
        Text('Amount', style: theme.textTheme.bodySmall),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              currencySymbol(currency),
              style: style?.copyWith(
                fontSize: TextSize.headline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: SpaceSize.small),
            IntrinsicWidth(
              child: TextField(
                controller: controller,
                autofocus: autofocus,
                onChanged: onChanged,
                textAlign: TextAlign.center,
                style: style,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: style?.copyWith(color: theme.colorScheme.outline),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Money display
// ---------------------------------------------------------------------------

enum AmountTone { neutral, income, expense, muted }

class AmountText extends StatelessWidget {
  const AmountText(
    this.minor, {
    super.key,
    required this.currency,
    this.tone = AmountTone.neutral,
    this.signed = false,
    this.style,
  });
  final int minor;
  final String currency;
  final AmountTone tone;
  final bool signed;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final color = switch (tone) {
      AmountTone.neutral => theme.colorScheme.onSurface,
      AmountTone.income => colors.income,
      AmountTone.expense => colors.expense,
      AmountTone.muted => theme.colorScheme.onSurfaceVariant,
    };
    return Text(
      money(minor, currency, signed: signed),
      maxLines: 1,
      style: (style ?? theme.textTheme.bodyLarge)?.copyWith(
        color: color,
        fontWeight: style?.fontWeight ?? FontWeight.w600,
        fontFeatures: _tabular,
      ),
    );
  }
}

/// One row of the activity feed, shared by Home and History.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.item,
    required this.currency,
    this.onTap,
    this.showDate = true,
    this.accountId,
  });
  final ActivityItem item;
  final String currency;
  final VoidCallback? onTap;
  final bool showDate;

  /// When shown inside one account, transfers display as +/− for it and the
  /// account name is left out.
  final int? accountId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = item.transaction;
    final (icon, fg, bg) = switch (item.kind) {
      ActivityKind.transfer => (
        Icons.swap_horiz_rounded,
        colors.transfer,
        colors.transferContainer,
      ),
      ActivityKind.tax => (
        Icons.account_balance_outlined,
        colors.warning,
        colors.warningContainer,
      ),
      ActivityKind.transaction => switch (t!.type) {
        TransactionType.income => (
          categoryIcon(item.title, income: true),
          colors.income,
          colors.incomeContainer,
        ),
        TransactionType.expense => (
          categoryIcon(item.title),
          scheme.onSurfaceVariant,
          colors.neutralContainer,
        ),
        TransactionType.oweIn || TransactionType.oweOut => (
          Icons.handshake_outlined,
          colors.warning,
          colors.warningContainer,
        ),
      },
    };
    final isTransfer = item.kind == ActivityKind.transfer;
    // Income and expense rows wear their category's own icon and color.
    final isCategoryEntry =
        t?.type == TransactionType.income || t?.type == TransactionType.expense;
    final amount = isTransfer && accountId != null
        ? item.effectOn(accountId!)
        : item.amountMinor;
    final tone = item.isPending || isTransfer
        ? AmountTone.muted
        : amount > 0
        ? AmountTone.income
        : AmountTone.neutral;
    final party = t?.party?.trim() ?? '';
    final isOwe =
        t?.type == TransactionType.oweIn || t?.type == TransactionType.oweOut;
    // For money owed, the person matters more than the category.
    final title = isOwe && party.isNotEmpty ? party : item.title;
    final detail = [
      if (isTransfer) item.accountName ?? item.subtitle else item.subtitle,
      if (isOwe && party.isNotEmpty) item.title,
      if (!isTransfer && accountId == null && item.accountName != null)
        item.accountName!,
      if (item.taxMinor > 0) 'Tax ${money(item.taxMinor, currency)}',
      if (showDate) relativeDay(item.date),
    ].join(' · ');

    return AppTile(
      leading: isCategoryEntry
          ? CategoryBadge(
              name: item.title,
              iconKey: item.categoryIcon,
              colorHex: item.categoryColor,
              income: t!.type == TransactionType.income,
            )
          : IconBadge(icon, color: fg, background: bg),
      title: title,
      subtitle: detail,
      showChevron: false,
      onTap: onTap,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          AmountText(
            amount,
            currency: currency,
            tone: tone,
            signed: !isTransfer || accountId != null,
          ),
          if (item.isPending)
            Padding(
              padding: const EdgeInsets.only(top: SpaceSize.tiny),
              child: StatusPill('Pending', color: colors.warning),
            ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: SpaceSize.small,
      vertical: SpaceSize.tiny,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(RadiusSize.small),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

// ---------------------------------------------------------------------------
// Feedback
// ---------------------------------------------------------------------------

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpaceSize.large,
        vertical: SpaceSize.huge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon, size: 56),
          const SizedBox(height: SpaceSize.large),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: SpaceSize.extraSmall),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: SpaceSize.large),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, ComponentSize.minTouchTarget),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline error message; renders nothing when [message] is null.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpaceSize.small),
      child: Container(
        padding: const EdgeInsets.all(SpaceSize.medium),
        decoration: BoxDecoration(
          color: colors.expenseContainer,
          borderRadius: BorderRadius.circular(RadiusSize.medium),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: IconSize.medium,
              color: colors.expense,
            ),
            const SizedBox(width: SpaceSize.small),
            Expanded(
              child: Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.expense),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small explanatory note in muted text with an info icon.
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpaceSize.extraSmall,
        vertical: SpaceSize.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: IconSize.small,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: SpaceSize.small),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String message = 'This can’t be undone.',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

// ---------------------------------------------------------------------------
// Sheets
// ---------------------------------------------------------------------------

/// Opens a scrollable bottom sheet that moves above the keyboard.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: builder(sheetContext),
  ),
);

/// Standard editor-sheet layout: title, fields, error, primary button and an
/// optional destructive action at the bottom.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.subtitle,
    this.error,
    this.busy = false,
    this.destructiveLabel,
    this.onDestructive,
    this.secondaryLabel,
    this.onSecondary,
  });
  final String title;
  final String? subtitle;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? error;
  final bool busy;
  final String? destructiveLabel;
  final VoidCallback? onDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
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
          Text(title, style: theme.textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: SpaceSize.extraSmall),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: SpaceSize.extraLarge),
          ...children,
          ErrorBanner(error),
          const SizedBox(height: SpaceSize.small),
          FilledButton(
            onPressed: busy ? null : onPrimary,
            child: Text(primaryLabel),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: SpaceSize.small),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, ComponentSize.minTouchTarget),
              ),
              onPressed: busy ? null : onSecondary,
              child: Text(secondaryLabel!),
            ),
          ],
          if (destructiveLabel != null) ...[
            const SizedBox(height: SpaceSize.small),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                minimumSize: const Size(0, ComponentSize.minTouchTarget),
              ),
              onPressed: busy ? null : onDestructive,
              child: Text(destructiveLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.indent = 0,
  });
  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Custom leading widget (e.g. a [CategoryBadge]); overrides [icon].
  final Widget? leading;
  final int indent;
}

/// Single-choice list in a bottom sheet. Returns the picked value, or null
/// when dismissed.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickerOption<T>> options,
  T? selected,
  String? emptyMessage,
  String? footerLabel,
  VoidCallback? onFooter,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) {
    final theme = Theme.of(sheetContext);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpaceSize.gutter,
              0,
              SpaceSize.gutter,
              SpaceSize.medium,
            ),
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SpaceSize.gutter),
              child: Text(
                emptyMessage ?? 'Nothing to choose yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: SpaceSize.gutter,
                ),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, i) {
                  final option = options[i];
                  final isSelected = option.value == selected;
                  return Material(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(RadiusSize.medium),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: EdgeInsets.only(left: option.indent * 20.0),
                      child: AppTile(
                        title: option.title,
                        subtitle: option.subtitle,
                        leading:
                            option.leading ??
                            (option.icon == null
                                ? null
                                : IconBadge(option.icon!)),
                        showChevron: false,
                        trailing: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () =>
                            Navigator.of(sheetContext).pop(option.value),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (footerLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpaceSize.gutter,
                SpaceSize.small,
                SpaceSize.gutter,
                0,
              ),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onFooter?.call();
                },
                icon: const Icon(Icons.edit_outlined, size: IconSize.small),
                label: Text(footerLabel),
              ),
            ),
          const SizedBox(height: SpaceSize.large),
        ],
      ),
    );
  },
);

/// Pinned bottom area for a screen's primary action. Rises with the keyboard.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpaceSize.gutter,
          SpaceSize.small,
          SpaceSize.gutter,
          SpaceSize.medium,
        ),
        child: child,
      ),
    ),
  );
}

/// Date picker with the app's range limits.
Future<DateTime?> pickDate(BuildContext context, DateTime? initial) =>
    showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial ?? DateTime.now(),
    );
