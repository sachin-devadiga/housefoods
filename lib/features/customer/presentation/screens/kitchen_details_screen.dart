import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../domain/models/kitchen_model.dart';
import '../providers/kitchen_provider.dart';
import '../providers/review_provider.dart';
import '../widgets/subscription_plan_card.dart';
import '../widgets/review_card.dart';
import '../widgets/meal_calendar_widget.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import 'checkout_screen.dart';

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
      context.read<ReviewProvider>().fetchKitchenReviews(widget.kitchen.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isOpen = widget.kitchen.isOpen;

    return Scaffold(
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
                          "This kitchen is currently not taking new orders.",
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
                      _buildSectionTitle("Available Subscription Plans"),
                      const SizedBox(height: 16),
                      _buildPlansList(isOpen),
                      const SizedBox(height: 32),
                      _buildSectionTitle("Customer Reviews"),
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
                  const Text("No reviews yet. Be the first to subscribe!", style: TextStyle(color: Colors.grey)),
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
