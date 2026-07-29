import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../auth/presentation/screens/login_screen.dart';
import '../../../../customer/domain/models/kitchen_model.dart';
import '../../providers/chef_provider.dart';
import '../edit_kitchen_screen.dart';
import '../manage_hours_screen.dart';

class ChefProfileTab extends StatelessWidget {
  const ChefProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = authProvider.userProfile;
    final chefProvider = Provider.of<ChefProvider>(context);
    final kitchen = chefProvider.myKitchen;
    final kitchenModel = kitchen != null
        ? KitchenModel.fromMap(kitchen, (kitchen['id'] ?? '').toString())
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildChefHeader(profile, kitchen),
          const SizedBox(height: 32),
          
          _buildOption(
            context,
            Icons.storefront,
            "Edit Kitchen Details",
            "Update name, address, and specialties",
            () {
              if (kitchenModel != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditKitchenScreen(kitchen: kitchenModel)),
                );
              }
            },
          ),
          _buildOption(
            context,
            Icons.schedule,
            "Business Hours",
            "Set your weekly opening/closing times",
            () {
              if (kitchenModel != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageHoursScreen(kitchen: kitchenModel)),
                );
              }
            },
          ),
          _buildOption(
            context,
            Icons.account_balance,
            "Bank Account",
            "Manage payout destinations",
            () {},
          ),
          _buildOption(
            context,
            Icons.person_outline,
            "Personal Information",
            "Update your profile photo",
            () {},
          ),
          
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _showLogoutDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.errorColor,
              side: const BorderSide(color: AppTheme.errorColor),
            ),
            child: const Text("Logout"),
          ),
          const SizedBox(height: 20),
          Text(
            "Chef Portal v1.0.0",
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChefHeader(Map<String, dynamic>? profile, dynamic kitchen) {
    final name = profile?['name'] ?? 'Chef';
    final kitchenMap = kitchen as Map<String, dynamic>?;
    final imageUrl = kitchenMap?['imageUrl']?.toString() ?? '';
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppTheme.secondaryColor,
          backgroundImage: imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : null,
          child: imageUrl.isEmpty
              ? const Icon(Icons.restaurant, size: 50, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          kitchenMap?['name'] ?? "My Kitchen",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          "By ${kitchenMap?['chefName'] ?? name}",
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.secondaryColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
