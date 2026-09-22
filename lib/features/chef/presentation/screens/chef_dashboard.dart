import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../chat/presentation/screens/inbox_screen.dart';
import '../providers/chef_provider.dart';
import '../../../customer/presentation/providers/order_provider.dart';
import '../services/new_order_watcher.dart';
import 'tabs/chef_home_tab.dart';
import 'tabs/chef_menu_tab.dart';
import 'tabs/chef_orders_tab.dart';
import 'tabs/chef_earnings_tab.dart';
import 'tabs/chef_profile_tab.dart';

class ChefDashboard extends StatefulWidget {
  const ChefDashboard({super.key});

  @override
  State<ChefDashboard> createState() => _ChefDashboardState();
}

class _ChefDashboardState extends State<ChefDashboard> {
  int _selectedIndex = 0;
  NewOrderWatcher? _watcher;
  bool _orderDialogOpen = false;

  final List<Widget> _screens = [
    const ChefHomeTab(),
    const ChefMenuTab(),
    const ChefOrdersTab(),
    const ChefEarningsTab(),
    const ChefProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _loadKitchen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _watcher = NewOrderWatcher(
        getKitchenId: () {
          if (!mounted) return '';
          final kitchen = context.read<ChefProvider>().myKitchen;
          return kitchen?['id']?.toString() ?? '';
        },
        onNewOrders: _showNewOrderAlert,
      );
      _watcher!.start();
    });
  }

  @override
  void dispose() {
    _watcher?.dispose();
    super.dispose();
  }

  void _showNewOrderAlert(List<NewOrderInfo> freshOrders) {
    if (!mounted || _orderDialogOpen) {
      // Still refresh the lists behind the scenes.
      _refreshOrderLists();
      return;
    }
    _orderDialogOpen = true;
    _refreshOrderLists();
    final total = freshOrders.fold<double>(0, (sum, o) => sum + o.amount);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active,
                    color: AppTheme.errorColor, size: 30),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('New Order!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                freshOrders.length == 1
                    ? 'Order #${freshOrders.first.id} • ₹${freshOrders.first.amount.toStringAsFixed(0)}'
                    : '${freshOrders.length} new orders • ₹${total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (freshOrders.first.address.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(freshOrders.first.address,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              const Text('Alarm rings for 30 seconds. Tap below to silence it.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _watcher?.stopAlarm();
                Navigator.pop(ctx);
                setState(() {
                  _orderDialogOpen = false;
                  _selectedIndex = 2;
                });
              },
              child: const Text('VIEW ORDER',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
              onPressed: () {
                _watcher?.stopAlarm();
                Navigator.pop(ctx);
                setState(() => _orderDialogOpen = false);
              },
              child: const Text('STOP ALARM', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshOrderLists() {
    if (!mounted) return;
    try {
      final kitchen = context.read<ChefProvider>().myKitchen;
      final kitchenId = kitchen?['id']?.toString() ?? '';
      if (kitchenId.isNotEmpty) {
        final orders = context.read<OrderProvider>();
        orders.fetchTodayDeliveries(kitchenId);
        orders.fetchKitchenOrders(kitchenId);
      }
    } catch (_) {}
  }

  void _loadKitchen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.userProfile?['uid']?.toString() ?? '';
      if (uid.isNotEmpty) {
        context.read<ChefProvider>().fetchMyKitchen(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MEALIN RESTO"),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InboxScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.secondaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Menu'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
