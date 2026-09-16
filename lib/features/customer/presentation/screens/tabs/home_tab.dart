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
import '../../../../../meal_voice/meal_voice_controller.dart';
import '../../../../../meal_voice/meal_voice_screen.dart';
import '../../../../ai_assistant/presentation/screens/ai_chat_screen.dart';

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

                // 2. Ask MEAL AI Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AiChatScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ask MEAL AI',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'Get personalized food recommendations',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Category Filter
                const SliverToBoxAdapter(child: CategorySelector()),

                // 4. Promo Banners
                const SliverToBoxAdapter(child: PromoCarousel()),

                // 5. Quick Cuisine Grid
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

                // 6. Curated Collection: Top Rated
                if (provider.topRatedKitchens.isNotEmpty && !provider.isLoading)
                  SliverToBoxAdapter(
                    child: KitchenHorizontalList(
                      title: "Top Rated Near You",
                      kitchens: provider.topRatedKitchens,
                    ),
                  ),

                // 7. Curated Collection: Healthy Picks
                if (provider.healthyKitchens.isNotEmpty && !provider.isLoading)
                  SliverToBoxAdapter(
                    child: KitchenHorizontalList(
                      title: "Healthy Picks",
                      kitchens: provider.healthyKitchens,
                    ),
                  ),

                // 8. Main Feed Header
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      "All Restaurants Near You",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // 9. Initial Loading State (Shimmers)
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

                // 10. Error State
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

                // 11. Kitchen/Restaurant List
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

                // 12. Pagination Loading Footer
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'voice',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MealVoiceScreen()),
              );
            },
            backgroundColor: Colors.deepPurple,
            child: Consumer<MealVoiceController>(
              builder: (context, vc, _) => Icon(
                vc.isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'map',
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
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
