import 'package:flutter/material.dart';

import '../app_services.dart';
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
      0: HomeScreen(services: widget.services),
      1: HistoryScreen(services: widget.services),
      4: ReportsScreen(services: widget.services),
      5: SettingsScreen(services: widget.services, embedded: true),
    };
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(child: pages[selected]!),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          color: colors.surface,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                _NavItem(
                  index: 2,
                  label: 'Add',
                  icon: Icons.add_rounded,
                  emphasized: true,
                  onTap: _select,
                ),
                _NavItem(
                  index: 3,
                  label: 'Transfer',
                  icon: Icons.swap_horiz_rounded,
                  emphasized: true,
                  onTap: _select,
                ),
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
    this.emphasized = false,
  });
  final int index;
  final String label;
  final IconData icon;
  final ValueChanged<int> onTap;
  final bool selected;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = emphasized
        ? colors.onPrimary
        : selected
        ? colors.primary
        : colors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: emphasized ? 44 : 40,
                height: 40,
                decoration: BoxDecoration(
                  color: emphasized
                      ? colors.primary
                      : selected
                      ? colors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(emphasized ? 14 : 20),
                ),
                child: Icon(
                  icon,
                  color: foreground,
                  size: emphasized ? 26 : 23,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: emphasized ? colors.primary : foreground,
                  fontSize: 10,
                  fontWeight: emphasized || selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
