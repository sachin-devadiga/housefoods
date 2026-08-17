import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../customer/presentation/providers/order_provider.dart';
import '../../providers/chef_provider.dart';
import '../payout_request_screen.dart';
import '../../widgets/revenue_chart.dart';

class ChefEarningsTab extends StatelessWidget {
  const ChefEarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChefProvider, OrderProvider>(
      builder: (context, chefProvider, orderProvider, child) {
        if (chefProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Financial Overview",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              _buildEarningsCard(
                "Total Revenue", 
                "₹${chefProvider.totalEarnings.toStringAsFixed(0)}", 
                Icons.account_balance_wallet, 
                AppTheme.secondaryColor
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSmallCard("This Month", "₹${chefProvider.monthlyEarnings.toStringAsFixed(0)}", Colors.blue),
                  const SizedBox(width: 12),
                  _buildSmallCard("Pending Payout", "₹${chefProvider.pendingPayout.toStringAsFixed(0)}", Colors.orange),
                ],
              ),

              const SizedBox(height: 32),
              const Text(
                "Earnings Trend (Last 7 Days)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Visual Analytics Chart (real data from orders)
              RevenueChart(weeklyData: chefProvider.weeklyEarnings),
              
              const SizedBox(height: 32),
              const Text(
                "Recent Transactions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              if (orderProvider.customerOrders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text("No transactions yet.", style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orderProvider.customerOrders.length,
                  itemBuilder: (context, index) {
                    final order = orderProvider.customerOrders[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[100],
                        child: const Icon(Icons.payment, color: AppTheme.secondaryColor, size: 20),
                      ),
                      title: Text(order.planName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(order.createdAt)),
                      trailing: Text(
                        "+₹${order.amount}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                      ),
                    );
                  },
                ),
                
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PayoutRequestScreen(
                        availableBalance: chefProvider.availableBalance,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Request Payout"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarningsCard(String title, String amount, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String title, String amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const SizedBox(height: 4),
            Text(amount, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
