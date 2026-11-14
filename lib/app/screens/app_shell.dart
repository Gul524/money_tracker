import 'package:flutter/material.dart';

import '../app_services.dart';
import 'add_entry_sheet.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

/// Root layout: four top-level destinations in a standard navigation bar and
/// one primary "Add" action. Tabs keep their scroll position and state.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.services});
  final AppServices services;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    HomeScreen(services: widget.services, onShowHistory: () => _select(1)),
    HistoryScreen(services: widget.services),
    ReportsScreen(services: widget.services),
    SettingsScreen(services: widget.services),
  ];

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      // The primary action lives where people record money: Home and History.
      floatingActionButton: _index <= 1
          ? FloatingActionButton.extended(
              tooltip: 'Add',
              onPressed: () => openAddFlow(context, widget.services),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : null,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
