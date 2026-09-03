import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/kitchen_card.dart';
import '../../widgets/kitchen_card_shimmer.dart';
import '../../widgets/category_selector.dart';
import '../../widgets/promo_carousel.dart';
import '../../widgets/kitchen_horizontal_list.dart';
import '../kitchen_details_screen.dart';
import '../kitchen_map_screen.dart';
import '../../../../../core/theme/app_theme.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.userProfile?['uid'] ?? '';
      if (uid.isNotEmpty) {
        context.read<FavoritesProvider>().loadFavorites(uid);
      }
      context.read<KitchenProvider>().fetchKitchens();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<KitchenProvider>().fetchMoreKitchens();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final uid = authProvider.userProfile?['uid'] ?? '';
          if (uid.isNotEmpty) {
            await context.read<FavoritesProvider>().loadFavorites(uid);
          }
          if (!context.mounted) return;
          await context.read<KitchenProvider>().fetchKitchens();
        },
        child: Consumer<KitchenProvider>(
          builder: (context, provider, child) {
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // 1. Location + Search Header
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Delivering to your location',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'What would you like to eat?',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Category Filter
                const SliverToBoxAdapter(child: CategorySelector()),

                // 3. Promo Banners
                const SliverToBoxAdapter(child: PromoCarousel()),

                // 4. Quick Cuisine Grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "What's on your mind?",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Curated Collection: Top Rated
                if (provider.topRatedKitchens.isNotEmpty && !provider.isLoading)
                  SliverToBoxAdapter(
                    child: KitchenHorizontalList(
                      title: "Top Rated Near You",
                      kitchens: provider.topRatedKitchens,
                    ),
                  ),

                // 6. Curated Collection: Healthy Picks
                if (provider.healthyKitchens.isNotEmpty && !provider.isLoading)
                  SliverToBoxAdapter(
                    child: KitchenHorizontalList(
                      title: "Healthy Picks",
                      kitchens: provider.healthyKitchens,
                    ),
                  ),

                // 7. Main Feed Header
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      "All Restaurants Near You",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // 8. Initial Loading State (Shimmers)
                if (provider.isLoading && provider.kitchens.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const KitchenCardShimmer(),
                        childCount: 3,
                      ),
                    ),
                  ),

                // 9. Error State
                if (provider.error != null && provider.kitchens.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text("Error: ${provider.error}"),
                          ElevatedButton(
                            onPressed: () => provider.fetchKitchens(),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 10. Kitchen/Restaurant List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final kitchen = provider.kitchens[index];
                        return KitchenCard(
                          kitchen: kitchen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => KitchenDetailsScreen(kitchen: kitchen),
                              ),
                            );
                          },
                        );
                      },
                      childCount: provider.kitchens.length,
                    ),
                  ),
                ),

                // 11. Pagination Loading Footer
                if (provider.isLoading && provider.kitchens.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const KitchenMapScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.map_outlined, color: Colors.white),
        label: const Text("View on Map", style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
