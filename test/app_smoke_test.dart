import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/app_services.dart';
import 'package:money_tracker/app/app_theme.dart';
import 'package:money_tracker/app/screens/app_shell.dart';
import 'package:money_tracker/app/screens/reports_screen.dart';
import 'package:money_tracker/app/screens/settings_screen.dart';
import 'package:money_tracker/app/screens/account_detail_screen.dart';
import 'package:money_tracker/app/screens/category_screen.dart';
import 'package:money_tracker/app/screens/defaults_screen.dart';
import 'package:money_tracker/data/models/account.dart';
import 'package:money_tracker/data/models/account_transfer.dart';
import 'package:money_tracker/data/models/model_types.dart';
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
    final taxField = find.ancestor(
      of: find.text('Tax paid (optional)'),
      matching: find.byType(TextField),
    );
    await tester.enterText(taxField, '100');
    await tester.pumpAndSettle();
    expect(find.textContaining('Rs 1,350.50 leaves Cash'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await _settle(tester);
    await _settle(tester);
    expect(find.text('Saved'), findsOneWidget);

    final history = await tester.runAsync(services.activity.history);
    expect(history!.single.amountMinor, -125050);
    expect(history.single.title, 'Food');
    expect(history.single.taxMinor, 10000);
    expect(
      await tester.runAsync(() => services.accounts.balanceMinor(1)),
      -135050,
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

  testWidgets('history filters, editing transfers, reports and accounts', (
    tester,
  ) async {
    _phoneSize(tester);
    final services = _services();
    addTearDown(services.close);
    await tester.runAsync(() async {
      await services.initialize();
      final bank = await services.accounts.create(
        const Account(name: 'Bank', type: AccountType.bank),
      );
      await services.transfers.create(
        AccountTransfer(
          fromAccountId: 1,
          toAccountId: bank.id!,
          amountMinor: 50000,
          occurredAt: DateTime.now(),
        ),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppShell(services: services),
      ),
    );
    await _settle(tester);

    await tester.tap(_nav('History'));
    await _settle(tester);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Filter activity'), findsOneWidget);
    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    expect(find.text('Show 1 results'), findsOneWidget);
    await tester.tap(find.text('Show 1 results'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cash → Bank'));
    await _settle(tester);
    expect(find.text('Edit transfer'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(_nav('Reports'));
    await _settle(tester);
    await tester.tap(find.text('Year'));
    await _settle(tester);
    expect(find.text('${DateTime.now().year}'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No tax paid in this period.'),
      300,
    );
    expect(find.text('No tax paid in this period.'), findsOneWidget);

    await tester.tap(_nav('Home'));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Bank').first, 300);
    await tester.tap(find.text('Bank').first);
    await _settle(tester);
    expect(find.byType(AccountDetailScreen), findsOneWidget);
    expect(find.text('Bank account balance'), findsOneWidget);
    expect(find.text('+Rs 500.00'), findsWidgets);
  });

  testWidgets('settings defaults are chosen and prefill a new expense', (
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

    await tester.tap(_nav('Settings'));
    await _settle(tester);
    await tester.tap(find.text('Defaults for new entries'));
    await _settle(tester);
    expect(find.byType(DefaultsScreen), findsOneWidget);
    await tester.tap(find.text('Category').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shopping'));
    await _settle(tester);
    expect(find.text('Shopping'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(_nav('Home'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense'));
    await _settle(tester);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
  });

  testWidgets('category icon and any hex color are chosen and saved', (
    tester,
  ) async {
    _phoneSize(tester);
    final services = _services();
    addTearDown(services.close);
    await tester.runAsync(services.initialize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CategoryScreen(services: services),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('Edit category'), findsOneWidget);

    await tester.tap(find.text('Icon'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an icon'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('local pizza'));
    await tester.pumpAndSettle();
    expect(find.text('Custom'), findsOneWidget);

    await tester.tap(find.text('Color'));
    await tester.pumpAndSettle();
    expect(find.text('Tag color'), findsOneWidget);
    await tester.enterText(
      find.ancestor(of: find.text('Hex'), matching: find.byType(TextField)),
      '12ab9c',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this color'));
    await tester.pumpAndSettle();
    expect(find.text('#12AB9C'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await _settle(tester);
    final food = (await tester.runAsync(services.categories.getAll))!
        .firstWhere((c) => c.name == 'Food');
    expect((food.icon, food.color), ('local_pizza', '#12AB9C'));
  });
}
