import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/model/wk_card_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:qgim_client_flutter/widgets/chatview/chatview.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import '../utils/logger.dart';
import '../services/msg_service.dart';
import '../providers/auth_provider.dart';
import '../config/constants.dart';
import '../models/wk_mention_text_content.dart';
import '../services/contacts_service.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../utils/navigation_service.dart';
import '../providers/conversation_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._loginProvider) {
    _initMsgService();
  }

  String? _lastToken;
  String? _lastBaseUrl;

  void _initMsgService() {
    // Initialize MsgService with auth header - delay if baseUrl not ready
    final currentBaseUrl = WKApiConfig.baseUrl.isNotEmpty
        ? WKApiConfig.baseUrl
        : '${WKApiConfig.defaultBaseUrl}/v1/';
    final currentToken = _loginProvider.currentUser?.token ?? '';

    // Avoid rebuilding Dio if nothing changed
    if (_lastToken == currentToken && _lastBaseUrl == currentBaseUrl) {
      return;
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: currentBaseUrl,
        headers: {
          'Content-Type': 'application/json',
          'token': currentToken,
          'package': 'com.test.demo',
          'os': 'iOS',
          'appid': 'wukongchat',
          'model': 'flutter_app',
          'version': '1.0',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              final nav = NavigationService.navigatorKey.currentState;
              if (nav != null) {
                final context = nav.context;
                await _loginProvider.logout();
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
    _msgService = MsgService(dio);
    _lastToken = currentToken;
    _lastBaseUrl = currentBaseUrl;
  }

  // Call when auth state (token/baseUrl) may have changed
  void onAuthChanged() {
    _initMsgService();
    // Reset cached UID for typing comparison to ensure it reflects new user
    resetCache();
  }

  // Current channel info
  String _channelId = '';
  int _channelType = WKChannelType.personal;
  WKChannel? _currentChannel;

  // Messages
  List<WKMsg> _messages = [];
  bool _isLoading = false;
  bool _isSendingMessage = false;
  String _error = '';

  // Typing state
  bool _isTyping = false;
  String _typingUserName = '';
  String _typingUserId = '';
  Timer? _typingTimer;

  // Message pagination (Android parity)
  // Tracks the smallest orderSeq among currently loaded messages to fetch older ones
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 30; // Android ChatActivity.limit = 30

  // Initial unread divider support (Android parity)
  // If set, initial load will center around this orderSeq and we will insert an
  // unread divider at this boundary just like Android's WKContentType.msgPromptNewMsg
  int _initialAroundOrderSeq = 0;
  int _unreadStartOrderSeq = 0;
  bool _shouldInsertUnreadDivider = false;

  // Typing status management
  Timer? _sendTypingTimer;
  int _lastTypingTime = 0;
  late MsgService _msgService;
  final LoginProvider _loginProvider;

  // Message delay management for typing interruption
  Timer? _messageDelayTimer;
  final List<WKMsg> _pendingMessages = [];
  bool _isDelayingMessages = false;

  // Cached values for performance
  String? _cachedCurrentUserUid;

  // Constants for typing logic
  static const int _typingCooldownSeconds = 5;
  static const int _typingTimeoutSeconds = 5;

  // Whether the chat screen for current channel is currently visible (top route)
  bool _isChatForeground = false;
  bool get isChatForeground => _isChatForeground;
  void setChatForeground(bool value) {
    _isChatForeground = value;

    // Notify ConversationProvider about active chat status
    try {
      final nav = NavigationService.navigatorKey.currentState;
      if (nav != null) {
        final context = nav.context;
        final conversationProvider = Provider.of<ConversationProvider>(
          context,
          listen: false,
        );

        if (value && _channelId.isNotEmpty) {
          // Chat screen is now foreground
          conversationProvider.setActiveChat(_channelId, _channelType, true);
        } else {
          // Chat screen is no longer foreground
          conversationProvider.clearActiveChat();
        }
      }
    } catch (e) {
      Logger.error('Failed to update active chat status', error: e);
    }
  }

  /// Delete a single message locally by clientMsgNo
  Future<bool> deleteLocalMessage(String clientMsgNo) async {
    try {
      // Delete from SDK local DB
      await WKIM.shared.messageManager.deleteWithClientMsgNo(clientMsgNo);
      // Remove from in-memory list and notify
      final idx = _messages.indexWhere((m) => m.clientMsgNO == clientMsgNo);
      if (idx != -1) {
        _messages.removeAt(idx);
        notifyListeners();
      }
      return true;
    } catch (e) {
      Logger.error('deleteLocalMessage error', error: e);
      return false;
    }
  }

  /// Delete messages on server for everyone, then delete locally
  Future<bool> deleteMessagesForEveryone(List<String> clientMsgNos) async {
    try {
      if (clientMsgNos.isEmpty) return false;
      // Map to WKMsg from in-memory list
      final list = _messages
          .where((m) => clientMsgNos.contains(m.clientMsgNO))
          .toList();
      if (list.isEmpty) return false;

      final ok = await _msgService.deleteMessages(list);
      if (ok) {
        // Delete locally as well
        for (final m in list) {
          try {
            await WKIM.shared.messageManager.deleteWithClientMsgNo(
              m.clientMsgNO,
            );
          } catch (_) {}
        }
        // Update in-memory list and notify
        _messages.removeWhere((m) => clientMsgNos.contains(m.clientMsgNO));
        notifyListeners();
      }
      return ok;
    } catch (e) {
      Logger.error('deleteMessagesForEveryone error', error: e);
      return false;
    }
  }

  // Getters
  String get channelId => _channelId;
  int get channelType => _channelType;
  WKChannel? get currentChannel => _currentChannel;
  List<WKMsg> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;
  String get error => _error;
  bool get isTyping => _isTyping;
  String get typingUserName => _typingUserName;
  String get typingUserId => _typingUserId;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isLoadingMore => _isLoadingMore;

  /// Initialize chat with channel ID and type
  Future<void> initializeChat(String channelId, int channelType) async {
    Logger.service(
      'ChatProvider',
      'Initializing chat: $channelId, type: $channelType',
    );

    _channelId = channelId;
    _channelType = channelType;
    _messages = [];
    _hasMoreMessages = true;
    _error = '';

    // Load channel info
    await _loadChannelInfo();

    // Setup listeners
    _setupListeners();

    // Load initial messages
    await loadMessages();

    // Update active chat status if currently foreground
    if (_isChatForeground) {
      try {
        final nav = NavigationService.navigatorKey.currentState;
        if (nav != null) {
          final context = nav.context;
          final conversationProvider = Provider.of<ConversationProvider>(
            context,
            listen: false,
          );
          conversationProvider.setActiveChat(_channelId, _channelType, true);
        }
      } catch (e) {
        Logger.error(
          'Failed to update active chat status during init',
          error: e,
        );
      }
    }

    notifyListeners();
  }

  /// Configure initial unread divider placement by providing the orderSeq
  /// at which unread messages begin. This mirrors Android's
  /// `unreadStartMsgOrderSeq` behavior.
  void setInitialUnreadDivider(int aroundOrderSeq) {
    _initialAroundOrderSeq = aroundOrderSeq;
    _unreadStartOrderSeq = aroundOrderSeq;
    _shouldInsertUnreadDivider = aroundOrderSeq > 0;
  }

  /// Load channel information
  Future<void> _loadChannelInfo() async {
    try {
      Logger.service('ChatProvider', 'Loading channel info: $_channelId');

      _currentChannel = await WKIM.shared.channelManager.getChannel(
        _channelId,
        _channelType,
      );

      if (_currentChannel == null) {
        Logger.service(
          'ChatProvider',
          'Channel not found, fetching from server',
        );
        await WKIM.shared.channelManager.fetchChannelInfo(
          _channelId,
          _channelType,
        );
        _currentChannel = await WKIM.shared.channelManager.getChannel(
          _channelId,
          _channelType,
        );
      }

      // If channel name is empty or looks like an ID, try to refresh from server
      if (_currentChannel != null &&
          (_currentChannel!.channelName.isEmpty ||
              _currentChannel!.channelName.length > 30 || // Likely an ID
              (_currentChannel!.channelRemark.isEmpty && _channelType == 1))) {
        // Personal chat should have remark
        Logger.service(
          'ChatProvider',
          'Channel info incomplete, refreshing from server',
        );
        await WKIM.shared.channelManager.fetchChannelInfo(
          _channelId,
          _channelType,
        );
        _currentChannel = await WKIM.shared.channelManager.getChannel(
          _channelId,
          _channelType,
        );
      }

      Logger.service(
        'ChatProvider',
        'Channel loaded: ${_currentChannel?.channelName}, remark: ${_currentChannel?.channelRemark}, ID: ${_currentChannel?.channelID}',
      );
    } catch (e) {
      Logger.error('Failed to load channel info', error: e);
    }
  }

  /// Toggle mute setting for current personal chat (uses FriendModel API)
  Future<bool> setMute(bool mute) async {
    try {
      if (_channelType != WKChannelType.personal || _channelId.isEmpty) {
        return false;
      }
      final success = await ContactsService().updateUserSettingForFriend(
        _channelId,
        'mute',
        mute ? 1 : 0,
      );
      if (success) {
        _currentChannel?.mute = mute ? 1 : 0;
        if (_currentChannel != null) {
          WKIM.shared.channelManager.addOrUpdateChannel(_currentChannel!);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      Logger.error('setMute error', error: e);
      return false;
    }
  }

  /// Toggle top (stick) setting for current personal chat
  Future<bool> setTop(bool top) async {
    try {
      if (_channelType != WKChannelType.personal || _channelId.isEmpty) {
        return false;
      }
      final success = await ContactsService().updateUserSettingForFriend(
        _channelId,
        'top',
        top ? 1 : 0,
      );
      if (success) {
        _currentChannel?.top = top ? 1 : 0;
        if (_currentChannel != null) {
          WKIM.shared.channelManager.addOrUpdateChannel(_currentChannel!);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      Logger.error('setTop error', error: e);
      return false;
    }
  }

  /// Clear chat history locally and optionally offset on server
  Future<void> clearChatHistory({bool alsoOffsetServer = true}) async {
    try {
      if (_channelId.isEmpty) return;
      await WKIM.shared.messageManager.clearWithChannel(
        _channelId,
        _channelType,
      );
      if (alsoOffsetServer) {
        _msgService.offsetMsg(_channelId, _channelType);
      }
      _messages.clear();
      notifyListeners();
    } catch (e) {
      Logger.error('clearChatHistory error', error: e);
    }
  }

  /// Set up message and channel listeners
  void _setupListeners() {
    Logger.service('ChatProvider', 'Setting up chat listeners');

    // Listen for message insert (when message is saved to local DB before sending)
    WKIM.shared.messageManager.addOnMsgInsertedListener((msg) {
      Logger.service(
        'ChatProvider',
        'Message inserted: ${msg.clientMsgNO} for channel: ${msg.channelID}',
      );

      if (msg.channelID == _channelId && msg.channelType == _channelType) {
        // Check if message already exists to avoid duplicates
        final existingIndex = _messages.indexWhere(
          (m) => m.clientMsgNO == msg.clientMsgNO,
        );
        if (existingIndex == -1) {
          _messages.insert(0, msg);
          Logger.service(
            'ChatProvider',
            'Added new message to UI: ${msg.clientMsgNO}',
          );
          notifyListeners();
        }
      }
    });

    // Listen for new messages from other users
    WKIM.shared.messageManager.addOnNewMsgListener('chat_provider', (messages) {
      Logger.service(
        'ChatProvider',
        'Received ${messages.length} new messages',
      );

      bool hasNewMessages = false;
      bool hasRegularMessages = false;
      List<WKMsg> newRegularMessages = [];

      for (final msg in messages) {
        Logger.service(
          'ChatProvider',
          'Processing message: channelID=${msg.channelID}, channelType=${msg.channelType}, content=${msg.messageContent?.displayText()}',
        );

        // Print raw JSON payload for debugging (useful for mention issues)
        try {
          Logger.service(
            'ChatProvider',
            '❤️RAW incoming message JSON: ${msg.content}',
          );
        } catch (_) {}

        // Note: Global notifications are now handled by ConversationProvider

        if (msg.channelID == _channelId && msg.channelType == _channelType) {
          // Handle typing messages - check if message content contains typing payload
          if (_isTypingMessage(msg)) {
            Logger.service('ChatProvider', 'Detected typing message');
            _handleTypingMessage(msg);
            continue;
          }

          // Check if message already exists to avoid duplicates
          final existingIndex = _messages.indexWhere(
            (m) => m.clientMsgNO == msg.clientMsgNO,
          );
          if (existingIndex == -1) {
            newRegularMessages.add(msg);
            hasNewMessages = true;
            hasRegularMessages = true;
          }
        }
      }

      // Handle new regular messages with typing delay logic
      if (hasRegularMessages) {
        if (_isTyping) {
          Logger.service(
            'ChatProvider',
            'Clearing typing indicator and delaying ${newRegularMessages.length} messages by 350ms',
          );

          // Clear typing indicator immediately
          _clearTyping();

          // Add messages to pending list
          _pendingMessages.addAll(newRegularMessages);

          // Start delay timer if not already running
          if (!_isDelayingMessages) {
            _isDelayingMessages = true;
            _messageDelayTimer = Timer(const Duration(milliseconds: 350), () {
              _processPendingMessages();
            });
          }

          // Don't call notifyListeners() here - will be called after delay
          return;
        } else {
          // No typing, add messages immediately
          _messages.insertAll(0, newRegularMessages);
        }

        // Auto-read only when chat screen is foreground
        try {
          if (_isChatForeground && _channelId.isNotEmpty) {
            WKIM.shared.conversationManager.updateRedDot(
              _channelId,
              _channelType,
              0,
            );
          }
        } catch (_) {}
      }

      if (hasNewMessages) {
        notifyListeners();
      }
    });

    // Listen for message updates (status, reactions, etc.)
    WKIM.shared.messageManager.addOnRefreshMsgListener('chat_provider', (msg) {
      Logger.service(
        'ChatProvider',
        'Message updated: ${msg.clientMsgNO}, status: ${msg.status}',
      );

      if (msg.channelID == _channelId && msg.channelType == _channelType) {
        final index = _messages.indexWhere(
          (m) => m.clientMsgNO == msg.clientMsgNO,
        );
        if (index != -1) {
          _messages[index] = msg;

          // Also notify ChatController about the message status update
          _notifyMessageStatusUpdate(msg);

          notifyListeners();
        }
      }
    });

    // Listen for channel updates
    WKIM.shared.channelManager.addOnRefreshListener('chat_provider', (channel) {
      if (channel.channelID == _channelId &&
          channel.channelType == _channelType) {
        Logger.service(
          'ChatProvider',
          'Channel updated: ${channel.channelName}, remark: ${channel.channelRemark}',
        );
        _currentChannel = channel;
        notifyListeners();
      }
    });

    // Listen for typing status - support both wk_typing and typing commands
    WKIM.shared.cmdManager.addOnCmdListener('chat_provider', (cmd) {
      if (cmd.cmd == 'wk_typing' || cmd.cmd == 'typing') {
        _handleTypingCommand(cmd);
      }
    });
  }

  /// Check if message is a typing message
  bool _isTypingMessage(WKMsg msg) {
    try {
      // Check if message content contains typing payload
      if (msg.messageContent != null) {
        final content = msg.messageContent!.displayText();
        Logger.service('ChatProvider', 'Checking message content: $content');

        // Parse JSON content to check for typing command
        if (content.contains('"cmd":"typing"') &&
            content.contains('"type":99')) {
          Logger.service('ChatProvider', 'Found typing message!');
          return true;
        }
      }
      return false;
    } catch (e) {
      Logger.error('Error checking typing message', error: e);
      return false;
    }
  }

  /// Handle typing message from type=99 messages
  void _handleTypingMessage(WKMsg msg) {
    try {
      if (msg.messageContent == null) return;

      final content = msg.messageContent!.displayText();
      Logger.service('ChatProvider', 'Handling typing message: $content');

      // Try to parse as JSON first (more efficient than regex)
      Map<String, dynamic>? typingData;
      try {
        // Extract JSON from the content if it contains typing command
        if (content.contains('"cmd":"typing"')) {
          final jsonStart = content.indexOf('{');
          final jsonEnd = content.lastIndexOf('}');
          if (jsonStart >= 0 && jsonEnd > jsonStart) {
            final jsonStr = content.substring(jsonStart, jsonEnd + 1);
            typingData = jsonDecode(jsonStr) as Map<String, dynamic>;
          }
        }
      } catch (_) {
        // Fallback to regex if JSON parsing fails
        typingData = _parseTypingDataWithRegex(content);
      }

      if (typingData != null) {
        _processTypingData(
          channelId: typingData['channel_id']?.toString() ?? '',
          channelType: typingData['channel_type'] ?? 0,
          fromUid: typingData['from_uid']?.toString() ?? '',
          fromName: typingData['from_name']?.toString() ?? '',
          source: 'message',
        );
      }
    } catch (e) {
      Logger.error('Failed to handle typing message', error: e);
    }
  }

  /// Clear typing indicator and cancel timer
  void _clearTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;
    _isTyping = false;
    _typingUserName = '';
    _typingUserId = '';
    notifyListeners();
  }

  /// Handle typing command
  void _handleTypingCommand(WKCMD cmd) {
    try {
      if (cmd.param is! Map) return;

      final params = cmd.param as Map;
      _processTypingData(
        channelId: params['channel_id']?.toString() ?? '',
        channelType: params['channel_type'] ?? 0,
        fromUid: params['from_uid']?.toString() ?? '',
        fromName: params['from_name']?.toString() ?? '',
        source: 'command',
      );
    } catch (e) {
      Logger.error('Failed to handle typing command', error: e);
    }
  }

  /// Parse typing data using regex as fallback
  Map<String, dynamic>? _parseTypingDataWithRegex(String content) {
    try {
      final channelIdMatch = RegExp(
        r'"channel_id":"([^"]+)"',
      ).firstMatch(content);
      final channelTypeMatch = RegExp(
        r'"channel_type":(\d+)',
      ).firstMatch(content);
      final fromUidMatch = RegExp(r'"from_uid":"([^"]+)"').firstMatch(content);
      final fromNameMatch = RegExp(
        r'"from_name":"([^"]+)"',
      ).firstMatch(content);

      if (channelIdMatch == null ||
          channelTypeMatch == null ||
          fromUidMatch == null) {
        return null;
      }

      return {
        'channel_id': channelIdMatch.group(1) ?? '',
        'channel_type': int.tryParse(channelTypeMatch.group(1) ?? '0') ?? 0,
        'from_uid': fromUidMatch.group(1) ?? '',
        'from_name': fromNameMatch?.group(1) ?? '',
      };
    } catch (e) {
      Logger.error('Failed to parse typing data with regex', error: e);
      return null;
    }
  }

  /// Process typing data from either command or message
  void _processTypingData({
    required String channelId,
    required int channelType,
    required String fromUid,
    required String fromName,
    required String source,
  }) {
    // Cache current user UID for performance
    _cachedCurrentUserUid ??= _loginProvider.currentUser?.uid ?? '';

    // Validate typing data
    if (!_isValidTypingData(channelId, channelType, fromUid)) {
      Logger.service(
        'ChatProvider',
        '$source: Ignoring typing from self or invalid user: $fromUid vs $_cachedCurrentUserUid',
      );
      return;
    }

    // Show typing indicator
    _showTypingIndicator(fromName, fromUid, source);
  }

  /// Validate if typing data should be processed
  bool _isValidTypingData(String channelId, int channelType, String fromUid) {
    return channelId == _channelId &&
        channelType == _channelType &&
        fromUid != _cachedCurrentUserUid &&
        fromUid.isNotEmpty;
  }

  /// Show typing indicator with timeout
  void _showTypingIndicator(String fromName, String fromUid, String source) {
    // Cancel previous typing timer if exists
    _typingTimer?.cancel();

    _isTyping = true;
    _typingUserName = fromName;
    _typingUserId = fromUid;

    Logger.service(
      'ChatProvider',
      '$source: User $fromName ($fromUid) is typing (current user: $_cachedCurrentUserUid)',
    );
    notifyListeners();

    // Set new timer to clear typing after timeout
    _typingTimer = Timer(const Duration(seconds: _typingTimeoutSeconds), () {
      _clearTyping();
    });
  }

  /// Helper: compute current oldest (minimum) orderSeq in memory
  int _computeMinOrderSeq() {
    if (_messages.isEmpty) return 0;
    int minSeq = _messages.first.orderSeq;
    for (final m in _messages) {
      if (m.orderSeq < minSeq) minSeq = m.orderSeq;
    }
    return minSeq;
  }

  /// Load messages from local storage or sync from server
  /// Android parity:
  /// - Initial load: pullMode=1 (down), oldestOrderSeq=0, limit=30
  /// - Load more older (scroll up): pullMode=0 (up), oldestOrderSeq=min(orderSeq in memory), limit=30
  Future<void> loadMessages({bool loadMore = false}) async {
    if (loadMore && (!_hasMoreMessages || _isLoadingMore)) {
      Logger.service(
        'ChatProvider',
        'Skip loadMore (hasMore=$_hasMoreMessages, isLoadingMore=$_isLoadingMore)',
      );
      return;
    }

    try {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _messages = [];
        _hasMoreMessages = true;
      }
      notifyListeners();

      // Determine params (Android parity)
      // Initial: pullMode=0, oldestOrderSeq=0
      // Load more older (scroll up): pullMode=0, oldestOrderSeq=min(current)
      final pullMode = 0; // 0: down (older direction in Android's naming)
      final oldestOrderSeq = loadMore ? _computeMinOrderSeq() : 0;
      Logger.service(
        'ChatProvider',
        'Loading messages (loadMore=$loadMore) channel=$_channelId/$_channelType, oldestOrderSeq=$oldestOrderSeq, pullMode=$pullMode, limit=$_pageSize, aroundOrderSeq=${loadMore ? 0 : _initialAroundOrderSeq}',
      );

      await WKIM.shared.messageManager.getOrSyncHistoryMessages(
        _channelId,
        _channelType,
        oldestOrderSeq,
        false, // contain
        pullMode,
        _pageSize,
        loadMore
            ? 0
            : _initialAroundOrderSeq, // aroundMsgOrderSeq (center initial load around unread)
        (messages) {
          Logger.service(
            'ChatProvider',
            'SDK returned ${messages.length} msgs (loadMore=$loadMore)',
          );

          if (messages.isEmpty) {
            _hasMoreMessages = false;
          } else {
            if (loadMore) {
              // Append older messages to the end while avoiding duplicates
              final existingIds = _messages.map((m) => m.clientMsgNO).toSet();
              final toAppend = messages
                  .where((m) => !existingIds.contains(m.clientMsgNO))
                  .toList();
              _messages.addAll(toAppend);
              Logger.service(
                'ChatProvider',
                'Appended ${toAppend.length} older msgs; total=${_messages.length}',
              );
            } else {
              _messages = messages;
              Logger.service(
                'ChatProvider',
                'Initial loaded msgs=${_messages.length}',
              );

              // Insert unread divider if configured and applicable (Android parity)
              if (_shouldInsertUnreadDivider && _unreadStartOrderSeq > 0) {
                try {
                  // Always keep messages sorted by orderSeq ascending before inserting divider
                  _messages.sort((a, b) => a.orderSeq.compareTo(b.orderSeq));

                  // Find exact index where unread starts; fallback to the next greater orderSeq
                  int insertIndex = _messages.indexWhere(
                    (m) => m.orderSeq == _unreadStartOrderSeq,
                  );
                  if (insertIndex == -1) {
                    for (int i = 0; i < _messages.length; i++) {
                      if (_messages[i].orderSeq > _unreadStartOrderSeq) {
                        insertIndex = i;
                        break;
                      }
                    }
                  }
                  if (insertIndex == -1) insertIndex = _messages.length;

                  // Build synthetic WKMsg for unread divider (contentType -1)
                  final divider = WKMsg();
                  divider.channelID = _channelId;
                  divider.channelType = _channelType;
                  divider.contentType = -1; // WKContentType.msgPromptNewMsg
                  divider.content = 'The following is new news';
                  divider.orderSeq = _unreadStartOrderSeq;
                  // Use neighbor timestamp if available for stable ordering
                  if (_messages.isNotEmpty) {
                    final neighbor = insertIndex < _messages.length
                        ? _messages[insertIndex]
                        : _messages[_messages.length - 1];
                    divider.timestamp = neighbor.timestamp;
                  }
                  _messages.insert(insertIndex, divider);
                } catch (e) {
                  Logger.error('Failed to insert unread divider', error: e);
                } finally {
                  // Only insert once for the initial load
                  _shouldInsertUnreadDivider = false;
                  _initialAroundOrderSeq = 0;
                }
              }
            }

            // Always keep messages sorted by orderSeq ascending (Android parity)
            _messages.sort((a, b) => a.orderSeq.compareTo(b.orderSeq));
          }

          _isLoading = false;
          _isLoadingMore = false;
          notifyListeners();
        },
        () {
          Logger.service(
            'ChatProvider',
            'Syncing messages from server (SDK sync back)',
          );
        },
      );
    } catch (e) {
      Logger.error('Failed to load messages', error: e);
      _error = 'Failed to load messages: ${e.toString()}';
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Send text message
  Future<void> sendTextMessage(String content) async {
    if (content.trim().isEmpty || _isSendingMessage) return;

    try {
      _isSendingMessage = true;
      _error = '';
      notifyListeners();

      Logger.service('ChatProvider', 'Sending text message: $content');

      // Create text content
      final textContent = WKTextContent(content.trim());

      // Create channel
      final channel = WKChannel(_channelId, _channelType);

      // Send message - this will trigger the message insert listener
      WKIM.shared.messageManager.sendMessage(textContent, channel);
      Logger.service(
        'ChatProvider',
        'Message sent to SDK - will track status updates',
      );

      // Message will be added to the UI via the message insert listener
      // Status updates will be handled by addOnRefreshMsgListener
    } catch (e) {
      Logger.error('Failed to send message', error: e);
      _error = 'Failed to send message: ${e.toString()}';
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Send mention text message
  Future<void> sendMentionTextMessage(
    WKMentionTextContent mentionContent,
  ) async {
    if (mentionContent.content.trim().isEmpty || _isSendingMessage) return;

    try {
      _isSendingMessage = true;
      _error = '';
      notifyListeners();

      Logger.service(
        'ChatProvider',
        'Sending mention text message: ${mentionContent.content} with ${mentionContent.mentionEntities.length} mentions',
      );

      // Validate entities before sending
      mentionContent.validateEntities();

      // Create channel
      final channel = WKChannel(_channelId, _channelType);

      // Send message - this will trigger the message insert listener
      WKIM.shared.messageManager.sendMessage(mentionContent, channel);
      Logger.service(
        'ChatProvider',
        'Mention message sent to SDK - will track status updates',
      );

      // Log mention details for debugging
      for (final entity in mentionContent.mentionEntities) {
        Logger.service(
          'ChatProvider',
          'Mention: ${entity.displayName} (${entity.value}) at offset ${entity.offset}',
        );
      }

      // Message will be added to the UI via the message insert listener
      // Status updates will be handled by addOnRefreshMsgListener
    } catch (e) {
      Logger.error('Failed to send mention text message', error: e);
      _error = 'Failed to send mention message: ${e.toString()}';
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Send mention text message with reply
  Future<void> sendMentionTextMessageWithReply(
    WKMentionTextContent mentionContent,
    ReplyMessage replyMessage,
  ) async {
    if (mentionContent.content.trim().isEmpty || _isSendingMessage) return;

    try {
      _isSendingMessage = true;
      _error = '';
      notifyListeners();

      Logger.service(
        'ChatProvider',
        'Sending mention text message with reply: ${mentionContent.content} with ${mentionContent.mentionEntities.length} mentions',
      );

      // Validate entities before sending
      mentionContent.validateEntities();

      // Create reply object
      final wkReply = WKReply();
      wkReply.messageId = replyMessage.messageId;
      wkReply.fromUID = replyMessage.replyBy;

      // Set reply to mention content
      mentionContent.reply = wkReply;

      // Create channel
      final channel = WKChannel(_channelId, _channelType);

      // Send message - this will trigger the message insert listener
      WKIM.shared.messageManager.sendMessage(mentionContent, channel);

      Logger.service(
        'ChatProvider',
        'Mention message with reply sent to SDK - will track status updates',
      );

      // Log mention details for debugging
      for (final entity in mentionContent.mentionEntities) {
        Logger.service(
          'ChatProvider',
          'Mention with reply: ${entity.displayName} (${entity.value}) at offset ${entity.offset}',
        );
      }

      // Message will be added to the UI via the message insert listener
      // Status updates will be handled by addOnRefreshMsgListener
    } catch (e) {
      Logger.error('Failed to send mention text message with reply', error: e);
      _error = 'Failed to send mention message: ${e.toString()}';
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Send text message with reply
  Future<void> sendTextMessageWithReply(
    String content,
    ReplyMessage replyMessage,
  ) async {
    if (content.trim().isEmpty || _isSendingMessage) return;

    try {
      _isSendingMessage = true;
      _error = '';
      notifyListeners();

      Logger.service(
        'ChatProvider',
        'Sending text message with reply: $content',
      );

      // Create text content
      final textContent = WKTextContent(content.trim());

      // Find the original message to get proper data
      WKMsg? originalMsg;
      for (final msg in _messages) {
        if (msg.clientMsgNO == replyMessage.messageId) {
          originalMsg = msg;
          break;
        }
      }

      if (originalMsg != null) {
        // Create WKReply object following Android implementation
        final wkReply = WKReply();

        // Set payload - use edited content if available, otherwise original content
        if (originalMsg.wkMsgExtra != null &&
            originalMsg.wkMsgExtra!.messageContent != null) {
          wkReply.payload = originalMsg.wkMsgExtra!.messageContent;
        } else {
          wkReply.payload = originalMsg.messageContent;
        }

        // Set sender name
        String showName = '';
        if (originalMsg.getFrom() != null) {
          showName = originalMsg.getFrom()!.channelName;
        } else {
          final channel = await WKIM.shared.channelManager.getChannel(
            originalMsg.fromUID,
            WKChannelType.personal,
          );
          if (channel != null) showName = channel.channelName;
        }

        wkReply.fromName = showName;
        wkReply.fromUID = originalMsg.fromUID;
        wkReply.messageId = originalMsg.messageID;
        wkReply.messageSeq = originalMsg.messageSeq;

        // Set rootMid for threading - if replying to a reply, use the original rootMid
        if (originalMsg.messageContent != null &&
            originalMsg.messageContent!.reply != null &&
            originalMsg.messageContent!.reply!.rootMid.isNotEmpty) {
          wkReply.rootMid = originalMsg.messageContent!.reply!.rootMid;
        } else {
          wkReply.rootMid = wkReply.messageId;
        }

        // Assign reply to text content
        textContent.reply = wkReply;

        Logger.service(
          'ChatProvider',
          'Created reply object: ${wkReply.messageId} -> ${wkReply.rootMid}',
        );
      } else {
        Logger.warning(
          'ChatProvider: Original message not found for reply: ${replyMessage.messageId}',
        );
      }

      // Create channel
      final channel = WKChannel(_channelId, _channelType);

      // Send message - this will trigger the message insert listener
      WKIM.shared.messageManager.sendMessage(textContent, channel);
      Logger.service(
        'ChatProvider',
        'Reply message sent to SDK - will track status updates',
      );

      // Message will be added to the UI via the message insert listener
      // Status updates will be handled by addOnRefreshMsgListener
    } catch (e) {
      Logger.error('Failed to send reply message', error: e);
      _error = 'Failed to send reply message: ${e.toString()}';
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Send image message
  Future<void> sendImageMessage(String localPath, int width, int height) async {
    if (_isSendingMessage) return;

    try {
      _isSendingMessage = true;
      notifyListeners();

      Logger.service('ChatProvider', 'Sending image message');

      // Create image content
      final imageContent = WKImageContent(width, height);
      imageContent.localPath = localPath;

      // Create channel
      final channel = WKChannel(_channelId, _channelType);

      // Send message
      WKIM.shared.messageManager.sendMessage(imageContent, channel);
      Logger.service('ChatProvider', 'Image message sent successfully');

      _isSendingMessage = false;
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to send image', error: e);
      _error = 'Failed to send image: ${e.toString()}';
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Send voice message
  Future<void> sendVoiceMessage(String localPath, int duration) async {
    if (_isSendingMessage) return;

    try {
      _isSendingMessage = true;
      notifyListeners();

      Logger.service('ChatProvider', 'Sending voice message');

      // Create voice content
      final voiceContent = WKVoiceContent(duration);
      voiceContent.localPath = localPath;

      // Create channel
      final channel = WKChannel(_channelId, _channelType);

      // Send message
      WKIM.shared.messageManager.sendMessage(voiceContent, channel);
      Logger.service('ChatProvider', 'Voice message sent successfully');

      _isSendingMessage = false;
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to send voice', error: e);
      _error = 'Failed to send voice: ${e.toString()}';
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Send card message (contact card like Android)
  Future<void> sendCardMessage({
    required String uid,
    required String name,
    String? vercode,
  }) async {
    if (_isSendingMessage) return;
    try {
      _isSendingMessage = true;
      notifyListeners();
      Logger.service('ChatProvider', 'Sending card message for $name ($uid)');

      // Build WKCardContent similar to Android
      final card = WKCardContent(uid, name);
      card.vercode = vercode;

      // Create channel and send
      final channel = WKChannel(_channelId, _channelType);
      WKIM.shared.messageManager.sendMessage(card, channel);

      _isSendingMessage = false;
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to send card', error: e);
      _error = 'Failed to send card: ${e.toString()}';
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Clear messages when leaving chat
  void clearMessages() {
    _messages = [];
    _hasMoreMessages = true;
    _clearTyping(); // Clear typing when leaving chat

    // Cancel message delay timer and clear pending messages
    _messageDelayTimer?.cancel();
    _messageDelayTimer = null;
    _pendingMessages.clear();
    _isDelayingMessages = false;

    notifyListeners();
  }

  /// Reset cached data (call when user changes)
  void resetCache() {
    _cachedCurrentUserUid = null;
    _clearTyping();
  }

  /// Clear error
  void clearError() {
    _error = '';
    notifyListeners();
  }

  /// Handle text input changes - send typing status
  void handleTextChanged(String text) {
    if (text.isEmpty) {
      _sendTypingTimer?.cancel();
      return;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Send typing status if cooldown period has passed
    if (currentTime - _lastTypingTime >= _typingCooldownSeconds) {
      _sendTypingStatusIfAllowed(currentTime);
    }
  }

  /// Send typing status if user has permission
  void _sendTypingStatusIfAllowed(int currentTime) {
    if (!_canSendTypingStatus()) {
      Logger.service(
        'ChatProvider',
        'Cannot send typing status - user blocked or invalid channel',
      );
      return;
    }

    Logger.service(
      'ChatProvider',
      'Sending typing status for channel: $_channelId',
    );
    _msgService.sendTyping(_channelId, _channelType);
    _lastTypingTime = currentTime;
  }

  /// Check if user can send typing status
  bool _canSendTypingStatus() {
    // For groups, should check if user is a member (simplified for now)
    if (_channelType == WKChannelType.group) {
      return true; // TODO: Add proper member check
    }

    // For personal chats, check if not blocked/deleted
    if (_currentChannel?.localExtra == null) return true;

    final beDeleted = _currentChannel?.localExtra['be_deleted'] ?? 0;
    final beBlacklist = _currentChannel?.localExtra['be_blacklist'] ?? 0;

    return beDeleted != 1 && beBlacklist != 1;
  }

  /// Process pending messages after typing delay
  void _processPendingMessages() {
    if (_pendingMessages.isNotEmpty) {
      Logger.service(
        'ChatProvider',
        'Processing ${_pendingMessages.length} pending messages after typing delay',
      );

      // Add pending messages to the main list
      _messages.insertAll(0, _pendingMessages);
      _pendingMessages.clear();
    }

    // Auto-mark as read only if chat is foreground
    try {
      if (_isChatForeground && _channelId.isNotEmpty) {
        WKIM.shared.conversationManager.updateRedDot(
          _channelId,
          _channelType,
          0,
        );
      }
    } catch (_) {}

    // Reset delay state
    _isDelayingMessages = false;
    _messageDelayTimer = null;

    // Notify listeners to update UI
    notifyListeners();
  }

  /// Notify external listeners (like ChatController) about message status updates
  void _notifyMessageStatusUpdate(WKMsg wkMsg) {
    // This method can be used to notify ChatController or other components
    // about message status changes for real-time UI updates
    Logger.service(
      'ChatProvider',
      'Notifying message status update for ${wkMsg.clientMsgNO}: status=${wkMsg.status}',
    );

    // The actual ChatController update will be handled by the ChatScreen
    // through the existing listener mechanism in _processNewMessages
  }

  /// Clear all data and reset state (called on logout)
  void clear() {
    Logger.service('ChatProvider', 'Clearing all chat data...');

    // Clear active chat status
    try {
      final nav = NavigationService.navigatorKey.currentState;
      if (nav != null) {
        final context = nav.context;
        final conversationProvider = Provider.of<ConversationProvider>(
          context,
          listen: false,
        );
        conversationProvider.clearActiveChat();
      }
    } catch (e) {
      Logger.error('Failed to clear active chat status', error: e);
    }

    // Clear channel info
    _channelId = '';
    _channelType = WKChannelType.personal;
    _currentChannel = null;

    // Clear messages
    _messages = [];
    _pendingMessages.clear();
    _isLoading = false;
    _isSendingMessage = false;
    _error = '';

    // Clear typing state
    _isTyping = false;
    _typingUserName = '';
    _typingUserId = '';
    _typingTimer?.cancel();
    _typingTimer = null;

    // Clear pagination state
    _hasMoreMessages = true;
    _isLoadingMore = false;

    // Clear typing timers
    _sendTypingTimer?.cancel();
    _sendTypingTimer = null;
    _lastTypingTime = 0;

    // Clear message delay timer
    _messageDelayTimer?.cancel();
    _messageDelayTimer = null;
    _isDelayingMessages = false;

    // Clear cached values
    _cachedCurrentUserUid = null;

    // Remove listeners
    WKIM.shared.messageManager.removeNewMsgListener('chat_provider');
    WKIM.shared.messageManager.removeOnRefreshMsgListener('chat_provider');
    WKIM.shared.channelManager.removeOnRefreshListener('chat_provider');
    WKIM.shared.cmdManager.removeCmdListener('chat_provider');

    notifyListeners();

    Logger.service('ChatProvider', 'Clear completed');
  }

  /// Dispose and cleanup
  @override
  void dispose() {
    Logger.service('ChatProvider', 'Disposing chat provider');

    // Cancel typing timer
    _typingTimer?.cancel();
    _sendTypingTimer?.cancel();

    // Cancel message delay timer and clear pending messages
    _messageDelayTimer?.cancel();
    _pendingMessages.clear();

    // Remove listeners
    WKIM.shared.messageManager.removeNewMsgListener('chat_provider');
    WKIM.shared.messageManager.removeOnRefreshMsgListener('chat_provider');
    WKIM.shared.channelManager.removeOnRefreshListener('chat_provider');
    WKIM.shared.cmdManager.removeCmdListener('chat_provider');

    super.dispose();
  }
}
