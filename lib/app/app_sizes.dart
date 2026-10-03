/// Centralized UI dimensions. Values are logical pixels (dp), except text
/// sizes, which Flutter treats as logical font sizes.
abstract final class TextSize {
  static const double extraSmall = 10;
  static const double small = 12;
  static const double medium = 14;
  static const double large = 16;
  static const double extraLarge = 22;
  static const double display = 28;
  static const double caption = 13;
  static const double eyebrowLetterSpacing = 1.1;
}

/// Padding options for cards and other large surfaces.
abstract final class CardSize {
  static const double small = 12;
  static const double medium = 16;
  static const double large = 20;
  static const double extraLarge = 28;
}

abstract final class BorderSize {
  static const double small = 2;
  static const double medium = 4;
  static const double large = 6;
  static const double extraLarge = 8;
}

abstract final class IconSize {
  static const double extraSmall = 16;
  static const double small = 20;
  static const double medium = 23;
  static const double large = 40;
  static const double extraLarge = 42;
}

abstract final class RadiusSize {
  static const double small = 14;
  static const double medium = 16;
  static const double large = 20;
  static const double extraLarge = 24;
}

abstract final class SpaceSize {
  static const double tiny = 3;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double compact = 10;
  static const double medium = 12;
  static const double form = 14;
  static const double large = 16;
  static const double header = 18;
  static const double extraLarge = 20;
  static const double betweenCards = 22;
  static const double section = 24;
  static const double huge = 28;
  static const double emptyState = 40;
  static const double listBottom = 100;
  static const double formBottom = 120;
}

abstract final class ComponentSize {
  static const double navigationIconBox = 40;
  static const double centerActionHeight = 52;
  static const double centerActionDivider = 1;
  static const double splashLogoRadius = 42;
  static const double panelElevation = 2;
  static const double navigationElevation = 8;
  static const double appBarElevation = 0;
}
