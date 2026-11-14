import 'package:flutter/material.dart';

import 'app_sizes.dart';

/// Finance-specific semantic colors that Material's ColorScheme lacks.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.income,
    required this.incomeContainer,
    required this.expense,
    required this.expenseContainer,
    required this.transfer,
    required this.transferContainer,
    required this.warning,
    required this.warningContainer,
    required this.neutralContainer,
  });

  final Color income;
  final Color incomeContainer;
  final Color expense;
  final Color expenseContainer;
  final Color transfer;
  final Color transferContainer;
  final Color warning;
  final Color warningContainer;
  final Color neutralContainer;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? income,
    Color? incomeContainer,
    Color? expense,
    Color? expenseContainer,
    Color? transfer,
    Color? transferContainer,
    Color? warning,
    Color? warningContainer,
    Color? neutralContainer,
  }) => AppColors(
    income: income ?? this.income,
    incomeContainer: incomeContainer ?? this.incomeContainer,
    expense: expense ?? this.expense,
    expenseContainer: expenseContainer ?? this.expenseContainer,
    transfer: transfer ?? this.transfer,
    transferContainer: transferContainer ?? this.transferContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    neutralContainer: neutralContainer ?? this.neutralContainer,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      income: l(income, other.income),
      incomeContainer: l(incomeContainer, other.incomeContainer),
      expense: l(expense, other.expense),
      expenseContainer: l(expenseContainer, other.expenseContainer),
      transfer: l(transfer, other.transfer),
      transferContainer: l(transferContainer, other.transferContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      neutralContainer: l(neutralContainer, other.neutralContainer),
    );
  }
}

class _Palette {
  const _Palette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.background,
    required this.surface,
    required this.field,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.colors,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color background;
  final Color surface;
  final Color field;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color error;
  final AppColors colors;

