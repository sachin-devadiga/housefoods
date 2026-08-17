import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/token_service.dart';
import '../../../auth/data/repositories/user_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart' as app;
import '../../../auth/presentation/screens/edit_profile_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'delivery_document_upload_screen.dart';

class DeliveryPartnerProfileTab extends StatefulWidget {
  const DeliveryPartnerProfileTab({super.key});

  @override
  State<DeliveryPartnerProfileTab> createState() => _DeliveryPartnerProfileTabState();
}

class _DeliveryPartnerProfileTabState extends State<DeliveryPartnerProfileTab> {
  String _name = 'Delivery Partner';
  String _email = '';
  String? _avatarUrl;
  bool _isAvailable = true;
  bool _isVerified = false;
  late ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: AppConstants.apiBaseUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAuth();
    });
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _initAuth() async {
    final token = await TokenService().getAccessToken();
    if (token != null) _api.setToken(token);
    _loadProfile();
    _loadAvailability();
  }

  void _loadProfile() {
    try {
      final authProvider = Provider.of<app.AuthProvider>(context, listen: false);
      final profile = authProvider.userProfile;
      if (profile != null) {
        _name = profile['name']?.toString() ?? 'Delivery Partner';
        _email = profile['email']?.toString() ?? '';
        _avatarUrl = profile['avatar_url']?.toString() ?? profile['avatarUrl']?.toString();
        _isVerified = profile['is_verified'] == true;
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future<void> _loadAvailability() async {
    try {
      final data = await _api.get(AppConstants.deliveryAvailabilityEndpoint);
      _isAvailable = data['is_available'] == true;
      _isVerified = data['is_verified'] == true;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error loading availability: $e");
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    try {
      await _api.post(
        AppConstants.deliveryAvailabilityEndpoint,
        body: {'is_available': value},
      );
      _isAvailable = value;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error toggling availability: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Help & Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For any queries or assistance, please contact us:'),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.phone, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 8),
                Text('9019808476',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: _avatarUrl == null || _avatarUrl!.isEmpty
                  ? const Icon(Icons.person, size: 48, color: AppTheme.primaryColor)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_email, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            _buildVerificationBadge(),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                secondary: Icon(
                  _isAvailable ? Icons.circle : Icons.circle_outlined,
                  color: _isAvailable ? Colors.green : Colors.grey,
                ),
                title: Text(
                  _isAvailable ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isAvailable ? Colors.green : Colors.grey,
                  ),
                ),
                subtitle: Text(_isAvailable ? 'Accepting new deliveries' : 'Not accepting deliveries'),
                value: _isAvailable,
                onChanged: _toggleAvailability,
                activeTrackColor: Colors.green.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            _menuItem(context, Icons.edit, 'Edit Profile', _navigateToEditProfile),
            const Divider(),
            _menuItem(context, Icons.verified_user, 'Document Verification', _navigateToDocuments),
            const Divider(),
            _menuItem(context, Icons.help, 'Help & Support', _showContactDialog),
            const Divider(),
            _menuItem(context, Icons.logout, 'Logout', () {
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
                        await Provider.of<app.AuthProvider>(context, listen: false).logout();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            }, color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadge() {
    Color color;
    IconData icon;
    String text;
    if (_isVerified) {
      color = Colors.green;
      icon = Icons.verified;
      text = 'Verified — You can accept deliveries';
    } else {
      color = Colors.orange;
      icon = Icons.pending_actions;
      text = 'Pending verification — Documents under admin review';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }

  void _navigateToDocuments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryDocumentUploadScreen()),
    );
  }

  Future<void> _navigateToEditProfile() async {
    try {
      final authProvider = Provider.of<app.AuthProvider>(context, listen: false);
      final uid = authProvider.userProfile?['uid']?.toString();
      if (uid == null) return;
      final userModel = await UserRepositoryImpl(apiService: _api).getUser(uid);
      if (mounted && userModel != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditProfileScreen(user: userModel, apiService: _api)),
        );
        await authProvider.refreshProfile();
        _loadProfile();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Edit profile error: $e");
    }
  }

  Widget _menuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.primaryColor),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
