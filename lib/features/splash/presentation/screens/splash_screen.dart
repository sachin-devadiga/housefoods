import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/role_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/services/update_service.dart';
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

    // Check for update — if available, auto-download and install silently
    final updateInfo = await UpdateService.checkForUpdate();
    if (mounted && updateInfo != null && updateInfo.updateUrl.isNotEmpty) {
      final forceUpdate = UpdateService.isForceRequired(updateInfo.minVersion, currentVersion);
      if (forceUpdate) {
        // Force: show screen that auto-downloads and installs
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ForceUpdateScreen(
              updateUrl: updateInfo.updateUrl,
              updateMessage: updateInfo.updateMessage,
            ),
          ),
        );
        return;
      }
      // Optional: download silently in background, then trigger installer
      // App continues loading while download happens
      _silentUpdate(updateInfo.updateUrl);
    }

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = await authProvider.tryAutoLogin();

    if (!mounted) return;

    if (profile == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      final role = RoleConfig.isDedicated ? RoleConfig.roleName : (profile['role'] as String? ?? 'customer');
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

  /// Download APK in background and trigger Android installer.
  /// No UI interruption — user just sees the system install prompt when ready.
  Future<void> _silentUpdate(String url) async {
    try {
      final filePath = await UpdateService.downloadApk(url);
      if (filePath != null && mounted) {
        await UpdateService.installApk(filePath);
      }
    } catch (e) {
      debugPrint('[Splash] Silent update failed: $e');
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
    final appName = RoleConfig.isDedicated ? RoleConfig.appName : 'Mealin';
    final subtitle = RoleConfig.isDedicated
        ? RoleConfig.splashSubtitle
        : 'Order food from your favorite restaurants';

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/logo.jpeg',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.restaurant_menu,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              appName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
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
