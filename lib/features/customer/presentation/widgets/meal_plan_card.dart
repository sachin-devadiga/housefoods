import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../domain/models/subscription_model.dart';

/// One meal plan in the browse feed. Shows the kitchen, the distance, the
/// plan name, the starting price and the weekly preview derived from `slots`.
/// Anything the backend did not send is simply omitted — never invented.
class MealPlanCard extends StatelessWidget {
  final MealPlanModel plan;
  final VoidCallback onTap;

  const MealPlanCard({
    super.key,
    required this.plan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final distance = plan.distanceLabel;
    final preview = plan.weeklyPreview;
    final price = plan.startingPrice;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AppCachedImage(
                    imageUrl: plan.imageUrl,
                    width: 92,
                    height: 92,
                    borderRadius: 12,
                  ),
                  if (plan.isVeg)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF0E8A00), width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0E8A00),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.kitchenName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (distance != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.near_me, size: 12, color: AppTheme.primaryColor),
                          const SizedBox(width: 3),
                          Text(
                            distance,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF696969)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (price != null)
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        if (price != null && plan.activePrices.isNotEmpty)
                          const Text(
                            ' /period',
                            style: TextStyle(fontSize: 12, color: Color(0xFF696969)),
                          ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: Colors.grey),
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

/// Loading placeholder for [MealPlanCard]. Same geometry as the real card so
/// the feed does not jump when data lands.
class MealPlanCardShimmer extends StatelessWidget {
  const MealPlanCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoading.rounded(width: 92, height: 92, shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoading.rounded(height: 12, width: 120),
                SizedBox(height: 8),
                ShimmerLoading.rounded(height: 16, width: 180),
                SizedBox(height: 8),
                ShimmerLoading.rounded(height: 12, width: 140),
                SizedBox(height: 12),
                ShimmerLoading.rounded(height: 16, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}