  static const light = _Palette(
    primary: Color(0xFF2C5BE0),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE3EAFD),
    onPrimaryContainer: Color(0xFF1A3A99),
    background: Color(0xFFF3F4F6),
    surface: Colors.white,
    field: Color(0xFFF0F2F5),
    onSurface: Color(0xFF101828),
    onSurfaceVariant: Color(0xFF667085),
    outline: Color(0xFFD0D5DD),
    outlineVariant: Color(0xFFE6E8EC),
    error: Color(0xFFD92D20),
    colors: AppColors(
      income: Color(0xFF0F8A5F),
      incomeContainer: Color(0xFFE5F5EE),
      expense: Color(0xFFD92D20),
      expenseContainer: Color(0xFFFDECEA),
      transfer: Color(0xFF2C5BE0),
      transferContainer: Color(0xFFE8EEFD),
      warning: Color(0xFFB54708),
      warningContainer: Color(0xFFFEF0E1),
      neutralContainer: Color(0xFFF0F2F5),
    ),
  );

  static const dark = _Palette(
    primary: Color(0xFF8AA8FF),
    onPrimary: Color(0xFF0B1B4D),
    primaryContainer: Color(0xFF23315C),
    onPrimaryContainer: Color(0xFFD9E2FF),
    background: Color(0xFF0C0E13),
    surface: Color(0xFF171A21),
    field: Color(0xFF20242D),
    onSurface: Color(0xFFECEEF2),
    onSurfaceVariant: Color(0xFF98A2B3),
    outline: Color(0xFF3A4150),
    outlineVariant: Color(0xFF252A34),
    error: Color(0xFFFF6B5E),
    colors: AppColors(
      income: Color(0xFF45CF92),
      incomeContainer: Color(0xFF12291F),
      expense: Color(0xFFFF7A6E),
      expenseContainer: Color(0xFF301715),
      transfer: Color(0xFF8AA8FF),
      transferContainer: Color(0xFF1A2342),
      warning: Color(0xFFF5A14A),
      warningContainer: Color(0xFF2F2211),
      neutralContainer: Color(0xFF20242D),
    ),
  );
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final p = brightness == Brightness.dark ? _Palette.dark : _Palette.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p.primary,
          brightness: brightness,
        ).copyWith(
          primary: p.primary,
          onPrimary: p.onPrimary,
          primaryContainer: p.primaryContainer,
          onPrimaryContainer: p.onPrimaryContainer,
          surface: p.surface,
          onSurface: p.onSurface,
          onSurfaceVariant: p.onSurfaceVariant,
          surfaceContainerLowest: p.surface,
          surfaceContainerLow: p.surface,
          surfaceContainer: p.surface,
          surfaceContainerHigh: p.surface,
          surfaceContainerHighest: p.field,
          outline: p.outline,
          outlineVariant: p.outlineVariant,
          error: p.error,
          surfaceTint: Colors.transparent,
        );

    TextStyle text(
      double size,
      FontWeight weight, {
      Color? color,
      double spacing = 0,
      double? height,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? p.onSurface,
      letterSpacing: spacing,
      height: height,
    );

    final textTheme = TextTheme(
      displaySmall: text(
        TextSize.amount,
        FontWeight.w700,
        spacing: -0.6,
        height: 1.15,
      ),
      headlineMedium: text(TextSize.largeTitle, FontWeight.w700, spacing: -0.4),
      headlineSmall: text(24, FontWeight.w700, spacing: -0.2),
      titleLarge: text(TextSize.headline, FontWeight.w600, spacing: -0.1),
      titleMedium: text(TextSize.title, FontWeight.w600),
      titleSmall: text(TextSize.body, FontWeight.w600),
      bodyLarge: text(TextSize.bodyLarge, FontWeight.w400, height: 1.35),
      bodyMedium: text(TextSize.body, FontWeight.w400, height: 1.4),
      bodySmall: text(
        TextSize.caption,
        FontWeight.w400,
        color: p.onSurfaceVariant,
        height: 1.35,
      ),
      labelLarge: text(TextSize.body, FontWeight.w600),
      labelMedium: text(TextSize.caption, FontWeight.w500),
      labelSmall: text(11, FontWeight.w500, spacing: 0.2),
    );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RadiusSize.medium),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      extensions: [p.colors],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: ComponentSize.navigationBarHeight,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: p.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text(
            TextSize.caption,
            states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? p.onSurface
                : p.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: IconSize.large,
            color: states.contains(WidgetState.selected)
                ? p.onPrimaryContainer
                : p.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 3,
        extendedTextStyle: text(
          TextSize.bodyLarge,
          FontWeight.w600,
          color: p.onPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.large),
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.large),
          side: BorderSide(color: p.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: SpaceSize.large),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.field,
        hintStyle: text(
          TextSize.bodyLarge,
          FontWeight.w400,
          color: p.onSurfaceVariant,
        ),
        labelStyle: text(
          TextSize.bodyLarge,
          FontWeight.w400,
          color: p.onSurfaceVariant,
        ),
        floatingLabelStyle: text(
          TextSize.body,
          FontWeight.w500,
          color: p.primary,
        ),
        helperStyle: textTheme.bodySmall,
        helperMaxLines: 2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SpaceSize.large,
          vertical: SpaceSize.large,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.medium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.medium),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.medium),
          borderSide: BorderSide(color: p.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, ComponentSize.buttonHeight),
          shape: rounded,
          textStyle: text(TextSize.bodyLarge, FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, ComponentSize.buttonHeight),
          shape: rounded,
          side: BorderSide(color: p.outline),
          foregroundColor: p.onSurface,
          textStyle: text(TextSize.bodyLarge, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: text(TextSize.body, FontWeight.w600),
          shape: rounded,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          side: WidgetStatePropertyAll(BorderSide(color: p.outline)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.primaryContainer
                : p.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.onPrimaryContainer
                : p.onSurface,
          ),
          textStyle: WidgetStatePropertyAll(
            text(TextSize.body, FontWeight.w600),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.onSurface,
        side: BorderSide(color: p.outline),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: text(TextSize.small, FontWeight.w500),
        secondaryLabelStyle: text(
          TextSize.small,
          FontWeight.w600,
          color: p.background,
        ),
        padding: const EdgeInsets.symmetric(horizontal: SpaceSize.extraSmall),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RadiusSize.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.extraLarge),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: p.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.onSurface,
        contentTextStyle: text(
          TextSize.body,
          FontWeight.w500,
          color: p.background,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.medium),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.outlineVariant,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.medium),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.surface,
        headerForegroundColor: p.onSurface,
      ),
    );
  }
}
