import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/kitchen_card.dart';
import '../../widgets/kitchen_card_shimmer.dart';
import '../../widgets/kitchen_horizontal_list.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../widgets/zomato_widgets.dart';
import '../kitchen_details_screen.dart';
import '../kitchen_map_screen.dart';
import '../search_page.dart';
import '../../../../../meal_voice/meal_voice_controller.dart';
import '../../../../../meal_voice/meal_voice_screen.dart';
import '../../../../ai_assistant/presentation/screens/ai_chat_screen.dart';

enum _HomeMode { delivery, dining, nightlife }

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();
  _HomeMode _mode = _HomeMode.delivery;

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

  Future<void> _refresh() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isNotEmpty) {
      await context.read<FavoritesProvider>().loadFavorites(uid);
    }
    if (!mounted) return;
    await context.read<KitchenProvider>().fetchKitchens();
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: ZomatoColors.brand,
        onRefresh: _refresh,
        child: Consumer<KitchenProvider>(
          builder: (context, provider, child) {
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // 1. Location header
                SliverToBoxAdapter(child: _buildLocationHeader()),
                // 2. Search bar
                SliverToBoxAdapter(child: _buildSearchBar()),
                // 3. Delivery / Dining / Nightlife
                SliverToBoxAdapter(child: _buildModeTabs()),
                if (_mode != _HomeMode.delivery)
                  SliverFillRemaining(child: _buildComingSoon())
                else ...[
                  // 4. Top offers
                  SliverToBoxAdapter(child: _buildOffers(provider)),
                  // 5. Cuisines
                  SliverToBoxAdapter(child: _buildCuisines()),
                  // 6. Top rated horizontal
                  if (provider.topRatedKitchens.isNotEmpty && !provider.isLoading)
                    SliverToBoxAdapter(
                      child: KitchenHorizontalList(
                        title: 'Top Rated Near You',
                        kitchens: provider.topRatedKitchens,
                      ),
                    ),
                  // 7. Filter / sort bar
                  SliverToBoxAdapter(child: _buildFilterBar(provider)),
                  // 8. Feed header
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Text('All Restaurants Near You', style: ZomatoText.sectionTitle),
                    ),
                  ),
                  // 9. Shimmers
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
                  // 10. Error
                  if (provider.error != null && provider.kitchens.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: ZomatoColors.brand),
                            const SizedBox(height: 16),
                            Text('Error: ${provider.error}'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: ZomatoColors.brand),
                              onPressed: () => provider.fetchKitchens(),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 11. Empty
                  if (!provider.isLoading && provider.error == null && provider.kitchens.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            const Text('No restaurants found',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('Try a different search or clear filters',
                                style: ZomatoText.bodyGrey),
                          ],
                        ),
                      ),
                    ),
                  // 12. Restaurant feed
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
                  if (provider.isLoading && provider.kitchens.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                            child: CircularProgressIndicator(color: ZomatoColors.brand)),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
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
            backgroundColor: ZomatoColors.brand,
            icon: const Icon(Icons.map_outlined, color: Colors.white),
            label: const Text('View on Map', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLocationHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: ZomatoColors.brand, size: 24),
          const SizedBox(width: 6),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deliver to',
                    style: TextStyle(fontSize: 12, color: ZomatoColors.grey)),
                Text('Your current location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZomatoColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AiChatScreen()),
            ),
            icon: const Icon(Icons.auto_awesome, color: ZomatoColors.brand),
            tooltip: 'Ask MEAL AI',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchPage()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: ZomatoColors.lightGrey,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: ZomatoColors.brand, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text('Search restaurants, dishes...',
                    style: TextStyle(color: ZomatoColors.grey, fontSize: 15)),
              ),
              Icon(Icons.mic_none, color: ZomatoColors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    Widget tab(String label, IconData icon, _HomeMode mode) {
      final selected = _mode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mode = mode),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? ZomatoColors.brand.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                bottom: BorderSide(
                    color: selected ? ZomatoColors.brand : Colors.transparent, width: 2.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: selected ? ZomatoColors.brand : ZomatoColors.grey),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? ZomatoColors.brand : ZomatoColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Row(
        children: [
          tab('Delivery', Icons.delivery_dining, _HomeMode.delivery),
          tab('Dining Out', Icons.table_restaurant, _HomeMode.dining),
          tab('Nightlife', Icons.nightlife, _HomeMode.nightlife),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    final isDining = _mode == _HomeMode.dining;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isDining ? Icons.table_restaurant : Icons.nightlife,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 14),
          Text(isDining ? 'Dining Out' : 'Nightlife',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Launching soon in your city', style: ZomatoText.bodyGrey),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ZomatoColors.brand),
            onPressed: () => setState(() => _mode = _HomeMode.delivery),
            child: const Text('Order Delivery Instead', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildOffers(KitchenProvider provider) {
    final cards = [
      {
        'title': 'FREE Delivery',
        'subtitle': 'On every order',
        'icon': Icons.delivery_dining,
        'colors': [ZomatoColors.offerBlue, const Color(0xFF1B4FB8)],
      },
      {
        'title': 'Top Rated',
        'subtitle': '4.5★ kitchens near you',
        'icon': Icons.star,
        'colors': [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
      },
      {
        'title': 'Pure Veg',
        'subtitle': 'Veg-only kitchens',
        'icon': Icons.spa,
        'colors': [const Color(0xFF6A1B9A), const Color(0xFF4A148C)],
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text('Top Offers For You', style: ZomatoText.sectionTitle),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = cards[i];
              return GestureDetector(
                onTap: () {
                  if (i == 1) {
                    provider.setSortBy('rating');
                  } else if (i == 2) {
                    provider.setVegFilter(true);
                  } else {
                    provider.setSortBy('proximity');
                  }
                },
                child: Container(
                  width: 230,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: (c['colors'] as List<Color>),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(c['title'] as String,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Text(c['subtitle'] as String,
                                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Icon(c['icon'] as IconData, color: Colors.white70, size: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCuisines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Text("What's on your mind?", style: ZomatoText.sectionTitle),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: zomatoCuisines.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final c = zomatoCuisines[i];
              return GestureDetector(
                onTap: () {
                  context.read<KitchenProvider>().searchKitchens(c['label'] as String);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchPage()),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: ZomatoColors.lightGrey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Icon(c['icon'] as IconData, size: 30, color: ZomatoColors.brand),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 70,
                      child: Text(
                        c['label'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(KitchenProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: [
          ZFilterChip(
            label: 'Sort',
            icon: Icons.sort,
            selected: false,
            onTap: _openFilters,
          ),
          const SizedBox(width: 8),
          ZFilterChip(
            label: 'Pure Veg',
            icon: Icons.spa,
            selected: provider.isVegOnly,
            onTap: () => provider.setVegFilter(!provider.isVegOnly),
          ),
          const SizedBox(width: 8),
          ZFilterChip(
            label: 'Rating 4.0+',
            icon: Icons.star_outline,
            selected: provider.minRating >= 4.0,
            onTap: () => provider.setMinRating(provider.minRating >= 4.0 ? 0.0 : 4.0),
          ),
          const SizedBox(width: 8),
          ZFilterChip(
            label: provider.sortBy == 'rating' ? 'Top Rated ✓' : 'Nearest',
            icon: Icons.timer_outlined,
            selected: provider.sortBy == 'rating',
            onTap: () => provider.setSortBy(provider.sortBy == 'rating' ? 'proximity' : 'rating'),
          ),
        ],
      ),
    );
  }
}
