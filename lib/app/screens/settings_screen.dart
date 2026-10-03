import 'package:flutter/material.dart';

import '../app_services.dart';
import '../controllers/settings_controller.dart';
import '../widgets/app_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.services,
    this.embedded = false,
  });
  final AppServices services;
  final bool embedded;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController controller;
  @override
  void initState() {
    super.initState();
    controller = SettingsController(widget.services);
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
      final content = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.embedded) ...[
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
          ],
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('General', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                AppSelect<String>(
                  label: 'Display currency',
                  value: controller.currency,
                  items: const {
                    'PKR': 'PKR · Pakistani Rupee',
                    'USD': 'USD · US Dollar',
                    'EUR': 'EUR · Euro',
                    'GBP': 'GBP · British Pound',
                  },
                  onChanged: (v) {
                    if (v != null) controller.setCurrency(v);
                  },
                ),
                const SizedBox(height: 16),
                AppSelect<ThemeMode>(
                  label: 'Appearance',
                  value: controller.themeMode,
                  items: const {
                    ThemeMode.system: 'Use device setting',
                    ThemeMode.light: 'Light',
                    ThemeMode.dark: 'Dark',
                  },
                  onChanged: (value) {
                    if (value != null) controller.setThemeMode(value);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Currency changes how amounts are displayed. It does not convert saved amounts.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppError(controller.error),
          const AppPanel(
            child: AppValue(
              label: 'Storage',
              value: 'Saved locally on this device',
            ),
          ),
        ],
      );
      return widget.embedded
          ? content
          : Scaffold(
              appBar: AppBar(title: const Text('Settings')),
              body: content,
            );
    },
  );
}
