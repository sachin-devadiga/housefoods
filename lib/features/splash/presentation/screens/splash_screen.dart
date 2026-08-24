import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/screens/maintenance_screen.dart';
import '../../../../core/screens/force_update_screen.dart';
import '../../../admin/presentation/screens/admin_dashboard.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chef/presentation/screens/chef_dashboard.dart';
import '../../../customer/presentation/screens/customer_dashboard.dart';
import '../../../delivery_partner/presentation/screens/delivery_partner_dashboard.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final RemoteConfigService _remoteConfigService = RemoteConfigService();

  @override
  void initState() {
    super.initState();
    _handleStartUp();
  }

  Future<void> _handleStartUp() async {
    await Future.delayed(const Duration(seconds: 2));

    await _remoteConfigService.initialize();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (!mounted) return;

    if (_remoteConfigService.isMaintenanceMode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MaintenanceScreen(message: _remoteConfigService.maintenanceMessage),
        ),
      );
      return;
    }

    if (_isUpdateRequired(currentVersion, _remoteConfigService.minAppVersion)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ForceUpdateScreen()),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = await authProvider.tryAutoLogin();

    if (!mounted) return;

    if (profile == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      final role = profile['role'] as String? ?? 'customer';
      Widget destination;
      switch (role) {
        case 'chef':
          destination = const ChefDashboard();
          break;
        case 'admin':
          destination = const AdminDashboard();
          break;
        case 'delivery_partner':
          destination = const DeliveryPartnerDashboard();
          break;
        default:
          destination = const CustomerDashboard();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    }
  }

  bool _isUpdateRequired(String current, String minRequired) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> minParts = minRequired.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < minParts[i]) return true;
      if (currentParts[i] > minParts[i]) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.restaurant_menu,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              AppConstants.appName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Order/subscribe anything you prefer for instant delivery',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
