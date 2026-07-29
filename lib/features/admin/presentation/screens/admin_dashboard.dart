import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../widgets/platform_revenue_chart.dart';
import '../widgets/user_distribution_chart.dart';
import 'verify_kitchens_screen.dart';
import 'payout_management_screen.dart';
import 'admin_tickets_screen.dart';
import 'manage_coupons_screen.dart';
import 'manage_banners_screen.dart';
import 'manage_users_screen.dart';
import 'manage_kitchens_screen.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("HouseFoods Admin"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Executive Overview",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                // KPI Row
                Row(
                  children: [
                    _buildSmallStatCard(
                      "Total Users", 
                      provider.totalUsers.toString(), 
                      Icons.people, 
                      Colors.blue,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
                    ),
                    const SizedBox(width: 12),
                    _buildSmallStatCard(
                      "Kitchens", 
                      provider.totalKitchens.toString(), 
                      Icons.restaurant, 
                      Colors.orange,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageKitchensScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSmallStatCard(
                  "Total GMV", 
                  "₹${provider.totalPlatformRevenue.toStringAsFixed(0)}", 
                  Icons.payments, 
                  Colors.green,
                  fullWidth: true,
                ),
                
                const SizedBox(height: 32),
                const Text("Marketplace Health", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                UserDistributionChart(
                  totalCustomers: (provider.totalUsers - provider.totalKitchens).clamp(0, 999999),
                  totalChefs: provider.totalKitchens,
                ),

                const SizedBox(height: 32),
                const Text("Revenue Growth", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                const PlatformRevenueChart(),

                const SizedBox(height: 32),
                _buildSectionHeader("Quick Actions", () {}),
                const SizedBox(height: 16),
                _buildAdminActions(context),
                
                const SizedBox(height: 32),
                _buildSectionHeader("Recent Activity", () {}),
                const SizedBox(height: 16),
                _buildActivityItem("Subscription #1024", "Customer: Sachin", "₹1,200", "2 mins ago"),
                _buildActivityItem("Payout Request", "Chef: Rahul", "₹4,500", "1 hour ago", onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutManagementScreen()));
                }),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onTap, child: const Text("View All")),
      ],
    );
  }

  Widget _buildSmallStatCard(String title, String value, IconData icon, Color color, {bool fullWidth = false, VoidCallback? onTap}) {
    return Expanded(
      flex: fullWidth ? 0 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String trailing, String time, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(trailing, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                Text(time, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return Column(
      children: [
        _actionTile("Verify New Kitchens", Icons.verified_user, Colors.indigo, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const VerifyKitchensScreen()));
        }),
        _actionTile("Manage Payouts", Icons.account_balance_wallet, Colors.green, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PayoutManagementScreen()));
        }),
        _actionTile("Home Screen Banners", Icons.add_photo_alternate, Colors.blue, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageBannersScreen()));
        }),
        _actionTile("Promotions & Coupons", Icons.local_offer, Colors.orange, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCouponsScreen()));
        }),
        _actionTile("Support Tickets", Icons.support_agent, Colors.red, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTicketsScreen()));
        }),
      ],
    );
  }

  Widget _actionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}
