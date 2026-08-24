import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../customer/presentation/providers/order_provider.dart';
import '../../providers/chef_provider.dart';
import '../manage_daily_menu_screen.dart';
import '../daily_fulfillment_screen.dart';
import '../dispatch_history_screen.dart';

class ChefHomeTab extends StatefulWidget {
  const ChefHomeTab({super.key});

  @override
  State<ChefHomeTab> createState() => _ChefHomeTabState();
}

class _ChefHomeTabState extends State<ChefHomeTab> {
  @override
  void initState() {
    super.initState();
    _loadOperationalData();
  }

  Future<void> _loadOperationalData() async {
    final chefProvider = context.read<ChefProvider>();
    if (chefProvider.myKitchen != null) {
      final kitchenId = chefProvider.myKitchen!['id'].toString();
      await context.read<OrderProvider>().fetchTodayDeliveries(kitchenId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    
    return Consumer<ChefProvider>(
      builder: (context, provider, child) {
        final kitchen = provider.myKitchen;
        bool isOpen = kitchen?['isOpen'] ?? false;

        return RefreshIndicator(
          onRefresh: _loadOperationalData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBanner(context, provider, isOpen),
                const SizedBox(height: 24),
                Text(
                  "Hello, ${kitchen?['chefName'] ?? 'Chef'}!",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Here's your performance snapshot",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 24),
                
                // Stats Row
                Row(
                  children: [
                    _buildStatCard("Active Subs", orderProvider.customerOrders.length.toString(), Icons.people, Colors.blue),
                    const SizedBox(width: 12),
                    // Reactive Today's Meal Count
                    _buildStatCard(
                      "Today's Meals", 
                      orderProvider.todayDeliveries.length.toString(), 
                      Icons.soup_kitchen, 
                      Colors.orange,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyFulfillmentScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatCard("Today's Revenue", "₹${provider.dailyEarnings.toStringAsFixed(0)}", Icons.payments, AppTheme.secondaryColor, fullWidth: true),
                
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Preparation",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyFulfillmentScreen())), 
                      child: const Text("View Dispatch List"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Business Control Tiles
                _buildControlTile(
                  context,
                  "Daily Menu Planner",
                  "Schedule your upcoming meals",
                  Icons.calendar_month,
                  Colors.deepPurple,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageDailyMenuScreen())),
                ),
                const SizedBox(height: 12),
                _buildControlTile(
                  context,
                  "Delivery Dispatch",
                  "Manage today's active meal list",
                  Icons.delivery_dining,
                  Colors.blue,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyFulfillmentScreen())),
                ),
                const SizedBox(height: 12),
                _buildControlTile(
                  context,
                  "Dispatch History",
                  "View past deliveries",
                  Icons.history,
                  Colors.teal,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DispatchHistoryScreen())),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(BuildContext context, ChefProvider provider, bool isOpen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOpen ? AppTheme.secondaryColor.withValues(alpha: 0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOpen ? AppTheme.secondaryColor : Colors.grey[400]!),
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.check_circle : Icons.pause_circle_filled,
            color: isOpen ? AppTheme.secondaryColor : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? "Your Kitchen is OPEN" : "Your Kitchen is CLOSED",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOpen ? AppTheme.secondaryColor : Colors.grey[800],
                  ),
                ),
                Text(
                  isOpen ? "Customers can see and subscribe" : "Hidden from search results",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: isOpen,
            activeThumbColor: AppTheme.secondaryColor,
            onChanged: (val) => provider.toggleKitchenAvailability(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool fullWidth = false, VoidCallback? onTap}) {
    return Expanded(
      flex: fullWidth ? 0 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
