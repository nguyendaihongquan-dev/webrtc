import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk_options;
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/model/wk_media_message_content.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../utils/logger.dart';
import 'channel_info_manager.dart';
import '../utils/navigation_service.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import 'attachment_uploader.dart';

/// Main service for managing WuKongIM SDK operations
///
/// This service handles:
/// - SDK initialization and connection management
/// - Conversation synchronization
/// - Channel information management
/// - Message synchronization
class WuKongService {
  static final WuKongService _instance = WuKongService._internal();
  factory WuKongService() => _instance;
  WuKongService._internal() {
    Logger.service('WuKongService', 'Singleton instance created');
  }

  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isLoggingOut = false;

  // Channel info manager for optimized channel fetching
  final ChannelInfoManager _channelInfoManager = ChannelInfoManager();

  // Callback for conversation sync completion
  Function()? _onConversationSyncCompleted;

  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  ChannelInfoManager get channelInfoManager => _channelInfoManager;

  /// Initialize WuKongIM SDK with proper error handling and logging
  Future<bool> initialize() async {
    Logger.service(
      'WuKongService',
      'Initialize called (current state: $_isInitialized)',
    );

    if (_isInitialized) {
      Logger.debug('SDK already initialized, skipping');
      return true;
    }

    try {
      Logger.service('WuKongService', 'Starting SDK initialization');

      // Get user credentials from SharedPreferences
      final credentials = await _getUserCredentials();
      if (credentials == null) {
        Logger.error('Missing user credentials for SDK initialization');
        return false;
      }

      Logger.debug('Found user credentials: ${credentials['uid']}');

      // Setup SDK with user credentials
      final result = await WKIM.shared.setup(
        wk_options.Options.newDefault(
          credentials['uid']!,
          credentials['token']!,
        ),
      );

      if (!result) {
        Logger.error('Failed to setup WuKongIM SDK');
        return false;
      }

      // Configure server address
      _setupServerAddress();

      // Setup all listeners
      _setupDataSourceListeners();
      _setupConnectionStatusListener();
      _setupAttachmentUploadListener();

      _isInitialized = true;
      Logger.service('WuKongService', 'SDK initialized successfully');

      return true;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to initialize SDK',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Get user credentials from SharedPreferences
  Future<Map<String, String>?> _getUserCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(WKConstants.uidKey);
      final token = prefs.getString(WKConstants.imTokenKey);

      if (uid == null || token == null) {
        return null;
      }

      return {'uid': uid, 'token': token};
    } catch (e) {
      Logger.error('Failed to get user credentials', error: e);
      return null;
    }
  }

  /// Setup server address configuration (mirror Android getImIp flow)
  void _setupServerAddress() {
    WKIM.shared.options.getAddr = (Function(String address) complete) async {
      try {
        // Fetch credentials
        final credentials = await _getUserCredentials();
        if (credentials == null) {
          Logger.error('getAddr: Missing user credentials');
          // Fallback (last known hardcoded) if credentials missing
          const fallback = '45.204.13.113:5100';
          Logger.connection('getAddr: using fallback $fallback');
          complete(fallback);
          return;
        }

        // Build Dio with same headers as Android app
        final dio = Dio();
        dio.options.baseUrl = WKApiConfig.baseUrl.isNotEmpty
            ? WKApiConfig.baseUrl
            : '${WKApiConfig.defaultBaseUrl}/v1/';
        dio.options.connectTimeout = const Duration(seconds: 8);
        dio.options.receiveTimeout = const Duration(seconds: 8);
        dio.options.headers = {
          'Content-Type': 'application/json',
          'token': credentials['token']!,
          'package': 'com.test.demo',
          'os': 'Flutter',
          'appid': 'wukongchat',
          'model': 'flutter_app',
          'version': '1.0',
        };

        // Android calls: GET users/{uid}/im -> { tcp_addr: "ip:port", ... }
        final resp = await dio.get('users/${credentials['uid']}/im');
        if (resp.statusCode == 200 && resp.data != null) {
          final data = resp.data as Map;
          final tcpAddr = (data['tcp_addr'] ?? data['tcpAddr'] ?? data['addr'])
              ?.toString();
          if (tcpAddr != null && tcpAddr.contains(':')) {
            Logger.connection('getAddr: server returned $tcpAddr');
            complete(tcpAddr);
            return;
          } else {
            Logger.warning('getAddr: invalid addr payload: ${resp.data}');
          }
        } else {
          Logger.warning('getAddr: unexpected status ${resp.statusCode}');
        }
      } catch (e, st) {
        Logger.error(
          'getAddr: error fetching IM address',
          error: e,
          stackTrace: st,
        );
      }
      // Final fallback if API fails
      const fallback = '45.204.13.113:5100';
      Logger.connection('getAddr: using fallback $fallback');
      complete(fallback);
    };
  }

