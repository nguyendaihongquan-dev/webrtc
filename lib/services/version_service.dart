import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../config/constants.dart';
import '../utils/logger.dart';
import '../utils/navigation_service.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';

/// Version information model - matches Android AppVersion entity exactly
class AppVersion {
  final String os;
  final String appVersion;
  final int isForce;
  final String updateDesc;
  final String downloadUrl;
  final String createdAt;

  AppVersion({
    required this.os,
    required this.appVersion,
    required this.isForce,
    required this.updateDesc,
    required this.downloadUrl,
    required this.createdAt,
  });

  /// Convenience getter for force update check
  bool get forceUpdate => isForce == 1;

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      os: json['os'] ?? '',
      appVersion: json['app_version'] ?? '',
      isForce: json['is_force'] ?? 0,
      updateDesc: json['update_desc'] ?? '',
      downloadUrl: json['download_url'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'os': os,
      'app_version': appVersion,
      'is_force': isForce,
      'update_desc': updateDesc,
      'download_url': downloadUrl,
      'created_at': createdAt,
    };
  }
}

/// Version service that handles app version checking
/// Replicates Android WKCommonModel.getAppNewVersion functionality
class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  late Dio _dio;

  void initialize() {
    _dio = Dio();
    _dio.options.baseUrl = WKApiConfig.baseUrl.isNotEmpty
        ? WKApiConfig.baseUrl
        : 'http://45.204.13.113:8099/v1/';
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Add common request interceptor - matches Android CommonRequestParamInterceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add common headers like Android CommonRequestParamInterceptor
          final commonHeaders = await _getCommonHeaders();
          options.headers.addAll(commonHeaders);
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              final nav = NavigationService.navigatorKey.currentState;
              if (nav != null) {
                final context = nav.context;
                final loginProvider = Provider.of<LoginProvider>(
                  context,
                  listen: false,
                );
                await loginProvider.logout();
                Provider.of<ConversationProvider>(
                  context,
                  listen: false,
                ).clear();
                Provider.of<ChatProvider>(context, listen: false).clear();

                nav.pushNamedAndRemoveUntil(
                  '/wk-login',
                  (route) => false,
                  arguments: {'from': 0},
                );
              }
            } catch (_) {}
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Get common headers - matches Android CommonRequestParamInterceptor.getCommonParams()
  Future<Map<String, String>> _getCommonHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    final headers = <String, String>{};

    // Add token if available (matches Android)
    final token = prefs.getString(WKConstants.tokenKey);
    if (token != null && token.isNotEmpty) {
      headers['token'] = token;
    }

    // Add device model (matches Android Build.MODEL)
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        headers['model'] = androidInfo.model;
      } else if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        headers['model'] = iosInfo.model;
      } else {
        headers['model'] = 'Unknown';
      }
    } catch (e) {
      headers['model'] = 'Unknown';
    }

    // Add other common headers (matches Android)
    headers['os'] = 'Android'; // Keep as Android for API compatibility
    headers['appid'] = 'wukongchat'; // Matches Android WKBaseApplication.appID
    headers['version'] = packageInfo.version;
    headers['package'] = packageInfo.packageName;

    return headers;
  }

  /// Check for new app version - matches Android WKCommonModel.getAppNewVersion
  /// Returns null if no update available or on error
  Future<AppVersion?> checkForUpdate() async {
    try {
      Logger.service('VersionService', 'Checking for app updates...');

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      Logger.service('VersionService', 'Current version: $currentVersion');

      // First try with authentication (normal case)
      try {
        final response = await _dio.get(
          'common/appversion/android/$currentVersion',
        );

        Logger.service(
          'VersionService',
          'Version check response: ${response.statusCode}',
        );

        if (response.statusCode == 200) {
          final data = response.data;

          if (data != null && data is Map<String, dynamic>) {
            final newVersion = AppVersion.fromJson(data);

            if (newVersion.downloadUrl.isNotEmpty &&
                _isNewerVersion(currentVersion, newVersion.appVersion)) {
              Logger.service(
                'VersionService',
                'New version available: ${newVersion.appVersion}',
              );
              return newVersion;
            } else {
              Logger.service('VersionService', 'No update available');
              return null;
            }
          }
        }
      } catch (e) {
        // If 401 error, try without token (maybe version check doesn't need auth)
        if (e is DioException && e.response?.statusCode == 401) {
          Logger.service(
            'VersionService',
            'Trying version check without authentication...',
          );

          try {
            // Create a temporary dio instance without auth headers
            final tempDio = Dio();
            tempDio.options.baseUrl = _dio.options.baseUrl;
            tempDio.options.connectTimeout = _dio.options.connectTimeout;
            tempDio.options.receiveTimeout = _dio.options.receiveTimeout;

            final response = await tempDio.get(
              'common/appversion/android/$currentVersion',
            );

            if (response.statusCode == 200) {
              final data = response.data;
              if (data != null && data is Map<String, dynamic>) {
                final newVersion = AppVersion.fromJson(data);
                if (newVersion.downloadUrl.isNotEmpty &&
                    _isNewerVersion(currentVersion, newVersion.appVersion)) {
                  Logger.service(
                    'VersionService',
                    'New version available (no auth): ${newVersion.appVersion}',
                  );
                  return newVersion;
                }
              }
            }
          } catch (e2) {
            Logger.error('Version check without auth also failed', error: e2);
          }
        }

        // Re-throw original error if not 401 or if fallback also failed
        rethrow;
      }

      Logger.service('VersionService', 'No update information received');
      return null;
    } catch (e, stackTrace) {
      Logger.error('Version check failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Compare version strings to determine if newVersion is newer than currentVersion
  bool _isNewerVersion(String currentVersion, String newVersion) {
    try {
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final newParts = newVersion.split('.').map(int.parse).toList();

      // Pad shorter version with zeros
      while (currentParts.length < newParts.length) {
        currentParts.add(0);
      }
      while (newParts.length < currentParts.length) {
        newParts.add(0);
      }

      // Compare each part
      for (int i = 0; i < currentParts.length; i++) {
        if (newParts[i] > currentParts[i]) {
          return true;
        } else if (newParts[i] < currentParts[i]) {
          return false;
        }
      }

      return false; // Versions are equal
    } catch (e) {
      Logger.error('Version comparison failed', error: e);
      return false;
    }
  }

  /// Get current app version
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      Logger.error('Failed to get current version', error: e);
      return '1.0.0';
    }
  }

  /// Get app name
  Future<String> getAppName() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.appName;
    } catch (e) {
      Logger.error('Failed to get app name', error: e);
      return 'demo';
    }
  }

  void dispose() {
    _dio.close();
  }
}
