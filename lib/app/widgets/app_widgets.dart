import 'package:flutter/material.dart';

const ink = Color(0xFF17243B);
const muted = Color(0xFF718096);
const accent = Color(0xFF375CF5);
const canvas = Color(0xFFF5F7FB);

String money(int minor, String currency) {
  final sign = minor < 0 ? '−' : '';
  final absolute = minor.abs();
  final whole = absolute ~/ 100;
  final cents = (absolute % 100).toString().padLeft(2, '0');
  return '$sign$currency $whole.$cents';
}

Future<bool> confirmDelete(BuildContext context, String item) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $item?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(24),
    elevation: 2,
    shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.06),
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      ?action,
    ],
  );
}

class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.isViewOnly = false,
    this.hint,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool isViewOnly;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    if (isViewOnly) {
      return AppValue(label: label, value: value.isEmpty ? '—' : value);
    }
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class AppValue extends StatelessWidget {
  const AppValue({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isViewOnly = false,
    this.allowClear = false,
  });
  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final bool isViewOnly;
  final bool allowClear;
  @override
  Widget build(BuildContext context) {
    if (isViewOnly) return AppValue(label: label, value: items[value] ?? '—');
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: items.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: allowClear && value != null
            ? IconButton(
                tooltip: 'Clear $label',
                icon: const Icon(Icons.close),
                onPressed: () => onChanged(null),
              )
            : null,
      ),
      items: items.entries
          .map(
            (e) => DropdownMenuItem<T>(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isViewOnly = false,
    this.optional = false,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool isViewOnly;
  final bool optional;
  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? 'Not set'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    if (isViewOnly) return AppValue(label: label, value: display);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(display),
      trailing: optional && value != null
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            )
          : const Icon(Icons.calendar_month_outlined),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDate: value ?? DateTime.now(),
        );
        if (date != null) onChanged(date);
      },
    );
  }
}

class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
    this.isViewOnly = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isViewOnly;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    leading: CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primary
          .withValues(alpha: .12),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing:
        trailing ??
        (isViewOnly
            ? null
            : Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
    onTap: isViewOnly ? null : onTap,
  );
}

class AppEmpty extends StatelessWidget {
  const AppEmpty(this.message, {super.key, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 42,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class AppError extends StatelessWidget {
  const AppError(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            message!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    ),
  );
}
