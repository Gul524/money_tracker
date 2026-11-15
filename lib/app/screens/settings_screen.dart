import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/settings_controller.dart';
import '../widgets/app_widgets.dart';
import 'account_screen.dart';
import 'asset_screen.dart';
import 'category_screen.dart';
import 'defaults_screen.dart';
import 'owe_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.services});
  final AppServices services;
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

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _pickCurrency() async {
    final picked = await showPickerSheet<String>(
      context,
      title: 'Currency',
      selected: controller.currency,
      options: [
        for (final e in currencyNames.entries)
          PickerOption(
            value: e.key,
            title: e.value,
            subtitle: '${e.key} · ${currencySymbol(e.key)}',
          ),
      ],
    );
    if (picked != null) await controller.setCurrency(picked);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final services = widget.services;
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverAppBar.medium(title: Text('Settings')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                SpaceSize.gutter,
                0,
                SpaceSize.gutter,
                SpaceSize.huge,
              ),
              sliver: SliverList.list(
                children: [
                  ErrorBanner(controller.error),
                  const SectionHeader(
                    'Preferences',
                    padding: EdgeInsets.fromLTRB(
                      SpaceSize.extraSmall,
                      0,
                      0,
                      SpaceSize.small,
                    ),
                  ),
                  GroupedCard(
                    children: [
                      AppTile(
                        leading: const IconBadge(Icons.payments_outlined),
                        title: 'Currency',
                        subtitle: currencyNames[controller.currency],
                        trailing: Text(
                          controller.currency,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: _pickCurrency,
                      ),
                      AppTile(
                        leading: const IconBadge(Icons.tune_rounded),
                        title: 'Defaults for new entries',
                        subtitle: 'Category and wallet picked for you',
                        onTap: () => _open(DefaultsScreen(services: services)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(SpaceSize.large),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const IconBadge(Icons.contrast_rounded),
                                const SizedBox(width: SpaceSize.medium),
                                Text(
                                  'Appearance',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: SpaceSize.medium),
                            SegmentedButton<ThemeMode>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('System'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                ),
                              ],
                              selected: {controller.themeMode},
                              onSelectionChanged: (v) =>
                                  controller.setThemeMode(v.first),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const InfoNote(
                    'Changing the currency only changes the symbol shown. '
                    'Saved amounts are not converted.',
                  ),
                  const SectionHeader('Manage'),
                  GroupedCard(
                    children: [
                      AppTile(
                        leading: const IconBadge(
                          Icons.account_balance_wallet_outlined,
                        ),
                        title: 'Accounts',
                        subtitle: 'Cash and bank accounts',
                        onTap: () => _open(AccountScreen(services: services)),
                      ),
                      AppTile(
                        leading: const IconBadge(Icons.sell_outlined),
                        title: 'Categories',
                        subtitle: 'Groups for income and expenses',
                        onTap: () => _open(CategoryScreen(services: services)),
                      ),
                      AppTile(
                        leading: const IconBadge(Icons.handshake_outlined),
                        title: 'Money owed',
                        subtitle: 'Money lent and borrowed',
                        onTap: () => _open(OweScreen(services: services)),
                      ),
                      AppTile(
                        leading: const IconBadge(Icons.inventory_2_outlined),
                        title: 'Assets',
                        subtitle: 'Things you own and their value',
                        onTap: () => _open(AssetScreen(services: services)),
                      ),
                    ],
                  ),
                  const SectionHeader('About'),
                  const GroupedCard(
                    children: [
                      AppTile(
                        leading: IconBadge(Icons.lock_outline_rounded),
                        title: 'Private by design',
                        subtitle: 'Your data is stored only on this device. Nothing is uploaded.',
                      ),
                      AppTile(
                        leading: IconBadge(Icons.info_outline_rounded),
                        title: 'Version',
                        trailing: Text('0.1.0'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
