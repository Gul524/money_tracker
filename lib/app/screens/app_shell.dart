import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_sizes.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'transaction_screen.dart';
import 'transfer_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.services});
  final AppServices services;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;

  void _select(int index) {
    if (index == 2 || index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => index == 2
              ? TransactionScreen(services: widget.services)
              : TransferScreen(services: widget.services),
        ),
      );
      return;
    }
    setState(() => selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <int, Widget>{
      0: HomeScreen(
        services: widget.services,
        onShowHistory: () => setState(() => selected = 1),
      ),
      1: HistoryScreen(services: widget.services),
      4: ReportsScreen(services: widget.services),
      5: SettingsScreen(services: widget.services, embedded: true),
    };
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(child: pages[selected]!),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SafeArea(
          top: false,
          child: Material(
            color: colors.surface,
            elevation: ComponentSize.navigationElevation,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 9),
              child: Row(
                children: [
                  _NavItem(
                    index: 0,
                    label: 'Home',
                    icon: Icons.grid_view_rounded,
                    selected: selected == 0,
                    onTap: _select,
                  ),
                  _NavItem(
                    index: 1,
                    label: 'History',
                    icon: Icons.history_rounded,
                    selected: selected == 1,
                    onTap: _select,
                  ),
                  _CenterActions(onTap: _select),
                  _NavItem(
                    index: 4,
                    label: 'Reports',
                    icon: Icons.bar_chart_rounded,
                    selected: selected == 4,
                    onTap: _select,
                  ),
                  _NavItem(
                    index: 5,
                    label: 'Settings',
                    icon: Icons.settings_outlined,
                    selected: selected == 5,
                    onTap: _select,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });
  final int index;
  final String label;
  final IconData icon;
  final ValueChanged<int> onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(RadiusSize.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SpaceSize.tiny),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: ComponentSize.navigationIconBox,
                height: ComponentSize.navigationIconBox,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(RadiusSize.large),
                ),
                child: Icon(icon, color: foreground, size: IconSize.medium),
              ),
              const SizedBox(height: SpaceSize.extraSmall),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: TextSize.extraSmall,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterActions extends StatelessWidget {
  const _CenterActions({required this.onTap});
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      flex: 2,
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: SizedBox(
          height: ComponentSize.centerActionHeight,
          child: Material(
            color: colors.primary,
            elevation: 9,
            shadowColor: colors.primary.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: 'Add transaction',
                    child: InkWell(
                      onTap: () => onTap(2),
                      child: Center(
                        child: Icon(Icons.add_rounded, color: colors.onPrimary),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: ComponentSize.centerActionDivider,
                  height: ComponentSize.centerActionHeight,
                  color: colors.onPrimary.withValues(alpha: .35),
                ),
                Expanded(
                  child: Tooltip(
                    message: 'Transfer money',
                    child: InkWell(
                      onTap: () => onTap(3),
                      child: Center(
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
