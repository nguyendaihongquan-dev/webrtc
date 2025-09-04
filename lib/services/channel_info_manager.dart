import 'dart:async';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import '../config/constants.dart';
import '../utils/logger.dart';
import '../utils/navigation_service.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';

/// Manages channel information fetching and caching
class ChannelInfoManager {
  static final ChannelInfoManager _instance = ChannelInfoManager._internal();
  factory ChannelInfoManager() => _instance;
  ChannelInfoManager._internal();

  // Cache to prevent duplicate API calls
  final Map<String, Future<WKChannel?>> _fetchingChannels = {};
  final Map<String, DateTime> _lastFetchTime = {};

  // Cache for group member counts
  final Map<String, int> _groupMemberCounts = {};
  final Map<String, DateTime> _memberCountFetchTime = {};

  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Generate cache key for channel
  String _getCacheKey(String channelId, int channelType) {
    return '${channelId}_$channelType';
  }

  /// Check if channel info is cached and still valid
  bool _isCacheValid(String cacheKey) {
    final lastFetch = _lastFetchTime[cacheKey];
    if (lastFetch == null) return false;

    return DateTime.now().difference(lastFetch) < _cacheDuration;
  }

  /// Fetch channel information with caching and deduplication
  Future<WKChannel?> fetchChannelInfo(String channelId, int channelType) async {
    return _fetchChannelInfoInternal(channelId, channelType, false);
  }

  /// Force refresh channel information from server (bypass cache)
  Future<WKChannel?> forceRefreshChannelInfo(
    String channelId,
    int channelType,
  ) async {
    return _fetchChannelInfoInternal(channelId, channelType, true);
  }

  /// Internal method to fetch channel info with optional cache bypass
  Future<WKChannel?> _fetchChannelInfoInternal(
    String channelId,
    int channelType,
    bool forceRefresh,
  ) async {
    final cacheKey = _getCacheKey(channelId, channelType);

    // Check if we're already fetching this channel
    if (_fetchingChannels.containsKey(cacheKey)) {
      Logger.debug('Channel info fetch already in progress for $channelId');
      return _fetchingChannels[cacheKey];
    }

    // Check if we have valid cached data (skip if force refresh)
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      Logger.debug('Using cached channel info for $channelId');
      try {
        return await WKIM.shared.channelManager.getChannel(
          channelId,
          channelType,
        );
      } catch (e) {
        Logger.warning('Failed to get cached channel info: $e');
      }
    }

    // Start new fetch operation
    final fetchFuture = _performChannelFetch(channelId, channelType);
    _fetchingChannels[cacheKey] = fetchFuture;

