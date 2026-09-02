import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';

class UpdateInfo {
  final String latestVersion;
  final String minVersion;
  final String updateUrl;
  final String updateMessage;
  final bool forceUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.updateUrl,
    required this.updateMessage,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latestVersion'] ?? '1.0.0',
      minVersion: json['minVersion'] ?? '1.0.0',
      updateUrl: json['updateUrl'] ?? '',
      updateMessage: json['updateMessage'] ?? '',
      forceUpdate: json['forceUpdate'] ?? false,
    );
  }
}

class UpdateService {
  /// Check backend for latest version info.
  /// Returns null if check fails or no update available.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final url = '${AppConstants.apiBaseUrl}/api/auth/app-version/';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(data);

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (isNewer(info.latestVersion, currentVersion)) {
        return info;
      }
      return null;
    } catch (e) {
      debugPrint('[UpdateService] Check failed: $e');
      return null;
    }
  }

  /// Returns true if [remote] is newer than [current].
  static bool isNewer(String remote, String current) {
    final remoteParts = remote.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Returns true if [remote] is higher than [current] AND meets force threshold.
  static bool isForceRequired(String remoteMinVersion, String currentVersion) {
    return isNewer(remoteMinVersion, currentVersion);
  }

  /// Open the APK download URL.
  static Future<void> openUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
