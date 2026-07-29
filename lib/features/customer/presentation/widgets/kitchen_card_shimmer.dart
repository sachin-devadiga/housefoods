import 'package:flutter/material.dart';
import '../../../../core/widgets/shimmer_loading.dart';

class KitchenCardShimmer extends StatelessWidget {
  const KitchenCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Placeholder
          const ShimmerLoading.rounded(height: 180),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title Placeholder
                    ShimmerLoading.rounded(
                      height: 20,
                      width: MediaQuery.of(context).size.width * 0.5,
                    ),
                    // Rating Placeholder
                    const ShimmerLoading.rounded(height: 24, width: 60),
                  ],
                ),
                const SizedBox(height: 8),
                // Chef Name Placeholder
                const ShimmerLoading.rounded(height: 14, width: 120),
                const SizedBox(height: 16),
                // Specialty Chips Placeholder
                Row(
                  children: List.generate(3, (index) => const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ShimmerLoading.rounded(height: 24, width: 80),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
