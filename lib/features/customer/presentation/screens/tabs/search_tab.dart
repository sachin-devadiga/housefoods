import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/kitchen_provider.dart';
import '../../widgets/kitchen_card.dart';
import '../../widgets/kitchen_card_shimmer.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../kitchen_details_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KitchenProvider>().loadSearchHistory();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<KitchenProvider>().searchKitchens(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: Consumer<KitchenProvider>(
            builder: (context, provider, child) {
              // Case 1: Search bar empty - Show History & Suggestions
              if (_searchController.text.isEmpty) {
                return _buildSearchSuggestions(provider);
              }

              // Case 2: Loading search results
              if (provider.isLoading) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (context, index) => const KitchenCardShimmer(),
                );
              }

              // Case 3: No results found
              if (provider.kitchens.isEmpty) {
                return _buildEmptyResults(provider);
              }

              // Case 4: Results list
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: provider.kitchens.length,
                itemBuilder: (context, index) {
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: (value) {
                setState(() {}); // Update to show/hide suggestions
                _onSearch(value);
              },
              onSubmitted: (value) => _onSearch(value),
              decoration: InputDecoration(
                hintText: "Search kitchens or specialties...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          context.read<KitchenProvider>().searchKitchens('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildFilterButton(),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return Consumer<KitchenProvider>(
      builder: (context, provider, child) {
        bool hasFilters = provider.isVegOnly || provider.minRating > 0 || provider.sortBy != 'proximity';
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.tune, color: AppTheme.primaryColor),
                onPressed: _showFilters,
              ),
            ),
            if (hasFilters)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  height: 10,
                  width: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.secondaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchSuggestions(KitchenProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recent Searches", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: () => provider.clearHistory(),
                  child: const Text("Clear All", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: provider.recentSearches.take(5).map((query) => _buildSuggestionChip(query: query)).toList(),
            ),
            const SizedBox(height: 32),
          ],
          const Text("Popular Suggestions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              'North Indian',
              'Healthy',
              'Home-style',
              'Breakfast',
              'Organic',
              'South Indian',
              'Salads',
            ].map((tag) => _buildSuggestionChip(query: tag, isPopular: true)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip({required String query, bool isPopular = false}) {
    return ActionChip(
      onPressed: () {
        _searchController.text = query;
        _focusNode.unfocus();
        _onSearch(query);
      },
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey[200]!),
      label: Text(query, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
      avatar: isPopular ? const Icon(Icons.trending_up, size: 14, color: AppTheme.primaryColor) : const Icon(Icons.history, size: 14, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmptyResults(KitchenProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No kitchens found for '${_searchController.text}'",
            style: TextStyle(color: Colors.grey[600]),
          ),
          TextButton(
            onPressed: () {
              _searchController.clear();
              provider.searchKitchens('');
            },
            child: const Text("Clear Search"),
          ),
        ],
      ),
    );
  }
}
