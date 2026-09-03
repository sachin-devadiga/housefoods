import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../config/role_config.dart';
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
  static const _channel = MethodChannel('com.mealin.app/install');

  /// Check backend for latest version info.
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
        // Construct role-specific download URL from base URL
        if (info.updateUrl.isNotEmpty && RoleConfig.isDedicated) {
          final apkName = 'mealin-${RoleConfig.roleName.replaceAll('_', '-')}.apk';
          final baseUrl = info.updateUrl.endsWith('/') ? info.updateUrl : '${info.updateUrl}/';
          return UpdateInfo(
            latestVersion: info.latestVersion,
            minVersion: info.minVersion,
            updateUrl: '$baseUrl$apkName',
            updateMessage: info.updateMessage,
            forceUpdate: info.forceUpdate,
          );
        }
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

  /// Download APK and return the file path. Calls onProgress with 0.0-1.0.
  static Future<String?> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/mealin_update.apk';
      final file = File(filePath);

      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) return null;

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(receivedBytes / totalBytes);
        }
      }
      await sink.close();

      return filePath;
    } catch (e) {
      debugPrint('[UpdateService] Download failed: $e');
      return null;
    }
  }

  /// Trigger Android package installer for the given APK file.
  static Future<bool> installApk(String filePath) async {
    try {
      await _channel.invokeMethod('installApk', {'filePath': filePath});
      return true;
    } catch (e) {
      debugPrint('[UpdateService] Install failed: $e');
      return false;
    }
  }
}