  /// Set up data source listeners for WuKongIM
  void _setupDataSourceListeners() {
    Logger.service('WuKongService', 'Setting up data source listeners');

    // Listen for conversation sync requests from SDK
    WKIM.shared.conversationManager.addOnSyncConversationListener((
      lastMsgSeqs,
      msgCount,
      version,
      callback,
    ) async {
      Logger.sync(
        'Conversation',
        'SDK requested sync - msgCount: $msgCount, version: $version, lastMsgSeqs: $lastMsgSeqs',
      );

      try {
        // Call conversation sync API
        final syncResult = await _syncConversationsFromAPI(
          lastMsgSeqs,
          msgCount,
          version,
        );

        Logger.sync(
          'Conversation',
          'Sync completed with ${syncResult?.conversations?.length ?? 0} conversations',
        );

        callback(syncResult ?? (WKSyncConversation()..conversations = []));

        // Always notify conversation sync completion so UI can stop 'syncing' state
        Logger.service(
          'WuKongService',
          'Notifying conversation sync completion',
        );
        _onConversationSyncCompleted?.call();
      } catch (e, stackTrace) {
        Logger.error(
          'Conversation sync failed',
          error: e,
          stackTrace: stackTrace,
        );
        callback(WKSyncConversation()..conversations = []);
        // Even on failure, notify completion so UI can exit syncing state gracefully
        _onConversationSyncCompleted?.call();
      }
    });

    // Listen for channel info requests from SDK
    WKIM.shared.channelManager.addOnGetChannelListener((
      channelId,
      channelType,
      callback,
    ) async {
      Logger.sync(
        'Channel',
        'SDK requested channel info - channelId: $channelId, channelType: $channelType',
      );

      try {
        // Use optimized channel info manager for fetching
        final channel = await _channelInfoManager.fetchChannelInfo(
          channelId,
          channelType,
        );

        // Return the fetched channel or empty channel if fetch failed
        callback(channel ?? WKChannel(channelId, channelType));
      } catch (e, stackTrace) {
        Logger.error(
          'Channel info fetch failed for $channelId',
          error: e,
          stackTrace: stackTrace,
        );
        callback(WKChannel(channelId, channelType));
      }
    });

    // Listen for message sync requests from SDK
    WKIM.shared.messageManager.addOnSyncChannelMsgListener((
      channelID,
      channelType,
      startMessageSeq,
      endMessageSeq,
      limit,
      pullMode,
      callback,
    ) async {
      Logger.sync(
        'Message',
        'SDK requested message sync - channelID: $channelID, channelType: $channelType',
      );

      try {
        // For now, return null - in real implementation this would sync messages from API
        callback(null);
      } catch (e, stackTrace) {
        Logger.error('Message sync failed', error: e, stackTrace: stackTrace);
        callback(null);
      }
    });
  }

  /// Set up connection status listener
  void _setupConnectionStatusListener() {
    Logger.service('WuKongService', 'Setting up connection status listener');

    // Add connection status listener
    WKIM.shared.connectionManager.addOnConnectionStatus('wukong_service', (
      status,
      reason,
      connInfo,
    ) {
      Logger.connection('Status changed: $status, reason: $reason');

      if (status == WKConnectStatus.success || status == 4) {
        _isConnected = true;
        Logger.connection('Connected successfully (node: ${connInfo?.nodeId})');

        // Trigger conversation sync after successful connection
        Logger.service(
          'WuKongService',
          'Triggering conversation sync after connection',
        );
        WKIM.shared.conversationManager.setSyncConversation(() {
          Logger.sync('Conversation', 'Sync completed after connection');
          // Notify listeners that conversation sync is fully completed, even if 0 conversations
          _onConversationSyncCompleted?.call();
        });
      } else if (status == WKConnectStatus.fail ||
          status == WKConnectStatus.kicked) {
        _isConnected = false;
        Logger.connection('Connection failed or kicked');

        if (status == WKConnectStatus.kicked) {
          // Mirror Android: WKUIKitApplication.exitLogin(from = 1 when kicked)
          _handleKickedLogout(from: 1);
        }
      }
    });
  }

