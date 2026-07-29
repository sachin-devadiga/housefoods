import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;
  const MaintenanceScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_circle_outlined, size: 100, color: AppTheme.primaryColor),
            const SizedBox(height: 32),
            const Text(
              "Under Maintenance",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 48),
            // No navigation out of here, just an informative screen.
            // In production, we might add a "Contact Support" button here.
          ],
        ),
      ),
    );
  }
}
