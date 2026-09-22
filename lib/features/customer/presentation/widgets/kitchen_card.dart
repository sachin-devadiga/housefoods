import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/kitchen_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/kitchen_provider.dart';
import 'zomato_widgets.dart';

class KitchenCard extends StatelessWidget {
  final KitchenModel kitchen;
  final VoidCallback onTap;

  const KitchenCard({
    super.key,
    required this.kitchen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    final kitchenProvider = Provider.of<KitchenProvider>(context);
    final distance = kitchenProvider.getDistanceTo(kitchen.id);

    final bool isOperating = kitchen.isOperatingNow;
    final cuisine = kitchen.specialties.isNotEmpty
        ? kitchen.specialties.take(2).join(' • ')
        : (kitchen.categories.isNotEmpty ? kitchen.categories.take(2).join(' • ') : 'Home-style kitchen');

    return GestureDetector(
      onTap: isOperating ? onTap : null,
      child: Opacity(
        opacity: isOperating ? 1.0 : 0.75,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ColorFiltered(
                    colorFilter: isOperating
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                        : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                    child: AppCachedImage(
                      imageUrl: kitchen.imageUrl,
                      height: 190,
                      width: double.infinity,
                      borderRadius: 14,
                    ),
                  ),
                  // Offer banner pinned to image bottom-left, Zomato-style.
                  if (isOperating)
                    Positioned(
                      bottom: 0,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: const BoxDecoration(
                          color: ZomatoColors.offerBlue,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                        child: const Text(
                          'FREE DELIVERY',
                          style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (uid.isNotEmpty)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Consumer<FavoritesProvider>(
                        builder: (context, provider, child) {
                          final isFav = provider.isFavorite(kitchen.id);
                          return GestureDetector(
                            onTap: () => provider.toggleFavorite(uid, kitchen.id),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? ZomatoColors.brand : Colors.grey,
                                size: 19,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (kitchen.isVeg)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VegMark(isVeg: true, size: 13),
                            SizedBox(width: 4),
                            Text('Pure Veg',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  if (!isOperating)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'CURRENTLY CLOSED',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            kitchen.name,
                            style: ZomatoText.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RatingBadge(rating: kitchen.rating, totalRatings: kitchen.totalRatings),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cuisine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZomatoText.bodyGrey,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 15, color: ZomatoColors.grey),
                        const SizedBox(width: 4),
                        Text(
                          deliveryTimeFor(distance),
                          style: const TextStyle(fontSize: 12.5, color: ZomatoColors.ink, fontWeight: FontWeight.w500),
                        ),
                        if (distance != null) ...[
                          const Text('  •  ', style: TextStyle(color: ZomatoColors.grey)),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: ZomatoText.bodyGrey,
                          ),
                        ],
                        const Spacer(),
                        Text(
                          'By ${kitchen.chefName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZomatoText.bodyGrey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
