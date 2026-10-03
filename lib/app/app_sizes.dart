/// Centralized UI dimensions. Values are logical pixels (dp), except text
/// sizes, which Flutter treats as logical font sizes.
abstract final class TextSize {
  static const double extraSmall = 8;
  static const double small = 10;
  static const double medium = 12;
  static const double large = 14;
  static const double extraLarge = 18;
  static const double display = 24;
  static const double caption = 11;
  static const double eyebrowLetterSpacing = 0.8;
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
  static const double extraSmall = 14;
  static const double small = 18;
  static const double medium = 22;
  static const double large = 30;
  static const double extraLarge = 36;
}

abstract final class RadiusSize {
  static const double small = 4;
  static const double medium = 8;
  static const double large = 12;
  static const double extraLarge = 14;
}

abstract final class SpaceSize {
  static const double tiny = 2;
  static const double extraSmall = 4;
  static const double small = 6;
  static const double compact = 8;
  static const double medium = 10;
  static const double form = 12;
  static const double large = 14;
  static const double header = 16;
  static const double extraLarge = 18;
  static const double betweenCards = 20;
  static const double section = 22;
  static const double huge = 26;
  static const double emptyState = 30;
  static const double listBottom = 60;
  static const double formBottom = 80;
}

abstract final class ComponentSize {
  static const double navigationIconBox = 30;
  static const double centerActionHeight = 42;
  static const double centerActionDivider = 1;
  static const double splashLogoRadius = 36;
  static const double panelElevation = 2;
  static const double navigationElevation = 4;
  static const double appBarElevation = 0;
}
