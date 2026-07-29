import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../auth/data/repositories/user_repository_impl.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../auth/presentation/screens/address_book_screen.dart';
import '../../../../auth/presentation/screens/edit_profile_screen.dart';
import '../../../../auth/presentation/screens/login_screen.dart';
import '../../../../auth/presentation/screens/settings_screen.dart';
import '../../../../auth/presentation/screens/dietary_setup_screen.dart';
import '../../../../support/presentation/screens/user_tickets_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _navigateToEditProfile(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isEmpty) return;

    _showLoading(context);

    try {
      final userModel = await UserRepositoryImpl().getUser(uid);
      if (context.mounted) {
        Navigator.pop(context);
        if (userModel != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditProfileScreen(user: userModel)),
          );
        }
      }
    } catch (e) {
      _handleError(context, e);
    }
  }

  Future<void> _navigateToDietarySetup(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isEmpty) return;

    _showLoading(context);

    try {
      final userModel = await UserRepositoryImpl().getUser(uid);
      if (context.mounted) {
        Navigator.pop(context);
        if (userModel != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DietarySetupScreen(user: userModel)),
          );
        }
      }
    } catch (e) {
      _handleError(context, e);
    }
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _handleError(BuildContext context, dynamic e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = authProvider.userProfile;
    final name = profile?['name'] ?? 'HouseFoods User';
    final phone = profile?['phone'] ?? '';
    final photoUrl = profile?['photoUrl'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            phone,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          
          _buildProfileOption(
            Icons.edit, 
            "Edit Profile", 
            () => _navigateToEditProfile(context)
          ),
          _buildProfileOption(
            Icons.restaurant_menu_outlined, 
            "Food Preferences", 
            () => _navigateToDietarySetup(context)
          ),
          _buildProfileOption(
            Icons.location_on, 
            "Saved Addresses", 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressBookScreen()))
          ),
          _buildProfileOption(Icons.payment, "Payment Methods", () {}),
          _buildProfileOption(
            Icons.help_outline, 
            "Help & Support", 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserTicketsScreen()))
          ),
          _buildProfileOption(
            Icons.settings_outlined, 
            "Settings & Privacy", 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))
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
            "Version 1.0.0",
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
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