  void _handleKickedLogout({int from = 0}) async {
    try {
      if (_isLoggingOut) return;
      _isLoggingOut = true;
      // Disconnect IM with logout cleanup
      disconnect(logout: true);

      // Clear providers and user session
      final navigator = NavigationService.navigatorKey.currentState;
      if (navigator == null) return;
      final context = navigator.context;

      // Clear user session
      final loginProvider = Provider.of<LoginProvider>(context, listen: false);
      await loginProvider.logout();

      // Clear other providers similar to Android exitLogin
      Provider.of<ConversationProvider>(context, listen: false).clear();
      Provider.of<ChatProvider>(context, listen: false).clear();

      // Navigate to login and pass 'from' flag like Android
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.wkLogin,
        (route) => false,
        arguments: {'from': from},
      );
    } catch (e, st) {
      Logger.error('Kicked logout handling failed', error: e, stackTrace: st);
    } finally {
      // keep logging out flag true for a short time to avoid rapid re-entry
      Future.delayed(const Duration(seconds: 1), () {
        _isLoggingOut = false;
      });
    }
  }

  Future<void> forceLogout({int from = 0}) async {
    _handleKickedLogout(from: from);
  }

  /// Set callback for conversation sync completion
  void setOnConversationSyncCompleted(Function() callback) {
    _onConversationSyncCompleted = callback;
  }

  /// Connect to WuKongIM server
  Future<bool> connect() async {
    if (!_isInitialized) {
      Logger.error('Cannot connect: SDK not initialized');
      return false;
    }

    try {
      Logger.connection('Initiating connection to server');
      WKIM.shared.connectionManager.connect();
      return true;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to connect to server',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Get all conversations from local storage
  Future<List<WKUIConversationMsg>> getAllConversations() async {
    try {
      Logger.service(
        'WuKongService',
        'Getting all conversations from local storage',
      );
      final conversations = await WKIM.shared.conversationManager.getAll();
      Logger.service(
        'WuKongService',
        'Retrieved ${conversations.length} conversations',
      );
      return conversations;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to get conversations',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Add conversation refresh listener
  void addConversationRefreshListener(
    String key,
    Function(List<WKUIConversationMsg>) callback,
  ) {
    WKIM.shared.conversationManager.addOnRefreshMsgListListener(key, callback);
  }

  /// Remove conversation refresh listener
  void removeConversationRefreshListener(String key) {
    WKIM.shared.conversationManager.removeOnRefreshMsgListListener(key);
  }

  /// Add channel refresh listener
  void addChannelRefreshListener(String key, Function(WKChannel) callback) {
    WKIM.shared.channelManager.addOnRefreshListener(key, callback);
  }

  /// Remove channel refresh listener
  void removeChannelRefreshListener(String key) {
    WKIM.shared.channelManager.removeOnRefreshListener(key);
  }

  /// Add message refresh listener for real-time message updates
  void addMessageRefreshListener(String key, Function(WKMsg) callback) {
    WKIM.shared.messageManager.addOnRefreshMsgListener(key, callback);
  }

  /// Get channel from SDK cache (fast) without network
  Future<WKChannel?> findCachedChannel(
    String channelId,
    int channelType,
  ) async {
    try {
      return await WKIM.shared.channelManager.getChannel(
        channelId,
        channelType,
      );
    } catch (_) {
      return null;
    }
  }

  /// Remove message refresh listener
  void removeMessageRefreshListener(String key) {
    WKIM.shared.messageManager.removeOnRefreshMsgListener(key);
  }

  /// Disconnect from server and cleanup resources
  void disconnect({bool logout = false}) {
    try {
      Logger.connection('Disconnecting from server (logout: $logout)');
      WKIM.shared.connectionManager.disconnect(logout);
      _isConnected = false;
      Logger.connection('Disconnected successfully');
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to disconnect from server',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Sync conversations from API with optimized error handling
  Future<WKSyncConversation?> _syncConversationsFromAPI(
    String? lastMsgSeqs,
    int msgCount,
    int version,
  ) async {
    try {
      Logger.api(
        'conversation/sync',
        'Calling API - lastMsgSeqs: $lastMsgSeqs, msgCount: $msgCount, version: $version',
      );

      // Get user credentials
      final credentials = await _getUserCredentials();
      if (credentials == null) {
        Logger.error('Missing user credentials for conversation sync API call');
        return WKSyncConversation()..conversations = [];
      }

      // Create Dio instance with proper configuration
      final dio = Dio();
      dio.options.baseUrl = WKApiConfig.baseUrl.isNotEmpty
          ? WKApiConfig.baseUrl
          : 'http://45.204.13.113:8099/v1/';

      // Set headers (matching Android app headers)
      dio.options.headers = {
        'Content-Type': 'application/json',
        'token': credentials['token']!,
        'package': 'com.test.demo',
        'os': 'iOS',
        'appid': 'wukongchat',
        'model': 'flutter_app',
        'version': '1.0',
      };

      // Prepare request data
      final requestData = {
        'version': version,
        'msg_count': msgCount,
        'device_uuid': WKConstants.getDeviceID(),
      };

      if (lastMsgSeqs != null && lastMsgSeqs.isNotEmpty) {
        requestData['last_msg_seqs'] = lastMsgSeqs;
      }

      Logger.api('conversation/sync', 'Request data: $requestData');

      // Make API call
      final response = await dio.post('/conversation/sync', data: requestData);

      Logger.api(
        'conversation/sync',
        'Response status: ${response.statusCode}',
      );

      if (response.statusCode == 401) {
        // Force logout like Android BaseObserver
        await forceLogout(from: 0);
        return WKSyncConversation()..conversations = [];
      } else if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        Logger.api(
          'conversation/sync',
          'Response received - uid: ${responseData['uid']}',
        );

        // Create WKSyncConversation object
        final syncConversation = WKSyncConversation();
        syncConversation.uid = responseData['uid'] ?? '';
        syncConversation.conversations = [];

        // Parse conversations
        final conversationsData =
            responseData['conversations'] as List<dynamic>?;

        Logger.api(
          'conversation/sync',
          'Parsing ${conversationsData?.length ?? 0} conversations',
        );
        if (conversationsData != null) {
          for (int i = 0; i < conversationsData.length; i++) {
            try {
              final convData = conversationsData[i];
              final convMap = convData as Map<String, dynamic>;

              Logger.debug('Processing conversation: ${convMap['channel_id']}');

              final syncConvMsg = WKSyncConvMsg();

              syncConvMsg.channelID = convMap['channel_id'] ?? '';
              syncConvMsg.channelType = convMap['channel_type'] ?? 0;
              syncConvMsg.lastClientMsgNO = convMap['last_client_msg_no'] ?? '';
              syncConvMsg.lastMsgSeq = convMap['last_msg_seq'] ?? 0;
              syncConvMsg.offsetMsgSeq = convMap['offset_msg_seq'] ?? 0;
              syncConvMsg.timestamp = convMap['timestamp'] ?? 0;
              syncConvMsg.unread = convMap['unread'] ?? 0;
              syncConvMsg.version = convMap['version'] ?? 0;

              Logger.debug('Created syncConvMsg for ${syncConvMsg.channelID}');

              // Parse recent messages if available
              final recentsData = convMap['recents'] as List<dynamic>?;
              if (recentsData != null) {
                Logger.debug('Parsing ${recentsData.length} recent messages');
                syncConvMsg.recents = [];
                for (final recentData in recentsData) {
                  final recentMap = recentData as Map<String, dynamic>;
                  final syncMsg = WKSyncMsg();

                  syncMsg.messageID = (recentMap['message_id'] ?? '')
                      .toString();
                  syncMsg.messageSeq = recentMap['message_seq'] ?? 0;
                  syncMsg.clientMsgNO = recentMap['client_msg_no'] ?? '';
                  syncMsg.fromUID = recentMap['from_uid'] ?? '';
                  syncMsg.channelID = recentMap['channel_id'] ?? '';
                  syncMsg.channelType = recentMap['channel_type'] ?? 0;
                  syncMsg.timestamp = recentMap['timestamp'] ?? 0;
                  syncMsg.payload = recentMap['payload'];

                  syncConvMsg.recents!.add(syncMsg);
                }
              }

              syncConversation.conversations!.add(syncConvMsg);
              Logger.debug(
                'Added conversation ${syncConvMsg.channelID} to result',
              );
            } catch (e) {
              Logger.warning('Error parsing conversation $i: $e');
            }
          }
        }

        Logger.api(
          'conversation/sync',
          'Successfully parsed ${syncConversation.conversations?.length ?? 0} conversations',
        );

        // Call syncack API to acknowledge the sync
        await _callSyncAckAPI(dio);

        return syncConversation;
      } else {
        Logger.warning(
          'Conversation sync API failed with status: ${response.statusCode}',
        );
        return WKSyncConversation()..conversations = [];
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Conversation sync API call failed',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is DioException && e.response?.statusCode == 401) {
        await forceLogout(from: 0);
      }
      return WKSyncConversation()..conversations = [];
    }
  }

  /// Call conversation sync acknowledgment API
  Future<void> _callSyncAckAPI(Dio dio) async {
    try {
      Logger.api('conversation/syncack', 'Calling sync acknowledgment API');

      // Prepare request data
      final requestData = {'device_uuid': WKConstants.getDeviceID()};
      Logger.api('conversation/syncack', 'Request data: $requestData');

      // Make API call
      final response = await dio.post(
        '/conversation/syncack',
        data: requestData,
      );

      Logger.api(
        'conversation/syncack',
        'Response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        Logger.api('conversation/syncack', 'Sync acknowledgment successful');
      } else {
        Logger.warning(
          'Sync acknowledgment failed with status: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Sync acknowledgment API call failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Note: Channel info fetching is now handled by ChannelInfoManager
  // Old _fetchUserInfo and _fetchGroupInfo methods have been removed

  /// Setup listener to upload media attachments (image/voice) before sending
  void _setupAttachmentUploadListener() {
    try {
      WKIM.shared.messageManager.addOnUploadAttachmentListener((
        wkMsg,
        complete,
      ) async {
        try {
          final content = wkMsg.messageContent;
          if (content == null) {
            Logger.warning('UploadAttachment: messageContent is null');
            complete(false, wkMsg);
            return;
          }
          if (content is! WKMediaMessageContent) {
            // Not a media message; nothing to upload
            complete(true, wkMsg);
            return;
          }
          final media = content; // WKMediaMessageContent
          final localPath = media.localPath;
          if (localPath.isEmpty) {
            Logger.warning('UploadAttachment: localPath is empty');
            complete(false, wkMsg);
            return;
          }
          final channelId = wkMsg.channelID;
          final channelType = wkMsg.channelType;
          final ticket = await AttachmentUploader().getUploadFileUrl(
            channelId,
            channelType,
            localPath,
          );
          if (ticket == null) {
            Logger.error('UploadAttachment: failed to get upload URL');
            complete(false, wkMsg);
            return;
          }
          final uploadedPath = await AttachmentUploader().upload(
            ticket.uploadUrl,
            localPath,
          );
          if (uploadedPath == null || uploadedPath.isEmpty) {
            Logger.error('UploadAttachment: upload failed');
            complete(false, wkMsg);
            return;
          }
          media.url = uploadedPath;
          Logger.service(
            'WuKongService',
            'UploadAttachment success for ${wkMsg.clientMsgNO}: $uploadedPath',
          );
          complete(true, wkMsg);
        } catch (e, st) {
          Logger.error('UploadAttachment error', error: e, stackTrace: st);
          complete(false, wkMsg);
        }
      });
    } catch (e) {
      Logger.error('Failed to setup upload attachment listener', error: e);
    }
  }

  /// Cleanup resources
  void dispose() {
    disconnect(logout: true);
    _isInitialized = false;
  }
}
