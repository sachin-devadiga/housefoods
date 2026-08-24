import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../domain/models/kitchen_model.dart';
import '../../domain/models/menu_item_model.dart';
import '../providers/kitchen_provider.dart';
import '../providers/review_provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/subscription_plan_card.dart';
import '../widgets/review_card.dart';
import '../widgets/meal_calendar_widget.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import 'checkout_screen.dart';
import 'cart_screen.dart';

class KitchenDetailsScreen extends StatefulWidget {
  final KitchenModel kitchen;

  const KitchenDetailsScreen({super.key, required this.kitchen});

  @override
  State<KitchenDetailsScreen> createState() => _KitchenDetailsScreenState();
}

class _KitchenDetailsScreenState extends State<KitchenDetailsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final bool isOpen = widget.kitchen.isOpen;

    return Scaffold(
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cartProvider, _) {
          if (cartProvider.isNotEmpty) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                'Cart (${cartProvider.itemCount}) - ₹${cartProvider.subtotal.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isOpen)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade100,
                    padding: const EdgeInsets.all(12),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "This restaurant is currently not accepting orders.",
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildKitchenHeader(),
                ),
                const Divider(height: 1),
                const SizedBox(height: 24),
                MealCalendarWidget(kitchenId: widget.kitchen.id),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Order Now"),
                      const SizedBox(height: 16),
                      _buildMenuItemsList(isOpen),
                      const SizedBox(height: 32),
                      _buildSectionTitle("Subscription Plans"),
                      const SizedBox(height: 16),
                      _buildPlansList(isOpen),
                      const SizedBox(height: 32),
                      _buildSectionTitle("Reviews"),
                      const SizedBox(height: 16),
                      _buildReviewsList(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      actions: [
        IconButton(
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
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: AppCachedImage(
          imageUrl: widget.kitchen.imageUrl,
          height: 250,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildKitchenHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.kitchen.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    widget.kitchen.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "By Chef ${widget.kitchen.chefName}",
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(widget.kitchen.address, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildPlansList(bool isOpen) {
    return Consumer<KitchenProvider>(
      builder: (context, provider, child) {
        if (provider.isPlansLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.plans.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("No active plans available."),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.plans.length,
          itemBuilder: (context, index) {
            final plan = provider.plans[index];
            return SubscriptionPlanCard(
              plan: plan,
              onSelect: () {
                if (isOpen) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckoutScreen(
                        kitchen: widget.kitchen,
                        plan: plan,
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMenuItemsList(bool isOpen) {
    return Consumer<KitchenProvider>(
      builder: (context, provider, child) {
        if (provider.isMenuItemsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.menuItems.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("No menu items available."),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.menuItems.length,
          itemBuilder: (context, index) {
            final item = provider.menuItems[index];
            return _buildMenuItemCard(item, isOpen);
          },
        );
      },
    );
  }

  Widget _buildMenuItemCard(MenuItemModel item, bool isOpen) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.fastfood, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (item.isVeg)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('VEG', style: TextStyle(color: Colors.white, fontSize: 9)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('NON-VEG', style: TextStyle(color: Colors.white, fontSize: 9)),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.preparationTime} min',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isOpen)
              Consumer<CartProvider>(
                builder: (context, cartProvider, _) {
                  final isInCart = cartProvider.cart?.items.any((ci) => ci.menuItemId == item.id) ?? false;
                  final cartItem = isInCart
                      ? cartProvider.cart?.items.firstWhere((ci) => ci.menuItemId == item.id)
                      : null;

                  if (isInCart && cartItem != null) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => cartProvider.updateItemQuantity(cartItem.id, cartItem.quantity - 1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Icon(Icons.remove, size: 18, color: AppTheme.primaryColor),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('${cartItem.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          InkWell(
                            onTap: () => cartProvider.updateItemQuantity(cartItem.id, cartItem.quantity + 1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Icon(Icons.add, size: 18, color: AppTheme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => cartProvider.addItem(
                      menuItemId: item.id,
                      quantity: 1,
                    ),
                    child: const Text('ADD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    return Consumer<ReviewProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.reviews.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, color: Colors.grey[300], size: 48),
                  const SizedBox(height: 8),
                  const Text("No reviews yet. Be the first to order!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.reviews.length,
          itemBuilder: (context, index) {
            return ReviewCard(review: provider.reviews[index]);
          },
        );
      },
    );
  }
}
