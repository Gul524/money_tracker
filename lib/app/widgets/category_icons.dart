import 'package:flutter/material.dart';

/// Icons a user can choose for a category, grouped for the picker. The key is
/// what's stored in `categories.icon`, so keys must never be renamed.
const categoryIconGroups = <String, Map<String, IconData>>{
  'Food & drink': {
    'restaurant': Icons.restaurant_outlined,
    'fastfood': Icons.fastfood_outlined,
    'local_cafe': Icons.local_cafe_outlined,
    'local_pizza': Icons.local_pizza_outlined,
    'bakery': Icons.bakery_dining_outlined,
    'grocery': Icons.local_grocery_store_outlined,
    'liquor': Icons.local_bar_outlined,
    'icecream': Icons.icecream_outlined,
  },
  'Shopping': {
    'shopping_bag': Icons.shopping_bag_outlined,
    'shopping_cart': Icons.shopping_cart_outlined,
    'checkroom': Icons.checkroom_outlined,
    'diamond': Icons.diamond_outlined,
    'devices': Icons.devices_outlined,
    'chair': Icons.chair_outlined,
    'toys': Icons.toys_outlined,
    'spa': Icons.spa_outlined,
  },
  'Home & bills': {
    'home': Icons.home_outlined,
    'bolt': Icons.bolt_outlined,
    'water': Icons.water_drop_outlined,
    'gas': Icons.local_fire_department_outlined,
    'wifi': Icons.wifi_rounded,
    'smartphone': Icons.smartphone_outlined,
    'tv': Icons.tv_outlined,
    'build': Icons.build_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'receipt': Icons.receipt_long_outlined,
  },
  'Transport': {
    'car': Icons.directions_car_outlined,
    'fuel': Icons.local_gas_station_outlined,
    'bus': Icons.directions_bus_outlined,
    'train': Icons.train_outlined,
    'taxi': Icons.local_taxi_outlined,
    'bike': Icons.two_wheeler_outlined,
    'flight': Icons.flight_outlined,
    'parking': Icons.local_parking_outlined,
  },
  'Health & care': {
    'medical': Icons.medical_services_outlined,
    'pharmacy': Icons.local_pharmacy_outlined,
    'hospital': Icons.local_hospital_outlined,
    'fitness': Icons.fitness_center_outlined,
    'heart': Icons.favorite_outline_rounded,
    'child': Icons.child_care_outlined,
    'pets': Icons.pets_outlined,
    'salon': Icons.content_cut_rounded,
  },
  'Learning & fun': {
    'school': Icons.school_outlined,
    'book': Icons.menu_book_outlined,
    'movie': Icons.movie_outlined,
    'music': Icons.music_note_outlined,
    'game': Icons.sports_esports_outlined,
    'sports': Icons.sports_soccer_outlined,
    'travel': Icons.luggage_outlined,
    'hotel': Icons.hotel_outlined,
    'celebration': Icons.celebration_outlined,
    'camera': Icons.photo_camera_outlined,
  },
  'Money & work': {
    'payments': Icons.payments_outlined,
    'work': Icons.work_outline_rounded,
    'store': Icons.storefront_outlined,
    'trending_up': Icons.trending_up_rounded,
    'savings': Icons.savings_outlined,
    'bank': Icons.account_balance_outlined,
    'card': Icons.credit_card_outlined,
    'wallet': Icons.account_balance_wallet_outlined,
    'premium': Icons.workspace_premium_outlined,
    'percent': Icons.percent_rounded,
    'laptop': Icons.laptop_mac_outlined,
    'rent_in': Icons.real_estate_agent_outlined,
  },
  'People & giving': {
    'gift': Icons.card_giftcard_outlined,
    'charity': Icons.volunteer_activism_outlined,
    'family': Icons.family_restroom_outlined,
    'people': Icons.people_outline_rounded,
    'handshake': Icons.handshake_outlined,
    'mosque': Icons.mosque_outlined,
    'church': Icons.church_outlined,
    'cake': Icons.cake_outlined,
  },
  'Other': {
    'tag': Icons.sell_outlined,
    'star': Icons.star_outline_rounded,
    'category': Icons.category_outlined,
    'inventory': Icons.inventory_2_outlined,
    'eco': Icons.eco_outlined,
    'security': Icons.shield_outlined,
    'phone_call': Icons.call_outlined,
    'mail': Icons.mail_outline_rounded,
    'income': Icons.south_west_rounded,
    'expense': Icons.north_east_rounded,
  },
};

final Map<String, IconData> _iconsByKey = {
  for (final group in categoryIconGroups.values) ...group,
};

/// Whether [key] names an icon in [categoryIconGroups].
bool isCategoryIconKey(String? key) => _iconsByKey.containsKey(key);

