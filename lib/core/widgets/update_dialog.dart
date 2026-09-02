import 'package:flutter/material.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo info;
  final bool isForce;

  const UpdateDialog({
    super.key,
    required this.info,
    required this.isForce,
  });

  static Future<void> show(BuildContext context, UpdateInfo info, String currentVersion) async {
    final isForce = UpdateService.isForceRequired(info.minVersion, currentVersion);
    return showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (_) => UpdateDialog(info: info, isForce: isForce),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isForce,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('Update Available')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${info.latestVersion}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            if (info.updateMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                info.updateMessage,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
            if (isForce) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[800], size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Please update to continue using the app.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isForce)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (info.updateUrl.isNotEmpty) {
                UpdateService.openUpdateUrl(info.updateUrl);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
