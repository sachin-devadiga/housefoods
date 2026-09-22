import 'package:flutter/material.dart';

/// Zomato-style design tokens + shared components for the customer app.
/// Kept separate from [AppTheme] so the chef/rider apps keep their branding.
class ZomatoColors {
  static const Color brand = Color(0xFFE23744);
  static const Color brandDark = Color(0xFFCB202D);
  static const Color ink = Color(0xFF1C1C1C);
  static const Color grey = Color(0xFF696969);
  static const Color lightGrey = Color(0xFFF4F4F4);
  static const Color ratingGreen = Color(0xFF256F46);
  static const Color ratingAmber = Color(0xFFB7791F);
  static const Color offerBlue = Color(0xFF256FEF);
  static const Color vegGreen = Color(0xFF0E8A00);
  static const Color nonVegRed = Color(0xFFB9402B);
}

class ZomatoText {
  static const TextStyle sectionTitle =
      TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZomatoColors.ink);
  static const TextStyle cardTitle =
      TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ZomatoColors.ink);
  static const TextStyle bodyGrey = TextStyle(fontSize: 13, color: ZomatoColors.grey);
}

/// Green rating pill with star, Zomato-style. Amber when rating < 4.
class RatingBadge extends StatelessWidget {
  final double rating;
  final int? totalRatings;
  final double fontSize;

  const RatingBadge({super.key, required this.rating, this.totalRatings, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final bg = rating >= 4.0 ? ZomatoColors.ratingGreen : ZomatoColors.ratingAmber;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : 'New',
                style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 3),
              Icon(Icons.star, size: fontSize, color: Colors.white),
            ],
          ),
        ),
        if (totalRatings != null && totalRatings! > 0) ...[
          const SizedBox(width: 5),
          Text(
            '(${_compact(totalRatings!)})',
            style: TextStyle(fontSize: fontSize - 1, color: ZomatoColors.grey),
          ),
        ],
      ],
    );
  }

  String _compact(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Zomato-style veg / non-veg square-dot mark.
class VegMark extends StatelessWidget {
  final bool isVeg;
  final double size;

  const VegMark({super.key, required this.isVeg, this.size = 15});

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? ZomatoColors.vegGreen : ZomatoColors.nonVegRed;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: isVeg
            ? Icon(Icons.circle, size: size * 0.52, color: color)
            : Icon(Icons.play_arrow, size: size * 0.62, color: color),
      ),
    );
  }
}

/// Blue offer strip shown under restaurant images, Zomato-style.
class OfferStrip extends StatelessWidget {
  final String text;

  const OfferStrip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ZomatoColors.offerBlue.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, size: 15, color: ZomatoColors.offerBlue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: ZomatoColors.offerBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill filter chip used in the filter/sort bar.
class ZFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const ZFilterChip({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ZomatoColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? ZomatoColors.ink : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? Colors.white : ZomatoColors.grey),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : ZomatoColors.ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estimated delivery time from distance, shown Zomato-style ("25-30 min").
String deliveryTimeFor(double? distanceKm) {
  if (distanceKm == null) return '30-40 min';
  final base = 15 + distanceKm * 4;
  final lo = base.round();
  return '$lo-${lo + 10} min';
}

/// Cuisines for the "What's on your mind?" strip. Tapping searches real listings.
const List<Map<String, dynamic>> zomatoCuisines = [
  {'label': 'Biryani', 'icon': Icons.rice_bowl},
  {'label': 'Pizza', 'icon': Icons.local_pizza},
  {'label': 'Burger', 'icon': Icons.lunch_dining},
  {'label': 'Chinese', 'icon': Icons.ramen_dining},
  {'label': 'South Indian', 'icon': Icons.set_meal},
  {'label': 'North Indian', 'icon': Icons.dinner_dining},
  {'label': 'Desserts', 'icon': Icons.icecream},
  {'label': 'Healthy', 'icon': Icons.spa},
];
