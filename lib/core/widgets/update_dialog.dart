import 'package:flutter/material.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';

class UpdateDialog extends StatefulWidget {
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
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String? _error;

  bool get _isForce => widget.isForce;

  Future<void> _downloadAndInstall() async {
    if (widget.info.updateUrl.isEmpty) {
      setState(() => _error = 'No download URL configured. Contact support.');
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0.0;
      _error = null;
    });

    final filePath = await UpdateService.downloadApk(
      widget.info.updateUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    if (filePath == null) {
      setState(() {
        _downloading = false;
        _error = 'Download failed. Check your connection.';
      });
      return;
    }

    final success = await UpdateService.installApk(filePath);
    if (!mounted) return;

    if (!success) {
      setState(() {
        _downloading = false;
        _error = 'Could not open installer. Check permissions.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isForce,
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
              'Version ${widget.info.latestVersion}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            if (widget.info.updateMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.info.updateMessage,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Colors.grey[200],
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                _progress > 0
                    ? '${(_progress * 100).toStringAsFixed(0)}% downloaded...'
                    : 'Downloading update...',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ],
            if (_isForce && !_downloading) ...[
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
          if (!_isForce && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: _downloading ? null : _downloadAndInstall,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(_downloading ? 'Downloading...' : 'Update Now'),
          ),
        ],
      ),
    );
  }
}
