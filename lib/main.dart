import 'package:flutter/material.dart';

import 'app/app_services.dart';
import 'app/app_theme.dart';
import 'app/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MoneyTrackerApp(services: AppServices.create()));
}

class MoneyTrackerApp extends StatelessWidget {
  const MoneyTrackerApp({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: services,
    builder: (context, _) => MaterialApp(
      title: 'Money Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: services.themeMode,
      home: SplashScreen(services: services),
    ),
  );
}
