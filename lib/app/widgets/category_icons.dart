import 'package:flutter/material.dart';

/// Picks a recognisable icon from a category name so lists are scannable
/// without reading. Falls back to a generic icon for custom names.
IconData categoryIcon(String name, {bool income = false}) {
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
