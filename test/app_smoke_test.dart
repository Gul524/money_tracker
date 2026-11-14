import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/app_services.dart';
import 'package:money_tracker/app/app_theme.dart';
import 'package:money_tracker/app/screens/app_shell.dart';
import 'package:money_tracker/app/screens/reports_screen.dart';
import 'package:money_tracker/app/screens/settings_screen.dart';
import 'package:money_tracker/data/services/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppServices _services() => AppServices.withDatabase(
  LocalDatabase(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  ),
);

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Lets real sqflite futures complete, then pumps frames.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

Finder _nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  sqfliteFfiInit();

  testWidgets('shell shows dashboard, add menu, forms and tabs', (
    tester,
  ) async {
    _phoneSize(tester);
    final services = _services();
    addTearDown(services.close);

    await tester.runAsync(services.initialize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppShell(services: services),
      ),
    );
    await _settle(tester);

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('Welcome to Money Tracker'), findsOneWidget);
    for (final label in ['Home', 'History', 'Reports', 'Settings']) {
      expect(_nav(label), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Recent activity'), 300);
    expect(find.text('Recent activity'), findsOneWidget);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('What would you like to add?'), findsOneWidget);
    expect(find.text('Someone owes me'), findsOneWidget);
    await tester.tap(find.text('Expense'));
    await _settle(tester);
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await _settle(tester);
    expect(find.text('Transfer money'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(_nav('Reports'));
    await _settle(tester);
    expect(find.byType(ReportsScreen), findsOneWidget);
    expect(find.text('Spending by category'), findsOneWidget);
    expect(find.byTooltip('Add'), findsNothing);

    await tester.tap(_nav('Settings'));
    await _settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('records an expense end to end', (tester) async {
    _phoneSize(tester);
    final services = _services();
    addTearDown(services.close);

    await tester.runAsync(services.initialize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppShell(services: services),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense'));
    await _settle(tester);

    await tester.enterText(find.byType(TextField).first, '1250.5');
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    // The seeded Cash account is the only one, so it is preselected.
    expect(find.text('Cash'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await _settle(tester);
    await _settle(tester);
    expect(find.text('Saved'), findsOneWidget);

    final history = await tester.runAsync(services.activity.history);
    expect(history!.single.amountMinor, -125050);
    expect(history.single.title, 'Food');
    expect(
      await tester.runAsync(() => services.accounts.balanceMinor(1)),
      -125050,
    );
  });

  testWidgets('changes appearance and restores the saved choice', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    _phoneSize(tester);
    final services = _services();
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
    await _settle(tester);
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

    expect(services.themeMode, ThemeMode.system);
    expect(brightness(), Brightness.dark);

    await tester.tap(find.text('Light'));
    await _settle(tester);
    expect(services.themeMode, ThemeMode.light);
    expect(brightness(), Brightness.light);

    await tester.tap(find.text('Dark'));
    await _settle(tester);
    expect(services.themeMode, ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(brightness(), Brightness.dark);
    expect(await tester.runAsync(services.settings.themeMode), 'dark');

    await tester.tap(find.text('System'));
    await _settle(tester);
    expect(services.themeMode, ThemeMode.system);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);

    services.themeMode = ThemeMode.dark;
    await tester.runAsync(services.initialize);
    expect(services.themeMode, ThemeMode.system);
  });
}
