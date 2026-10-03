import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/app_theme.dart';
import 'package:money_tracker/app/screens/settings_screen.dart';
import 'package:money_tracker/app/screens/reports_screen.dart';
import 'package:money_tracker/app/app_services.dart';
import 'package:money_tracker/data/services/local_database.dart';
import 'package:money_tracker/app/screens/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('opens dashboard and transaction flow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final services = AppServices.withDatabase(
      LocalDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    );
    addTearDown(services.close);

    await tester.runAsync(services.initialize);
    await tester.pumpWidget(MaterialApp(home: AppShell(services: services)));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Overview'), findsOneWidget);
    for (final label in [
      'Home',
      'History',
      'Add',
      'Transfer',
      'Reports',
      'Settings',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('New transaction'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Transfer money'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reports'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ReportsScreen), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('changes appearance and restores the saved choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final services = AppServices.withDatabase(
      LocalDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    );
    addTearDown(services.close);

    await tester.runAsync(services.initialize);
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: services,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: services.themeMode,
          home: SettingsScreen(services: services),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(services.themeMode, ThemeMode.dark);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    expect(await tester.runAsync(services.settings.themeMode), 'dark');
    services.themeMode = ThemeMode.light;
    await tester.runAsync(services.initialize);
    expect(services.themeMode, ThemeMode.dark);
  });
}
