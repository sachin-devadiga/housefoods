import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class NoInternetOverlay extends StatelessWidget {
  final Widget child;

  const NoInternetOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Consumer<ConnectivityService>(
          builder: (context, connectivity, _) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: !connectivity.isOnline
                  ? Material(
                      color: Colors.transparent,
                      child: SafeArea(
                        child: Container(
                          width: double.infinity,
                          color: Colors.red.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off, color: Colors.white, size: 16),
                              SizedBox(width: 12),
                              Text(
                                "No Internet Connection",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }
}
