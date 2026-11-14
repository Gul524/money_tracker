import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/splash_controller.dart';
import '../widgets/app_widgets.dart';
import 'app_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.services});
  final AppServices services;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final SplashController controller;

  @override
  void initState() {
    super.initState();
    controller = SplashController(widget.services);
    controller.addListener(_onState);
    controller.initialize();
  }

  @override
  void dispose() {
    controller.removeListener(_onState);
    controller.dispose();
    super.dispose();
  }

  void _onState() {
    if (controller.ready && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 250),
            pageBuilder: (_, _, _) => AppShell(services: widget.services),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(SpaceSize.huge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: ComponentSize.splashLogo,
                    height: ComponentSize.splashLogo,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(
                        RadiusSize.extraLarge,
                      ),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: scheme.onPrimary,
                      size: IconSize.hero,
                    ),
                  ),
                  const SizedBox(height: SpaceSize.extraLarge),
                  Text('Money Tracker', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: SpaceSize.extraSmall),
                  Text(
                    'Know where your money stands',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SpaceSize.huge),
                  if (controller.error == null)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else ...[
                    const ErrorBanner(
                      'Couldn’t open your data. Please try again.',
                    ),
                    const SizedBox(height: SpaceSize.medium),
                    FilledButton(
                      onPressed: controller.initialize,
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
