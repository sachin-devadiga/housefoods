import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String updateUrl;
  final String updateMessage;

  const ForceUpdateScreen({
    super.key,
    this.updateUrl = '',
    this.updateMessage = '',
  });

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
              const Icon(Icons.system_update_alt_rounded, size: 100, color: AppTheme.secondaryColor),
              const SizedBox(height: 32),
              const Text(
                "New Update Available",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                updateMessage.isNotEmpty
                    ? updateMessage
                    : "We've added new features and improvements to make your Mealin experience even better. Please update to continue.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: updateUrl.isNotEmpty
                    ? () => UpdateService.openUpdateUrl(updateUrl)
                    : null,
                child: const Text("Update Now"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
