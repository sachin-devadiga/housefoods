import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class ForceUpdateScreen extends StatefulWidget {
  final String updateUrl;
  final String updateMessage;

  const ForceUpdateScreen({
    super.key,
    this.updateUrl = '',
    this.updateMessage = '',
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _downloading = false;
  double _progress = 0.0;
  String? _error;

  Future<void> _downloadAndInstall() async {
    if (widget.updateUrl.isEmpty) {
      setState(() => _error = 'No download URL configured.');
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0.0;
      _error = null;
    });

    final filePath = await UpdateService.downloadApk(
      widget.updateUrl,
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

    await UpdateService.installApk(filePath);
  }

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
                widget.updateMessage.isNotEmpty
                    ? widget.updateMessage
                    : "We've added new features and improvements to make your Mealin experience even better. Please update to continue.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.5),
              ),
              if (_downloading) ...[
                const SizedBox(height: 32),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.grey[200],
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 12),
                Text(
                  _progress > 0
                      ? '${(_progress * 100).toStringAsFixed(0)}% downloaded...'
                      : 'Downloading update...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
              ],
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _downloading ? null : _downloadAndInstall,
                child: Text(_downloading ? 'Downloading...' : 'Update Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
