import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../chat/chat_list_screen.dart';
import '../../widgets/common/update_dialog.dart';
import '../../services/version_service.dart';
import '../../utils/logger.dart';

class TabNavigationScreen extends StatefulWidget {
  const TabNavigationScreen({super.key});

  @override
  State<TabNavigationScreen> createState() => _TabNavigationScreenState();
}

class _TabNavigationScreenState extends State<TabNavigationScreen> {
  @override
  void initState() {
    super.initState();

    // Initialize version service and check for updates automatically
    // Matches Android TabActivity.java line 140-145
    _initializeVersionService();
    _checkForUpdatesOnLaunch();
  }

  void _initializeVersionService() {
    VersionService().initialize();
  }

  /// Automatic update check on app launch - matches Android TabActivity behavior
  Future<void> _checkForUpdatesOnLaunch() async {
    try {
      Logger.service(
        'TabNavigationScreen',
        'Checking for updates on app launch...',
      );

      final versionService = VersionService();
      final newVersion = await versionService.checkForUpdate();

      if (newVersion != null && mounted) {
        // Get current version to compare
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        // Only show dialog if versions are different (matches Android logic)
        if (newVersion.appVersion != currentVersion &&
            newVersion.downloadUrl.isNotEmpty) {
          Logger.service(
            'TabNavigationScreen',
            'New version available: ${newVersion.appVersion}, showing dialog',
          );

          // Show update dialog automatically
          if (mounted) {
            UpdateDialogUtils.showNewVersionDialog(context, newVersion);
          }
        } else {
          Logger.service(
            'TabNavigationScreen',
            'No update needed or same version',
          );
        }
      } else {
        Logger.service('TabNavigationScreen', 'No updates available');
      }
    } catch (e) {
      Logger.error('Automatic update check failed', error: e);
      // Fail silently for automatic checks
    }
  }

  @override
  Widget build(BuildContext context) {
    // Directly show ChatListScreen since we only need chat functionality
    return const Scaffold(body: ChatListScreen());
  }
}
