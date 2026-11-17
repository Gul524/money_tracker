/// Centralized UI dimensions on a 4 dp grid. Values are logical pixels (dp),
/// except text sizes, which Flutter treats as logical font sizes and scales
/// with the device's accessibility setting.
abstract final class TextSize {
  static const double caption = 12;
  static const double small = 13;
  static const double body = 14;
  static const double bodyLarge = 16;
  static const double title = 16;
  static const double headline = 20;
  static const double largeTitle = 28;
  static const double amount = 32;
  static const double amountInput = 44;

  /// App name on the splash screen.
  static const double brand = 44;
}

/// Inner padding for cards and grouped sections.
abstract final class CardSize {
  static const double padding = 16;
  static const double heroPadding = 20;
}

abstract final class IconSize {
  static const double small = 18;
  static const double medium = 20;
  static const double large = 24;
  static const double hero = 36;
}

abstract final class RadiusSize {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 20;
  static const double sheet = 28;
}

abstract final class SpaceSize {
  static const double tiny = 2;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 20;
  static const double section = 28;
  static const double huge = 40;

  /// Horizontal page margin used by every screen.
  static const double gutter = 16;

  /// Bottom space so the last item clears a floating action button.
  static const double fabClearance = 96;
}

abstract final class ComponentSize {
  /// Rounded-square container behind list icons.
  static const double iconBadge = 40;
  static const double minTouchTarget = 48;
  static const double buttonHeight = 52;
  static const double navigationBarHeight = 68;
  static const double splashLogo = 112;

  /// Soft glow drawn behind the splash logo.
  static const double splashGlow = 240;

  /// Left inset of dividers so they align with tile text, not icons.
  static const double tileDividerIndent = 68;
}
