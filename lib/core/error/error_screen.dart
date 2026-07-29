import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlobalErrorScreen extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const GlobalErrorScreen({super.key, required this.errorDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppTheme.errorColor),
            const SizedBox(height: 24),
            const Text(
              "Something went wrong",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "We've encountered an unexpected error. Our team has been notified.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // Navigate back to the initial screen
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text("Go to Home"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // In development, show details; in production, show a support ID
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Error Details"),
                    content: SingleChildScrollView(
                      child: Text(errorDetails.toString()),
                    ),
                  ),
                );
              },
              child: Text(
                "View Technical Details",
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
