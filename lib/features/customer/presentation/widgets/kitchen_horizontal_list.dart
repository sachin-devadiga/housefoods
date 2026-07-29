import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../domain/models/kitchen_model.dart';
import '../screens/kitchen_details_screen.dart';

class KitchenHorizontalList extends StatelessWidget {
  final String title;
  final List<KitchenModel> kitchens;

  const KitchenHorizontalList({
    super.key,
    required this.title,
    required this.kitchens,
  });

  @override
  Widget build(BuildContext context) {
    if (kitchens.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {}, // Action for "See All"
                child: const Text("See All", style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: kitchens.length,
            itemBuilder: (context, index) {
              final kitchen = kitchens[index];
              return _KitchenMiniCard(kitchen: kitchen);
            },
          ),
        ),
      ],
    );
  }
}

class _KitchenMiniCard extends StatelessWidget {
  final KitchenModel kitchen;

  const _KitchenMiniCard({required this.kitchen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => KitchenDetailsScreen(kitchen: kitchen),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCachedImage(
              imageUrl: kitchen.imageUrl,
              height: 120,
              width: 160,
              borderRadius: 12,
            ),
            const SizedBox(height: 8),
            Text(
              kitchen.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  kitchen.rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Text(
                  "(${kitchen.totalRatings})",
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              kitchen.specialties.take(1).join(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