/// The category's icon: the one the user chose ([iconKey]), otherwise one
/// guessed from its [name] so lists are scannable without reading.
IconData categoryIcon(String name, {bool income = false, String? iconKey}) {
  final chosen = _iconsByKey[iconKey];
  if (chosen != null) return chosen;
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);

  if (has(['salary', 'wage', 'pay'])) return Icons.payments_outlined;
  if (has(['business', 'shop sale', 'sales'])) return Icons.storefront_outlined;
  if (has(['bonus', 'reward', 'prize'])) {
    return Icons.workspace_premium_outlined;
  }
  if (has(['interest', 'profit', 'invest', 'dividend'])) {
    return Icons.trending_up_rounded;
  }
  if (has(['food', 'grocer', 'restaurant', 'meal', 'dining', 'lunch'])) {
    return Icons.restaurant_outlined;
  }
  if (has(['shop', 'cloth', 'fashion'])) return Icons.shopping_bag_outlined;
  if (has(['phone', 'mobile', 'internet', 'data'])) {
    return Icons.smartphone_outlined;
  }
  if (has(['donat', 'charity', 'zakat', 'sadqa'])) {
    return Icons.volunteer_activism_outlined;
  }
  if (has(['gift'])) return Icons.card_giftcard_outlined;
  if (has(['educat', 'school', 'fee', 'book', 'course', 'tuition'])) {
    return Icons.school_outlined;
  }
  if (has(['fuel', 'petrol', 'car', 'transport', 'taxi', 'bus', 'ride'])) {
    return Icons.directions_car_outlined;
  }
  if (has(['rent', 'house', 'home'])) return Icons.home_outlined;
  if (has(['bill', 'electric', 'gas', 'water', 'utilit'])) {
    return Icons.bolt_outlined;
  }
  if (has(['health', 'medic', 'doctor', 'pharma', 'hospital'])) {
    return Icons.medical_services_outlined;
  }
  if (has(['travel', 'trip', 'flight', 'hotel'])) return Icons.flight_outlined;
  if (has(['entertain', 'movie', 'game', 'fun'])) return Icons.movie_outlined;
  if (has(['loan', 'debt', 'owe'])) return Icons.handshake_outlined;
  return income ? Icons.south_west_rounded : Icons.sell_outlined;
}

/// Colors given to categories that have no color chosen yet, and offered as
/// quick picks in the color picker.
const categorySwatches = <Color>[
  Color(0xFFE4572E),
  Color(0xFFF08A24),
  Color(0xFFE0A100),
  Color(0xFF6BAA27),
  Color(0xFF1E9E6A),
  Color(0xFF13A3A3),
  Color(0xFF2B8FD6),
  Color(0xFF3F5BD9),
  Color(0xFF7B4FD6),
  Color(0xFFB44BC4),
  Color(0xFFD8447A),
  Color(0xFF8A6A4F),
];

/// `#RRGGBB` → [Color], or null when [hex] isn't a valid 6-digit hex color.
Color? colorFromHex(String? hex) {
  if (hex == null) return null;
  final clean = hex.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)) return null;
  return Color(0xFF000000 | int.parse(clean, radix: 16));
}

/// [Color] → `#RRGGBB` (upper case, alpha dropped). This is the stored form.
String colorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// The category's color: the stored [hex], otherwise a stable swatch derived
/// from its name so every category is colorful from the start.
Color categoryColor(String name, {String? hex}) {
  final chosen = colorFromHex(hex);
  if (chosen != null) return chosen;
  final seed = name.trim().toLowerCase().codeUnits.fold<int>(
    7,
    (h, c) => (h * 31 + c) & 0x7FFFFFFF,
  );
  return categorySwatches[seed % categorySwatches.length];
}

/// A category color adjusted to stay readable on the current background:
/// very dark colors are lightened in dark mode, very light ones darkened in
/// light mode.
Color readableCategoryColor(Color color, Brightness brightness) {
  final hsl = HSLColor.fromColor(color);
  if (brightness == Brightness.dark && hsl.lightness < .55) {
    return hsl.withLightness(.62).toColor();
  }
  if (brightness == Brightness.light && hsl.lightness > .72) {
    return hsl.withLightness(.45).toColor();
  }
  return color;
}

/// Rounded-square category icon tinted with the category's color.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.name,
    this.iconKey,
    this.colorHex,
    this.income = false,
    this.size = 40,
  });

  final String name;
  final String? iconKey;
  final String? colorHex;
  final bool income;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = readableCategoryColor(
      categoryColor(name, hex: colorHex),
      brightness,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: brightness == Brightness.dark ? .22 : .14,
        ),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(
        categoryIcon(name, income: income, iconKey: iconKey),
        size: size * .5,
        color: color,
      ),
    );
  }
}
