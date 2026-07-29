import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  void _openStore() {
    // In production, use url_launcher to open Play Store or App Store links
    // e.g. launchUrl(Uri.parse(Platform.isAndroid ? playStoreUrl : appStoreUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.system_update_alt_rounded, size: 100, color: AppTheme.secondaryColor),
            const SizedBox(height: 32),
            const Text(
              "New Update Available",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "We've added new features and improvements to make your HouseFoods experience even better. Please update to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _openStore,
              child: const Text("Update Now"),
            ),
          ],
        ),
      ),
    );
  }
}
