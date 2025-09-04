import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../services/version_service.dart';
import '../../config/constants.dart';
import '../../utils/logger.dart';

/// Custom update dialog that matches Android's act_new_version_layout.xml design
class UpdateDialog extends StatefulWidget {
  final AppVersion versionInfo;

  const UpdateDialog({super.key, required this.versionInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Title - matches Android "find_new_version"
            const Text(
              'Find New Version',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333), // colorDark from Android
              ),
            ),

            const SizedBox(height: 30),

            // Version description - matches Android "version_desc"
            const Text(
              'Version Description',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF333333), // colorDark from Android
              ),
            ),

            const SizedBox(height: 5),

            // Version number - matches Android versionTv
            Text(
              'New Version: ${widget.versionInfo.appVersion}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999), // color999 from Android
              ),
            ),

            const SizedBox(height: 10),

            // Update description - matches Android contentTv
            Text(
              widget.versionInfo.updateDesc.replaceAll('\\n', '\n'),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999), // color999 from Android
              ),
            ),

            const SizedBox(height: 20),

            // Progress bar - matches Android progressBar (shown when downloading)
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 20),
            ],

            // Update button - matches Android sureBtn
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isDownloading ? null : _handleUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF007AFF,
                  ), // buttonNormal style
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // button_radian
                  ),
                ),
                child: Text(
                  _isDownloading ? 'Downloading...' : 'Update Now',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cancel button - matches Android cancelTv (only shown if not force update)
            if (!widget.versionInfo.forceUpdate)
              Center(
                child: TextButton(
                  onPressed: _isDownloading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF999999), // color999 from Android
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    try {
      Logger.service('UpdateDialog', 'Starting update download...');

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.1;
      });

      // Simulate download progress (in real implementation, this would track actual download)
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          setState(() {
            _downloadProgress = i / 10;
          });
        }
      }

      final rawUrl = widget.versionInfo.downloadUrl;
      if (rawUrl.isEmpty) {
        throw Exception('Download URL is empty');
      }

      // Process URL like Android: WKApiConfig.getShowUrl(versionEntity.download_url)
      final url = WKApiConfig.getShowUrl(rawUrl);
      Logger.service('UpdateDialog', 'Processed download URL: $url');

      // Platform-specific download handling - matches Android DownloadApkUtils.downloadAPK
      await _launchDownload(url, widget.versionInfo.appVersion);

      // Show success message like Android: "后台下载中，可在通知栏中查看状态"
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Download started. Check your browser or download manager.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      Logger.error('Update download failed', error: e);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Launch download with platform-specific handling
  /// Matches Android DownloadApkUtils.downloadAPK(context, versionName, url)
  Future<void> _launchDownload(String url, String versionName) async {
    final uri = Uri.parse(url);

    // Check if URL can be launched
    if (!await canLaunchUrl(uri)) {
      throw Exception('Cannot launch download URL: $url');
    }

    // Platform-specific download handling - matches Android DownloadApkUtils logic
    if (Platform.isAndroid) {
      if (url.toLowerCase().endsWith('.apk')) {
        // Direct APK download - open in browser/download manager like Android DownloadManager
        Logger.service(
          'UpdateDialog',
          'Launching APK download for Android: $url',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (url.contains('play.google.com') || url.contains('market://')) {
        // Google Play Store link
        Logger.service('UpdateDialog', 'Opening Google Play Store');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Other URLs - open in browser
        Logger.service('UpdateDialog', 'Opening download URL in browser');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (Platform.isIOS) {
      if (url.contains('apps.apple.com') || url.contains('itunes.apple.com')) {
        // App Store link
        Logger.service('UpdateDialog', 'Opening App Store for iOS');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Other URLs - open in browser
        Logger.service('UpdateDialog', 'Opening download URL in Safari');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      // For other platforms, open in default application
      Logger.service(
        'UpdateDialog',
        'Opening download URL in default application',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    Logger.service('UpdateDialog', 'Download URL launched successfully');
  }
}

/// Utility class to show update dialog - matches Android WKDialogUtils.showNewVersionDialog
class UpdateDialogUtils {
  static void showNewVersionDialog(
    BuildContext context,
    AppVersion versionInfo,
  ) {
    showDialog(
      context: context,
      barrierDismissible:
          !versionInfo.forceUpdate, // Can't dismiss if force update
      builder: (context) => UpdateDialog(versionInfo: versionInfo),
    );
  }
}
