import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import 'manage_users_screen.dart';
import 'manage_kitchens_screen.dart';
import 'payout_management_screen.dart';
import 'verify_kitchens_screen.dart';
import 'verify_delivery_partners_screen.dart';
import 'manage_coupons_screen.dart';
import 'manage_banners_screen.dart';
import 'admin_tickets_screen.dart';
import 'admin_orders_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchPlatformStats();
      context.read<AdminProvider>().fetchPendingDocuments();
    });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  provider.fetchPlatformStats();
                  provider.fetchPendingDocuments();
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _showLogoutDialog,
              ),
            ],
          ),
          body: provider.isLoading && provider.totalUsers == 0
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    await provider.fetchPlatformStats();
                    await provider.fetchPendingDocuments();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKPIs(provider),
                        const SizedBox(height: 20),
                        _buildQuickActions(),
                        const SizedBox(height: 20),
                        _buildPendingSection(provider),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildKPIs(AdminProvider provider) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _kpiCard(Icons.person, '${provider.totalCustomers}', 'Customers', Colors.blue),
        _kpiCard(Icons.restaurant, '${provider.totalChefs}', 'Chefs', Colors.orange),
        _kpiCard(Icons.local_shipping, '${provider.totalDeliveryPartners}', 'Riders', Colors.green),
        _kpiCard(Icons.receipt_long, '${provider.totalOrders}', 'Orders', Colors.purple),
        _kpiCard(Icons.monetization_on, '₹${provider.totalPlatformRevenue.toStringAsFixed(0)}', 'Revenue', Colors.teal),
        _kpiCard(Icons.pending_actions, '${provider.pendingKitchenCount + provider.pendingDocumentCount}', 'Pending', Colors.red),
      ],
    );
  }

  Widget _kpiCard(IconData icon, String value, String label, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _actionTile(Icons.verified_user, 'Verify Kitchens', '${context.read<AdminProvider>().pendingKitchenCount} pending', Colors.orange, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyKitchensScreen()));
      }),
      _actionTile(Icons.badge, 'Verify Riders', '${context.read<AdminProvider>().pendingDocumentCount} pending', Colors.blue, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyDeliveryPartnersScreen()));
      }),
      _actionTile(Icons.receipt_long, 'Orders', 'View all orders', Colors.purple, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersScreen()));
      }),
      _actionTile(Icons.monetization_on, 'Payouts', 'Manage payouts', Colors.green, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutManagementScreen()));
      }),
      _actionTile(Icons.people, 'Users', 'Manage users', Colors.teal, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()));
      }),
      _actionTile(Icons.restaurant_menu, 'Kitchens', 'Manage kitchens', Colors.deepOrange, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageKitchensScreen()));
      }),
      _actionTile(Icons.discount, 'Coupons', 'Manage coupons', Colors.indigo, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCouponsScreen()));
      }),
      _actionTile(Icons.photo_library, 'Banners', 'Manage banners', Colors.pink, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageBannersScreen()));
      }),
      _actionTile(Icons.support_agent, 'Tickets', 'Support tickets', Colors.brown, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTicketsScreen()));
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: actions,
        ),
      ],
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[500]), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingSection(AdminProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pending Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (provider.pendingKitchenCount > 0)
          _pendingCard(Icons.restaurant, '${provider.pendingKitchenCount} kitchens awaiting approval', Colors.orange, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyKitchensScreen()));
          }),
        if (provider.pendingDocumentCount > 0)
          _pendingCard(Icons.badge, '${provider.pendingDocumentCount} rider documents awaiting review', Colors.blue, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyDeliveryPartnersScreen()));
          }),
        if (provider.pendingKitchenCount == 0 && provider.pendingDocumentCount == 0)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No pending reviews', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pendingCard(IconData icon, String text, Color color, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(text, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
