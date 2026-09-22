import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../domain/models/kitchen_model.dart';
import '../../domain/models/menu_item_model.dart';
import '../providers/kitchen_provider.dart';
import '../providers/review_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/review_card.dart';
import '../widgets/meal_calendar_widget.dart';
import '../widgets/zomato_widgets.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import 'cart_screen.dart';

enum _MenuFilter { all, veg, nonVeg }

class KitchenDetailsScreen extends StatefulWidget {
  final KitchenModel kitchen;

  const KitchenDetailsScreen({super.key, required this.kitchen});

  @override
  State<KitchenDetailsScreen> createState() => _KitchenDetailsScreenState();
}

class _KitchenDetailsScreenState extends State<KitchenDetailsScreen> {
  _MenuFilter _menuFilter = _MenuFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<KitchenProvider>();
      provider.fetchSubscriptionPlans(widget.kitchen.id);
      provider.fetchDailyMenus(widget.kitchen.id);
      provider.fetchMenuItems(widget.kitchen.id);
      context.read<ReviewProvider>().fetchKitchenReviews(widget.kitchen.id);
      context.read<CartProvider>().loadCart();
    });
  }

  String _todayTiming() {
    try {
      final day = DateFormat('EEEE').format(DateTime.now());
      final hours = widget.kitchen.businessHours[day];
      if (hours == null) return 'Open now';
      if (hours.isClosed) return 'Closed today';
      String fmt(TimeOfDay t) {
        final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
        final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
        return '$h:${t.minute.toString().padLeft(2, '0')} $suffix';
      }

      return '${fmt(hours.openTime)} – ${fmt(hours.closeTime)} today';
    } catch (_) {
      return 'Open now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOpen = widget.kitchen.isOperatingNow;
    final cuisine = widget.kitchen.specialties.isNotEmpty
        ? widget.kitchen.specialties.take(3).join(', ')
        : 'Home-style kitchen';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(widget.kitchen.name,
                                style: const TextStyle(
                                    fontSize: 23, fontWeight: FontWeight.bold, color: ZomatoColors.ink)),
                          ),
                          RatingBadge(
                              rating: widget.kitchen.rating,
                              totalRatings: widget.kitchen.totalRatings,
                              fontSize: 14),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(cuisine, style: ZomatoText.bodyGrey),
                      const SizedBox(height: 6),
                      Text('By Chef ${widget.kitchen.chefName}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: ZomatoColors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(widget.kitchen.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ZomatoText.bodyGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(isOpen ? Icons.access_time : Icons.access_time_filled,
                              size: 16,
                              color: isOpen ? ZomatoColors.ratingGreen : ZomatoColors.brand),
                          const SizedBox(width: 4),
                          Text(
                            isOpen ? _todayTiming() : 'Currently closed • ${_todayTiming()}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isOpen ? ZomatoColors.ratingGreen : ZomatoColors.brand,
                            ),
                          ),
                          if (widget.kitchen.isVeg) ...[
                            const SizedBox(width: 12),
                            const VegMark(isVeg: true, size: 14),
                            const SizedBox(width: 4),
                            const Text('Pure Veg', style: TextStyle(fontSize: 12.5)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isOpen)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    color: const Color(0xFFFFF3E0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text('Not accepting orders right now',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const OfferStrip(text: 'FREE delivery on all orders'),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('Menu', style: ZomatoText.sectionTitle),
                      const Spacer(),
                      _menuChip('All', _MenuFilter.all),
                      const SizedBox(width: 8),
                      _menuChip('Veg', _MenuFilter.veg),
                      const SizedBox(width: 8),
                      _menuChip('Non-veg', _MenuFilter.nonVeg),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildMenuItemsList(isOpen),
                const SizedBox(height: 20),
                MealCalendarWidget(kitchenId: widget.kitchen.id),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Reviews', style: ZomatoText.sectionTitle),
                ),
                const SizedBox(height: 10),
                _buildReviewsList(),
                const SizedBox(height: 110),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _buildCartBar(),
    );
  }

  Widget _menuChip(String label, _MenuFilter value) {
    final selected = _menuFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _menuFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? ZomatoColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? ZomatoColors.ink : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                color: selected ? Colors.white : ZomatoColors.ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _buildAppBar() {
    final galleryCount = widget.kitchen.galleryImages.length + 1;
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: ZomatoColors.ink,
      actions: [
        Consumer2<AuthProvider, FavoritesProvider>(
          builder: (context, authProvider, favoritesProvider, child) {
            final uid = authProvider.userProfile?['uid'] ?? '';
            if (uid.isEmpty) return const SizedBox.shrink();
            final isFav = favoritesProvider.isFavorite(widget.kitchen.id);
            return Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? ZomatoColors.brand : ZomatoColors.ink),
                onPressed: () => favoritesProvider.toggleFavorite(uid, widget.kitchen.id),
              ),
            );
          },
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    receiverId: widget.kitchen.chefId,
                    receiverName: widget.kitchen.chefName,
                  ),
                ),
              );
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            AppCachedImage(
              imageUrl: widget.kitchen.imageUrl,
              height: 250,
              width: double.infinity,
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('$galleryCount photos',
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemsList(bool isOpen) {
    return Consumer<KitchenProvider>(
      builder: (context, provider, child) {
        if (provider.isMenuItemsLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: ZomatoColors.brand)),
          );
        }

        var items = provider.menuItems;
        if (_menuFilter == _MenuFilter.veg) {
          items = items.where((e) => e.isVeg).toList();
        } else if (_menuFilter == _MenuFilter.nonVeg) {
          items = items.where((e) => !e.isVeg).toList();
        }

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No dishes in this section yet.', style: ZomatoText.bodyGrey)),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 28, color: Color(0xFFEEEEEE)),
          itemBuilder: (context, index) => _buildMenuItemRow(items[index], isOpen),
        );
      },
    );
  }

  Widget _buildMenuItemRow(MenuItemModel item, bool isOpen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VegMark(isVeg: item.isVeg, size: 15),
              const SizedBox(height: 6),
              Text(item.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ZomatoColors.ink)),
              const SizedBox(height: 3),
              Text('₹${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ZomatoText.bodyGrey),
              ],
              const SizedBox(height: 3),
              Text('${item.preparationTime} mins',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          width: 118,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _dishPlaceholder(),
                        )
                      : _dishPlaceholder(),
                ),
                if (isOpen)
                  Positioned(
                    bottom: -14,
                    left: 14,
                    right: 14,
                    child: _buildAddControl(item),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ),
      ],
    );
  }

  Widget _dishPlaceholder() {
    return Container(
      width: 118,
      height: 96,
      color: ZomatoColors.lightGrey,
      child: const Icon(Icons.fastfood, color: Colors.grey),
    );
  }

  Widget _buildAddControl(MenuItemModel item) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final match = cartProvider.cart?.items
            .where((ci) => ci.menuItemId == item.id)
            .toList();
        final cartItem = (match != null && match.isNotEmpty) ? match.first : null;

        BoxDecoration deco = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZomatoColors.brand.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        );

        if (cartItem != null) {
          return Container(
            decoration: deco,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => cartProvider.updateItemQuantity(cartItem.id, cartItem.quantity - 1),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(Icons.remove, size: 17, color: ZomatoColors.brand),
                  ),
                ),
                Text('${cartItem.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: ZomatoColors.brand)),
                InkWell(
                  onTap: () => cartProvider.updateItemQuantity(cartItem.id, cartItem.quantity + 1),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(Icons.add, size: 17, color: ZomatoColors.brand),
                  ),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () => cartProvider.addItem(menuItemId: item.id, quantity: 1),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: deco,
            child: const Text('ADD',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ZomatoColors.brand, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
          ),
        );
      },
    );
  }

  Widget _buildCartBar() {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        if (cartProvider.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          decoration: BoxDecoration(
            color: ZomatoColors.brand,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
          ),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
            child: const SizedBox(height: 26, child: _CartBarContent()),
          ),
        );
      },
    );
  }

  Widget _buildReviewsList() {
    return Consumer<ReviewProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(color: ZomatoColors.brand)),
          );
        }

        if (provider.reviews.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.rate_review_outlined, color: Colors.grey[300], size: 40),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('No reviews yet. Be the first to order!',
                      style: TextStyle(color: ZomatoColors.grey)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: provider.reviews.length,
          itemBuilder: (context, index) => ReviewCard(review: provider.reviews[index]),
        );
      },
    );
  }
}

class _CartBarContent extends StatelessWidget {
  const _CartBarContent();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Row(
      children: [
        Text('${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text('₹${cart.subtotal.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        const Text('View Cart',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
      ],
    );
  }
}
