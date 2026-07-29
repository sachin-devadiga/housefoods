import 'package:flutter/foundation.dart';

class RemoteConfigService {
  final bool _isMaintenanceMode = false;
  final String _minAppVersion = '1.0.0';
  final String _maintenanceMessage =
      "We're performing a scheduled upgrade. Please check back in a few minutes.";

  Future<void> initialize() async {
    try {
      // In production, fetch from your own backend API
      // e.g., using ApiService to GET /api/auth/admin/settings/
    } catch (e) {
      debugPrint("Remote Config Initialization Error: $e");
    }
  }

  bool get isMaintenanceMode => _isMaintenanceMode;
  String get minAppVersion => _minAppVersion;
  String get maintenanceMessage => _maintenanceMessage;
}
