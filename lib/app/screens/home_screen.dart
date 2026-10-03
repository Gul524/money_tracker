import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/home_controller.dart';
import '../widgets/app_widgets.dart';
import 'account_screen.dart';
import 'asset_screen.dart';
import 'category_screen.dart';
import 'owe_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController controller;
  @override
  void initState() {
    super.initState();
    controller = HomeController(widget.services);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final s = controller.summary;
      final currency = widget.services.currencyCode;
      return ListView(
        padding: const EdgeInsets.only(bottom: SpaceSize.listBottom),
        children: [
          PageHeader(
            title: 'Overview',
            subtitle: s == null
                ? 'This month'
                : '${s.asOf.day}/${s.asOf.month}/${s.asOf.year} · This month',
          ),
          if (controller.busy && s == null)
            const Center(child: CircularProgressIndicator()),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: AppError(controller.error),
            ),
          if (s != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL IN ACCOUNTS',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: TextSize.small,
                        fontWeight: FontWeight.w700,
                        letterSpacing: TextSize.eyebrowLetterSpacing,
                      ),
                    ),
                    const SizedBox(height: SpaceSize.small),
                    Text(
                      money(s.totalBalanceMinor, currency),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: SpaceSize.header),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniTotal(
                            'Income',
                            s.incomeMinor,
                            currency,
                            Icons.arrow_downward,
                          ),
                        ),
                        const SizedBox(width: SpaceSize.medium),
                        Expanded(
                          child: _MiniTotal(
                            'Expenses',
                            s.expenseMinor,
                            currency,
                            Icons.arrow_upward,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SpaceSize.betweenCards),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      'Owed to you',
                      s.oweInMinor,
                      currency,
                      Icons.call_received,
                    ),
                  ),
                  const SizedBox(width: SpaceSize.medium),
                  Expanded(
                    child: _StatCard(
                      'You owe',
                      s.oweOutMinor,
                      currency,
                      Icons.call_made,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpaceSize.medium),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      'Assets',
                      s.assetValueMinor,
                      currency,
                      Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: SpaceSize.medium),
                  Expanded(
                    child: _StatCard(
                      'Tax paid',
                      s.taxPaidMinor,
                      currency,
                      Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpaceSize.section),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: AppSectionTitle('Accounts'),
            ),
            const SizedBox(height: SpaceSize.compact),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: AppPanel(
                child: s.accounts.isEmpty
                    ? const AppEmpty('Add an account to get started')
                    : Column(
                        children: [
                          for (final a in s.accounts)
                            AppListItem(
                              title: a.account.name,
                              subtitle: a.account.type.name,
                              icon: Icons.account_balance_wallet_outlined,
                              trailing: Text(
                                money(a.balanceMinor, currency),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              isViewOnly: true,
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: SpaceSize.section),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: AppSectionTitle('Quick actions'),
            ),
            const SizedBox(height: SpaceSize.compact),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceSize.extraLarge,
              ),
              child: AppPanel(
                child: Column(
                  children: [
                    AppListItem(
                      title: 'Owe',
                      subtitle: 'Money to receive and repay',
                      icon: Icons.handshake_outlined,
                      onTap: () => _open(OweScreen(services: widget.services)),
                    ),
                    AppListItem(
                      title: 'Accounts',
                      subtitle: 'Manage your accounts',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () =>
                          _open(AccountScreen(services: widget.services)),
                    ),
                    AppListItem(
                      title: 'Assets',
                      subtitle: 'Manage your assets',
                      icon: Icons.inventory_2_outlined,
                      onTap: () =>
                          _open(AssetScreen(services: widget.services)),
                    ),
                    AppListItem(
                      title: 'Manage categories',
                      subtitle: 'Organize income and expenses',
                      icon: Icons.category_outlined,
                      onTap: () =>
                          _open(CategoryScreen(services: widget.services)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _MiniTotal extends StatelessWidget {
  const _MiniTotal(this.label, this.value, this.currency, this.icon);
  final String label;
  final int value;
  final String currency;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            icon,
            size: IconSize.extraSmall,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: SpaceSize.extraSmall),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: SpaceSize.extraSmall),
      Text(
        money(value, currency),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.currency, this.icon);
  final String label;
  final int value;
  final String currency;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AppPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: SpaceSize.medium),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: TextSize.caption,
          ),
        ),
        const SizedBox(height: SpaceSize.extraSmall),
        Text(
          money(value, currency),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: TextSize.large,
          ),
        ),
      ],
    ),
  );
}