    try {
      final result = await fetchFuture;
      _lastFetchTime[cacheKey] = DateTime.now();
      return result;
    } finally {
      // Clean up the fetching cache
      _fetchingChannels.remove(cacheKey);
    }
  }

  /// Perform the actual channel fetch from API
  Future<WKChannel?> _performChannelFetch(
    String channelId,
    int channelType,
  ) async {
    try {
      Logger.sync(
        'Channel',
        'Fetching info for $channelId (type: $channelType)',
      );

      if (channelType == WKChannelType.personal) {
        return await _fetchUserInfo(channelId);
      } else if (channelType == WKChannelType.group) {
        return await _fetchGroupInfo(channelId);
      } else {
        Logger.warning(
          'Unknown channel type: $channelType for channel $channelId',
        );
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to fetch channel info for $channelId',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Fetch user information from API
  Future<WKChannel?> _fetchUserInfo(String uid) async {
    final dio = await _createDioInstance();
    if (dio == null) return null;

    try {
      final response = await dio.get('/users/$uid');

      if (response.statusCode == 200 && response.data != null) {
        final json = response.data as Map<String, dynamic>;
        final channel = WKChannel(uid, WKChannelType.personal);
        channel.channelName = json['name'] ?? '';
        channel.avatar = json['avatar'] ?? '';
        // Mirror Android: persist personal remark (alias) if provided
        channel.channelRemark = json['remark'] ?? '';

        // Presence fields (mirror Android: online, lastOffline, deviceFlag)
        try {
          // online: accept int/bool
          final onlineVal = json.containsKey('online')
              ? json['online']
              : (json.containsKey('is_online') ? json['is_online'] : null);
          if (onlineVal is bool) channel.online = onlineVal ? 1 : 0;
          if (onlineVal is num) channel.online = onlineVal.toInt();

          // lastOffline seconds: accept common keys
          final lo =
              json['last_offline'] ??
              json['lastOffline'] ??
              json['last_logout'] ??
              json['last_offline_at'] ??
              json['last_seen'];
          if (lo is String) {
            final v = int.tryParse(lo);
            if (v != null) channel.lastOffline = v;
          } else if (lo is num) {
            channel.lastOffline = lo.toInt();
          }

          // deviceFlag: 0 app, 1 web, 2 pc
          final df =
              json['device_flag'] ?? json['deviceFlag'] ?? json['device'];
          if (df is num) channel.deviceFlag = df.toInt();
          if (df is String) {
            final s = df.toLowerCase();
            if (s.contains('web')) {
              channel.deviceFlag = 1;
            } else if (s.contains('pc') || s.contains('desktop')) {
              channel.deviceFlag = 2;
            } else {
              channel.deviceFlag = 0;
            }
          }
        } catch (e) {
          Logger.warning('Presence parse failed for $uid: $e');
        }

        Logger.api('users', 'Fetched user info: ${channel.channelName}');

        // Update channel in SDK
        WKIM.shared.channelManager.addOrUpdateChannel(channel);
        return channel;
      } else {
        Logger.warning(
          'Failed to fetch user info - status: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      Logger.error('Error fetching user info for $uid', error: e);
      return null;
    }
  }

  /// Fetch group information from API
  Future<WKChannel?> _fetchGroupInfo(String groupId) async {
    final dio = await _createDioInstance();
    if (dio == null) return null;

    try {
      final response = await dio.get('/groups/$groupId');

      if (response.statusCode == 200 && response.data != null) {
        final json = response.data as Map<String, dynamic>;
        final channel = WKChannel(groupId, WKChannelType.group);
        channel.channelName = json['name'] ?? '';
        channel.avatar = json['avatar'] ?? '';
        // Mirror Android: persist group remark and settings so they survive restarts
        channel.channelRemark = json['remark'] ?? '';

        // Permissions/status mapping
        if (json.containsKey('status')) {
          channel.status = (json['status'] ?? 1) as int;
        } else if (json.containsKey('group_status')) {
          channel.status = (json['group_status'] ?? 1) as int;
        }
        // Global mute/forbidden: accept common keys
        if (json.containsKey('forbidden')) {
          channel.forbidden = (json['forbidden'] ?? 0) as int;
        } else if (json.containsKey('mute_all')) {
          final v = json['mute_all'];
          channel.forbidden = (v is int ? v : (v == true ? 1 : 0));
        } else if (json.containsKey('banned')) {
          final v = json['banned'];
          // If API uses 'banned' boolean for group-wide mute
          channel.forbidden = (v == true ? 1 : 0);
        }

        // Other settings
        if (json.containsKey('mute')) {
          channel.mute = (json['mute'] ?? 0) as int;
        }
        if (json.containsKey('top')) {
          channel.top = (json['top'] ?? 0) as int;
        } else if (json.containsKey('stick')) {
          // Some APIs may return 'stick' like Android ChannelInfoEntity
          channel.top = (json['stick'] ?? 0) as int;
        }
        if (json.containsKey('save')) {
          channel.save = (json['save'] ?? 0) as int;
        }
        if (json.containsKey('show_nick')) {
          channel.showNick = (json['show_nick'] ?? 0) as int;
        }

        // Try to get member count from response and cache it
        int? memberCount;
        if (json.containsKey('member_count')) {
          memberCount = json['member_count'] as int?;
        } else if (json.containsKey('memberCount')) {
          memberCount = json['memberCount'] as int?;
        } else if (json.containsKey('members')) {
          // If members array is provided, count them
          final members = json['members'];
          if (members is List) {
            memberCount = members.length;
          }
        }

        // Cache member count if available
        if (memberCount != null) {
          _groupMemberCounts[groupId] = memberCount;
          _memberCountFetchTime[groupId] = DateTime.now();
        }

        Logger.api(
          'groups',
          'Fetched group info: ${channel.channelName} with ${memberCount ?? 'unknown'} members',
        );

        // Update channel in SDK
        WKIM.shared.channelManager.addOrUpdateChannel(channel);
        return channel;
      } else {
        Logger.warning(
          'Failed to fetch group info - status: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      Logger.error('Error fetching group info for $groupId', error: e);
      return null;
    }
  }

  /// Fetch group member count specifically
  Future<int?> fetchGroupMemberCount(String groupId) async {
    final dio = await _createDioInstance();
    if (dio == null) return null;

    try {
      // Try to get members list
      final response = await dio.get('/groups/$groupId/members');

      if (response.statusCode == 200 && response.data != null) {
        final json = response.data;
        if (json is List) {
          Logger.api(
            'groups',
            'Fetched ${json.length} members for group $groupId',
          );
          return json.length;
        } else if (json is Map<String, dynamic>) {
          // Check if response contains members array or count
          if (json.containsKey('members') && json['members'] is List) {
            final count = (json['members'] as List).length;
            Logger.api('groups', 'Fetched $count members for group $groupId');
            return count;
          } else if (json.containsKey('count')) {
            final count = json['count'] as int;
            Logger.api(
              'groups',
              'Fetched member count $count for group $groupId',
            );
            return count;
          }
        }
      }

      // Fallback: try to get count from group info
      final groupResponse = await dio.get('/groups/$groupId');
      if (groupResponse.statusCode == 200 && groupResponse.data != null) {
        final json = groupResponse.data as Map<String, dynamic>;
        if (json.containsKey('member_count')) {
          return json['member_count'] as int?;
        } else if (json.containsKey('memberCount')) {
          return json['memberCount'] as int?;
        }
      }

      Logger.debug('No member count available for group $groupId');
      return null;
    } catch (e) {
      Logger.error('Error fetching member count for group $groupId', error: e);
      return null;
    }
  }

  /// Get cached member count for a group
  int? getCachedMemberCount(String groupId) {
    final lastFetch = _memberCountFetchTime[groupId];
    if (lastFetch != null &&
        DateTime.now().difference(lastFetch) < _cacheDuration) {
      return _groupMemberCounts[groupId];
    }
    return null;
  }

  /// Fetch member count with caching
  Future<int?> fetchMemberCountCached(String groupId) async {
    // Check cache first
    final cached = getCachedMemberCount(groupId);
    if (cached != null) {
      return cached;
    }

    // Fetch from API
    final count = await fetchGroupMemberCount(groupId);
    if (count != null) {
      _groupMemberCounts[groupId] = count;
      _memberCountFetchTime[groupId] = DateTime.now();
    }

    return count;
  }

  /// Create Dio instance with proper configuration
  Future<Dio?> _createDioInstance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(WKConstants.uidKey);
      final token = prefs.getString(WKConstants.tokenKey);

      if (uid == null || token == null) {
        Logger.warning('Missing uid or token for API call');
        return null;
      }

      final dio = Dio();
      dio.options.baseUrl = WKApiConfig.baseUrl.isNotEmpty
          ? WKApiConfig.baseUrl
          : 'http://45.204.13.113:8099/v1/';

      dio.options.headers = {
        'Content-Type': 'application/json',
        'token': token,
        'package': 'com.test.demo',
        'os': 'iOS',
        'appid': 'wukongchat',
        'model': 'flutter_app',
        'version': '1.0',
      };

      // Interceptor to auto-logout on 401 like Android BaseObserver
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

  /// Clear cache for specific channel
  void clearChannelCache(String channelId, int channelType) {
    final cacheKey = _getCacheKey(channelId, channelType);
    _lastFetchTime.remove(cacheKey);
    _fetchingChannels.remove(cacheKey);

    // Also clear member count cache for groups
    if (channelType == WKChannelType.group) {
      _groupMemberCounts.remove(channelId);
      _memberCountFetchTime.remove(channelId);
    }
  }

  /// Clear all cache
  void clearAllCache() {
    _lastFetchTime.clear();
    _fetchingChannels.clear();
    _groupMemberCounts.clear();
    _memberCountFetchTime.clear();
  }
}
