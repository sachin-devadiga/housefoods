import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/role_config.dart';
import '../../../../core/services/token_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../chef/presentation/screens/chef_dashboard.dart';
import '../../../customer/presentation/screens/customer_dashboard.dart';
import '../../../delivery_partner/presentation/screens/delivery_partner_dashboard.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String? email;
  final String role;
  const ProfileSetupScreen({super.key, this.email, required this.role});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  final TokenService _tokenService = TokenService();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<String> _getEmail() async {
    if (widget.email != null && widget.email!.isNotEmpty) {
      return widget.email!;
    }
    final email = await _tokenService.getEmail();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    throw Exception('Email not available');
  }

  void _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your name")),
      );
      return;
    }

    String email;
    try {
      email = await _getEmail();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please login again.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.setupProfile(
      email: email,
      name: _nameController.text.trim(),
      role: widget.role,
      onSuccess: () {
        if (mounted) _navigateToDashboard();
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
          );
        }
      },
    );

    if (mounted) setState(() => _isLoading = false);
  }

  void _navigateToDashboard() {
    final resolvedRole = RoleConfig.isDedicated ? RoleConfig.roleName : widget.role;
    Widget destination;
    if (resolvedRole == 'customer') {
      destination = const CustomerDashboard();
    } else if (resolvedRole == 'chef') {
      destination = const ChefDashboard();
    } else {
      destination = const DeliveryPartnerDashboard();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  String get _roleTitle {
    switch (widget.role) {
      case 'chef':
        return 'Chef';
      case 'delivery_partner':
        return 'Delivery Partner';
      default:
        return 'Customer';
    }
  }

  IconData get _roleIcon {
    switch (widget.role) {
      case 'chef':
        return Icons.restaurant;
      case 'delivery_partner':
        return Icons.delivery_dining;
      default:
        return Icons.fastfood;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome to Mealin!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("Tell us your name to get started."),
            const SizedBox(height: 32),
            if (!RoleConfig.isDedicated)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                ),
                child: Row(
                  children: [
                    Icon(_roleIcon, color: AppTheme.primaryColor),
                    const SizedBox(width: 15),
                    Text(_roleTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 48),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text("Get Started"),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
