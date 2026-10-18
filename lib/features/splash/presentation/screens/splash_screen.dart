import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../core/config/role_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/sdui/sdui_provider.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/screens/maintenance_screen.dart';
import '../../../../core/screens/force_update_screen.dart';
import '../../../admin/presentation/screens/admin_dashboard.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chef/presentation/providers/chef_provider.dart';
import '../../../chef/presentation/screens/chef_dashboard.dart';
import '../../../customer/presentation/screens/customer_dashboard.dart';
import '../../../delivery_partner/presentation/screens/delivery_partner_dashboard.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';

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
    // SDUI is already usable before this runs: SduiProvider installs baked-in
    // defaults at construction, so the first frame never waits on the network.
    // `initialize()` here only refreshes cache + remote in the background.
    final sdui = context.read<SduiProvider>();
    _remoteConfigService.bind(sdui);
    // Deferred to the first frame for the same reason: anything that notifies
    // listeners must not run synchronously inside initState, which is mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_remoteConfigService.initialize());
    });

    await Future.delayed(const Duration(seconds: 2));

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (!mounted) return;

    // Maintenance is read from whatever config is in hand at this point — the
    // baked default (off) or the cache. A slow or dead backend therefore leaves
    // the app usable rather than blocking it on a network round trip.
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
        MaterialPageRoute(builder: (_) => _forceUpdateGate(null)),
      );
      return;
    }

    // Check for update — if available, auto-download and install silently
    final updateInfo = await UpdateService.checkForUpdate();
    if (mounted && updateInfo != null) {
      if (UpdateService.requiresForceUpdate(updateInfo, currentVersion)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => _forceUpdateGate(updateInfo)),
        );
        return;
      }
      // Auto-download only for dedicated apps (role-specific APK)
      if (RoleConfig.isDedicated && updateInfo.updateUrl.isNotEmpty) {
        _silentUpdate(updateInfo.updateUrl);
      }
    }

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = await authProvider.tryAutoLogin();

    if (!mounted) return;

    if (profile == null) {
      if (RoleConfig.isDedicated && RoleConfig.role != AppRole.customer) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    } else {
      final role = RoleConfig.isDedicated ? RoleConfig.roleName : (profile['role'] as String? ?? 'customer');
      if (role == 'chef') {
        try {
          context.read<ChefProvider>().reset();
        } catch (_) {}
      }
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

  /// Pick the right blocking screen for a forced update.
  ///
  /// [ForceUpdateScreen] downloads and sideloads an APK. That only works when
  /// there is a hosted APK to fetch, so the discriminator is `updateUrl` —
  /// NOT [RoleConfig.isDedicated]. Every AAB in build_all_apks.bat passes
  /// `--dart-define=APP_ROLE=...`, so `isDedicated` is true for all three Play
  /// builds; branching on it sent Play builds into the APK path, which with an
  /// empty `updateUrl` produced an undismissable screen that only ever said
  /// "No download URL configured".
  ///
  ///   - `updateUrl` present  -> a real sideload channel exists, keep the APK flow.
  ///   - `updateUrl` absent   -> Play-distributed, route to the store listing.
  Widget _forceUpdateGate(UpdateInfo? info) {
    final url = info?.updateUrl ?? '';
    if (url.isEmpty) {
      return _PlayUpdateGate(message: info?.updateMessage ?? '');
    }
    return ForceUpdateScreen(
      updateUrl: url,
      updateMessage: info?.updateMessage ?? '',
    );
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
    final appName = RoleConfig.isDedicated ? RoleConfig.appName : 'MEALIN';
    final subtitle = RoleConfig.isDedicated
        ? RoleConfig.splashSubtitle
        : 'Order food from your favorite restaurants';

    return Scaffold(
      backgroundColor: RoleConfig.splashColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                RoleConfig.logoAsset,
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

/// Blocking gate for Play-distributed builds.
///
/// Deliberately does NOT download an APK: Play builds are updated through the
/// store, and the server's `updateUrl` is typically empty because there is no
/// hosted APK to point at. Opening the listing is the only correct action, so
/// this screen never downloads, never stalls on a progress bar, and always
/// keeps a working button.
class _PlayUpdateGate extends StatefulWidget {
  const _PlayUpdateGate({this.message = ''});

  final String message;

  @override
  State<_PlayUpdateGate> createState() => _PlayUpdateGateState();
}

class _PlayUpdateGateState extends State<_PlayUpdateGate> {
  bool _launchFailed = false;

  Future<void> _openStore() async {
    final opened = await UpdateService.openPlayStoreListing();
    if (!opened && mounted) {
      setState(() => _launchFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                size: 100,
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(height: 32),
              const Text(
                'Update required',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                widget.message.isNotEmpty
                    ? widget.message
                    : 'A new version of MEALIN is required to continue. '
                        'Please update from Google Play.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.5),
              ),
              if (_launchFailed) ...[
                const SizedBox(height: 24),
                Text(
                  'Could not open the Play Store automatically. '
                  'Open ${UpdateService.playStoreListingUrl} to update.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _openStore,
                child: const Text('Update on Google Play'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
