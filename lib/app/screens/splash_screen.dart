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
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AppShell(services: widget.services),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpaceSize.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: ComponentSize.splashLogoRadius,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: IconSize.large,
                ),
              ),
              const SizedBox(height: SpaceSize.betweenCards),
              Text(
                'Money Tracker',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: SpaceSize.small),
              Text(
                'Know where your money stands',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpaceSize.huge),
              if (controller.error == null)
                const CircularProgressIndicator()
              else ...[
                AppError(controller.error),
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
}
