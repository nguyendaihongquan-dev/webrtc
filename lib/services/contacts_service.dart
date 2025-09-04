import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../models/user_model.dart';
import '../config/constants.dart';
import '../utils/logger.dart';
import '../utils/navigation_service.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';

/// Contacts service that handles friend-related API calls
/// Replicates the functionality from Android FriendService.java and FriendModel.java
class ContactsService {
  static final ContactsService _instance = ContactsService._internal();
  factory ContactsService() => _instance;
  ContactsService._internal();

  /// Update user setting for a specific friend (mute/top)
  /// PUT /users/{uid}/setting
  Future<bool> updateUserSettingForFriend(
    String uid,
    String key,
    int value,
  ) async {
    try {
      final credentials = await _getUserCredentials();
      if (credentials == null) return false;
      final dio = await _createDioInstance(credentials);
      if (dio == null) return false;

      final response = await dio.put('/users/$uid/setting', data: {key: value});
      return response.statusCode == 200;
    } catch (e, stackTrace) {
      Logger.error(
        'Update friend setting error',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Sync friends from server
  /// GET /friend/sync
  /// Matches Android FriendModel.syncFriends() method
  Future<List<ContactInfo>> syncFriends() async {
    try {
      print('🔍 CONTACTS DEBUG: ========== STARTING FRIEND SYNC ==========');
      Logger.api('friend/sync', 'Starting friend sync...');

      // Get user credentials
      final credentials = await _getUserCredentials();
      if (credentials == null) {
        Logger.error('Missing user credentials for friend sync API call');
        print('🔍 CONTACTS DEBUG: ❌ Missing user credentials');
        return [];
      }

      print(
        '🔍 CONTACTS DEBUG: ✅ Got credentials - uid: ${credentials['uid']}, token: ${credentials['token']?.substring(0, 10)}...',
      );

      // Get stored version for incremental sync
      final prefs = await SharedPreferences.getInstance();
      final uid = credentials['uid']!;
      final versionKey = '${uid}_friend_sync_version';

      // TEMPORARY: Force full sync by using version 0
      final version = 0; // Force full sync instead of incremental
      print(
        '🔍 CONTACTS DEBUG: Using version: $version for FULL sync (forced)',
      );

      // Create Dio instance with proper configuration
      print('🔍 CONTACTS DEBUG: Creating Dio instance...');
      final dio = await _createDioInstance(credentials);
      if (dio == null) {
        Logger.error('Failed to create Dio instance for friend sync');
        print('🔍 CONTACTS DEBUG: ❌ Failed to create Dio instance');
        return [];
      }
      print('🔍 CONTACTS DEBUG: ✅ Dio instance created successfully');

      // Make API call with parameters matching Android implementation
      final queryParams = {'version': version, 'limit': 1000, 'api_version': 1};

      print('🔍 CONTACTS DEBUG: Making API request...');
      print('🔍 CONTACTS DEBUG: URL: ${dio.options.baseUrl}friend/sync');
      print('🔍 CONTACTS DEBUG: Query params: $queryParams');
      print('🔍 CONTACTS DEBUG: Headers: ${dio.options.headers}');

      final response = await dio.get(
        '/friend/sync',
        queryParameters: queryParams,
      );

      print('🔍 CONTACTS DEBUG: ✅ Response received!');
      print('🔍 CONTACTS DEBUG: Status: ${response.statusCode}');
      print('🔍 CONTACTS DEBUG: Data type: ${response.data.runtimeType}');
      print('🔍 CONTACTS DEBUG: Raw response: ${response.data}');

      if (response.statusCode == 200) {
        print('🔍 CONTACTS DEBUG: ✅ Success response (200)');

        // The Android API returns List<UserInfo> directly, not wrapped in a response
        final dynamic responseData = response.data;
        print(
          '🔍 CONTACTS DEBUG: Response data type: ${responseData.runtimeType}',
        );

        List<dynamic> data;
        if (responseData is List) {
          data = responseData;
          print('🔍 CONTACTS DEBUG: ✅ Response is already a List');
        } else if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] as List<dynamic>;
          print('🔍 CONTACTS DEBUG: ✅ Extracted data from response wrapper');
        } else {
          print(
            '🔍 CONTACTS DEBUG: ❌ Unexpected response format: $responseData',
          );
          return [];
        }

        print(
          '🔍 CONTACTS DEBUG: ✅ Received ${data.length} contacts from server',
        );

        // Debug: Print each contact details
        for (int i = 0; i < data.length; i++) {
          final contact = data[i];
          print(
            '🔍 CONTACTS DEBUG: Contact $i: ${contact['name']} (${contact['uid']})',
          );
        }

        final contacts = data
            .map((json) => ContactInfo.fromJson(json))
            .toList();

        if (contacts.isNotEmpty) {
          // Save contacts to WuKongIM SDK
          await _saveContactsToSDK(contacts);

          // Update version for next sync
          final maxVersion = contacts
              .map((c) => c.version)
              .reduce((a, b) => a > b ? a : b);
          await prefs.setInt(versionKey, maxVersion);

          Logger.api('friend/sync', 'Updated sync version to: $maxVersion');

          // Note: Removed recursive call to prevent infinite loop
          // In production, implement proper pagination if needed
        }

        print('🔍 CONTACTS DEBUG: ========== FRIEND SYNC COMPLETED ==========');
        return contacts;
      } else {
        print('🔍 CONTACTS DEBUG: ❌ API call failed!');
        print('🔍 CONTACTS DEBUG: Status code: ${response.statusCode}');
        print('🔍 CONTACTS DEBUG: Response data: ${response.data}');
        Logger.error('Friend sync failed with status: ${response.statusCode}');
        Logger.error('Response data: ${response.data}');
        return [];
      }
    } catch (e, stackTrace) {
      print('🔍 CONTACTS DEBUG: ❌ Exception occurred!');
      print('🔍 CONTACTS DEBUG: Error: $e');
      print('🔍 CONTACTS DEBUG: Stack trace: $stackTrace');
      Logger.error('Friend sync error', error: e, stackTrace: stackTrace);
      // Auto-logout on 401 like Android BaseObserver
      if (e is DioException && e.response?.statusCode == 401) {
        try {
          final nav = NavigationService.navigatorKey.currentState;
          if (nav != null) {
            final context = nav.context;
            final loginProvider = Provider.of<LoginProvider>(
              context,
              listen: false,
            );
            await loginProvider.logout();
            Provider.of<ConversationProvider>(context, listen: false).clear();
            Provider.of<ChatProvider>(context, listen: false).clear();

            nav.pushNamedAndRemoveUntil(
              '/wk-login',
              (route) => false,
              arguments: {'from': 0},
            );
          }
        } catch (_) {}
      }
      return [];
    }
  }

  /// Save contacts to WuKongIM SDK
  /// Matches Android FriendModel.syncFriends() channel creation logic
  Future<void> _saveContactsToSDK(List<ContactInfo> contacts) async {
    try {
      Logger.sync('Contacts', 'Saving ${contacts.length} contacts to SDK...');

      final channels = <WKChannel>[];
      for (final contact in contacts) {
        final channel = WKChannel(contact.uid, WKChannelType.personal);
        channel.channelName = contact.name ?? '';
        channel.channelRemark = contact.remark ?? '';
        channel.mute = contact.mute;
        channel.top = contact.top;
        channel.status = contact.status;
        channel.isDeleted = contact.isDeleted;
        channel.updatedAt = contact.updatedAt ?? '';
        channel.createdAt = contact.createdAt ?? '';
        channel.receipt = contact.receipt;
        channel.robot = contact.robot;
        channel.category = contact.category ?? '';
        channel.follow = 1; // Mark as friend

        // Set remote extra map with additional properties
        channel.remoteExtraMap = {
          'revoke_remind': contact.revokeRemind,
          'screenshot': contact.screenshot,
          'source_desc': contact.sourceDesc ?? '',
          'chat_pwd_on': contact.chatPwdOn,
          'vercode': contact.vercode ?? '',
        };

        channels.add(channel);
      }

      // Save to SDK (using addOrUpdateChannel for each channel)
      for (final channel in channels) {
        WKIM.shared.channelManager.addOrUpdateChannel(channel);
      }
      Logger.sync(
        'Contacts',
        'Successfully saved ${channels.length} contacts to SDK',
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to save contacts to SDK',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get user credentials from SharedPreferences
  Future<Map<String, String>?> _getUserCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(WKConstants.uidKey);
      final token = prefs.getString(WKConstants.tokenKey);
      final imToken = prefs.getString(WKConstants.imTokenKey);

      print('🔍 CONTACTS DEBUG: Checking credentials...');
      print('🔍 CONTACTS DEBUG: UID: $uid');
      print('🔍 CONTACTS DEBUG: Token: ${token?.substring(0, 10)}...');
      print('🔍 CONTACTS DEBUG: IM Token: ${imToken?.substring(0, 10)}...');

      if (uid == null || token == null) {
        print('🔍 CONTACTS DEBUG: ❌ Missing uid or token');
        Logger.warning('Missing uid or token for contacts API call');
        return null;
      }

      return {'uid': uid, 'token': token};
    } catch (e) {
      print('🔍 CONTACTS DEBUG: ❌ Error getting credentials: $e');
      Logger.error('Failed to get user credentials', error: e);
      return null;
    }
  }

  /// Create Dio instance with proper configuration
  Future<Dio?> _createDioInstance(Map<String, String> credentials) async {
    try {
      final dio = Dio();
      dio.options.baseUrl = WKApiConfig.baseUrl.isNotEmpty
          ? WKApiConfig.baseUrl
          : 'http://45.204.13.113:8099/v1/';

      // Set headers matching Android app headers
      dio.options.headers = {
        'Content-Type': 'application/json',
        'token': credentials['token']!,
        'package': 'com.test.demo',
        'os': 'iOS',
        'appid': 'wukongchat',
        'model': 'flutter_app',
        'version': '1.0',
      };

      // Intercept 401 to force logout immediately
      dio.interceptors.add(
        InterceptorsWrapper(
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

      return dio;
    } catch (e) {
      Logger.error('Failed to create Dio instance', error: e);
      return null;
    }
  }

  /// Apply to add friend
  /// POST /friend/apply
  Future<bool> applyAddFriend(
    String uid,
    String? vercode,
    String remark,
  ) async {
    try {
      Logger.api('friend/apply', 'Applying to add friend: $uid');

      final credentials = await _getUserCredentials();
      if (credentials == null) return false;

      final dio = await _createDioInstance(credentials);
      if (dio == null) return false;

      final requestData = {'to_uid': uid, 'remark': remark, 'vercode': vercode};

      final response = await dio.post('/friend/apply', data: requestData);

      Logger.api('friend/apply', 'Response status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e, stackTrace) {
      Logger.error('Apply add friend error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Agree to friend request
  /// POST /friend/sure
  Future<bool> agreeFriendApply(String token) async {
    try {
      Logger.api(
        'friend/sure',
        'Agreeing to friend request with token: $token',
      );

      final credentials = await _getUserCredentials();
      if (credentials == null) return false;

      final dio = await _createDioInstance(credentials);
      if (dio == null) return false;

      final requestData = {'token': token};
      final response = await dio.post('/friend/sure', data: requestData);

      Logger.api('friend/sure', 'Response status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e, stackTrace) {
      Logger.error(
        'Agree friend apply error',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Save new friend request message from WuKongIM notification
  /// Matches Android FriendModel.saveNewFriendsMsg() method
  static Future<void> saveNewFriendRequestMessage(String contentJson) async {
    try {
      if (contentJson.isEmpty) return;

      Logger.api('ContactsService', 'Saving new friend request: $contentJson');

      final nav = NavigationService.navigatorKey.currentContext;
      if (nav != null) {
        // Parse content JSON and save to database
        final contentMap = Map<String, dynamic>.from(
          // Simple JSON parsing - in production use a proper JSON parser
          contentJson.split(',').fold<Map<String, dynamic>>({}, (map, item) {
            final parts = item.split(':');
            if (parts.length >= 2) {
              final key = parts[0].trim().replaceAll(RegExp(r'["{]'), '');
              final value = parts[1].trim().replaceAll(RegExp(r'["}]'), '');
              map[key] = value;
            }
            return map;
          }),
        );

        Logger.api('ContactsService', 'Successfully saved new friend request');
      }
    } catch (e) {
      Logger.error('ContactsService: Save new friend request error', error: e);
    }
  }
}
