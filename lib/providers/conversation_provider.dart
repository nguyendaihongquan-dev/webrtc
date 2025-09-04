import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../services/wukong_service.dart';
import '../services/notification_service.dart';
import '../models/conversation_model.dart';
import '../models/conversation_update_flags.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';

class ConversationProvider extends ChangeNotifier {
  final WuKongService _wuKongService = WuKongService();

  List<UIConversation> _conversations = [];
  bool _isLoading = false;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  String _error = '';
  int _totalUnreadCount = 0;
  bool _isInitialized = false;
  bool _isSyncingConversations = false;
  bool _isRefreshingChannelInfo = false;

  // Reference to LoginProvider for accessing user settings
  LoginProvider? _loginProvider;

  // Track current active chat to avoid notifications for it
  String _currentActiveChannelId = '';
  int _currentActiveChannelType = 0;
  bool _isChatScreenForeground = false;

  ConversationProvider() {
    developer.log(
      'Constructor called, _isInitialized: $_isInitialized',
      name: 'ConversationProvider',
    );
  }

  /// Set LoginProvider reference for accessing user settings
  void setLoginProvider(LoginProvider loginProvider) {
    _loginProvider = loginProvider;
  }

  /// Set current active chat info to avoid notifications for it
  void setActiveChat(String channelId, int channelType, bool isForeground) {
    _currentActiveChannelId = channelId;
    _currentActiveChannelType = channelType;
    _isChatScreenForeground = isForeground;
    developer.log(
      'ConversationProvider: Active chat set to $channelId/$channelType, foreground: $isForeground',
      name: 'ConversationProvider',
    );
  }

  /// Clear active chat info
  void clearActiveChat() {
    _currentActiveChannelId = '';
    _currentActiveChannelType = 0;
    _isChatScreenForeground = false;
    developer.log(
      'ConversationProvider: Active chat cleared',
      name: 'ConversationProvider',
    );
  }

  // Getters
  List<UIConversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  bool get isSyncingConversations => _isSyncingConversations;
  bool get isRefreshingChannelInfo => _isRefreshingChannelInfo;
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;
  String get error => _error;
  int get totalUnreadCount => _totalUnreadCount;

  /// Initialize WuKongIM and connect
  Future<bool> initialize() async {
    developer.log(
      'initialize() called, _isInitialized: $_isInitialized',
      name: 'ConversationProvider',
    );

    if (_isInitialized) {
      developer.log('Already initialized', name: 'ConversationProvider');
      return true;
    }

    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      developer.log('Initializing WuKongIM...', name: 'ConversationProvider');

      // Initialize WuKongIM SDK
      developer.log(
        'Calling WuKongService.initialize()',
        name: 'ConversationProvider',
      );
      final initSuccess = await _wuKongService.initialize();
      developer.log(
        'WuKongService.initialize() result: $initSuccess',
        name: 'ConversationProvider',
      );
      if (!initSuccess) {
        _error = 'Failed to initialize WuKongIM SDK';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Set up listeners before connecting
      developer.log('Setting up listeners...', name: 'ConversationProvider');
      _setupListeners();

      // Set up conversation sync completion callback
      _wuKongService.setOnConversationSyncCompleted(() async {
        developer.log(
          'Conversation sync completed, reloading...',
          name: 'ConversationProvider',
        );
        _isSyncingConversations = false;
        await _loadConversations();
        notifyListeners();
      });

      // Connect to server
      developer.log('Connecting to server...', name: 'ConversationProvider');
      final connectSuccess = await _wuKongService.connect();
      developer.log(
        'Connect result: $connectSuccess',
        name: 'ConversationProvider',
      );
      if (!connectSuccess) {
        _error = 'Failed to connect to WuKongIM server';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Load initial conversations from local while waiting for server sync
      developer.log('Loading conversations...', name: 'ConversationProvider');
      _isSyncingConversations = true;
      await _loadConversations();

      // Force refresh all channel info to get latest data from server
      developer.log(
        'Force refreshing channel info...',
        name: 'ConversationProvider',
      );
      await forceRefreshAllChannelInfo();

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      developer.log(
        'Initialization completed successfully',
        name: 'ConversationProvider',
      );
      return true;
    } catch (e) {
      developer.log('Initialization failed: $e', name: 'ConversationProvider');
      _error = 'Initialization failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mark a conversation as read (clear unread/red dot) and update UI
  Future<void> markConversationAsRead(String channelId, int channelType) async {
    try {
      // Clear unread red dot in SDK (mirrors Android behavior)
      await WKIM.shared.conversationManager.updateRedDot(
        channelId,
        channelType,
        0,
      );
    } catch (_) {
      // Ignore SDK errors; still proceed to update UI state locally
    }

    // Update local conversation model immediately for responsive UI
    for (final conv in _conversations) {
      if (conv.msg.channelID == channelId &&
          conv.msg.channelType == channelType) {
        conv.msg.unreadCount = 0;
        conv.updateFlags = ConversationUpdateFlags.unreadCountOnly();
        break;
      }
    }

    // Recompute total unread and notify listeners
    _calculateTotalUnreadCount();
    notifyListeners();
  }

  /// Load conversations from WuKongIM
  Future<void> _loadConversations() async {
    try {
      developer.log(
        'ConversationProvider: Loading conversations...',
        name: 'ConversationProvider',
      );

      final wkConversations = await _wuKongService.getAllConversations();
      if (wkConversations.isEmpty && _isSyncingConversations) {
        // Still syncing from server; skip clearing to avoid flicker of empty state
        developer.log(
          'ConversationProvider: Data empty but syncing in progress - keep current UI state',
          name: 'ConversationProvider',
        );
        return;
      }

      developer.log(
        'ConversationProvider: Loaded ${wkConversations.length} conversations',
        name: 'ConversationProvider',
      );

      // Convert to UI conversations and preserve previously known UI fields
      final Map<String, UIConversation> previousByKey = {
        for (final conv in _conversations)
          '${conv.msg.channelID}_${conv.msg.channelType}': conv,
      };

      final uiConversations = <UIConversation>[];
      final List<Future<void>> channelHydrationFutures = [];

      for (final wkConv in wkConversations) {
        final uiConv = UIConversation(wkConv);
        final key = '${wkConv.channelID}_${wkConv.channelType}';

        // Preserve prior UI data if available to avoid flicker
        final previous = previousByKey[key];
        if (previous != null) {
          uiConv.channelName = previous.channelName;
          uiConv.channelAvatar = previous.channelAvatar;
          uiConv.lastContent = previous.lastContent;
          uiConv.top = previous.top;
          uiConv.mute = previous.mute;
        }

        // If UI data still missing, hydrate from SDK channel cache
        if (uiConv.channelName.isEmpty || uiConv.channelAvatar.isEmpty) {
          channelHydrationFutures.add(
            uiConv.msg
                .getWkChannel()
                .then((channel) {
                  if (channel != null) {
                    if (uiConv.channelName.isEmpty) {
                      uiConv.channelName = channel.channelRemark.isNotEmpty
                          ? channel.channelRemark
                          : channel.channelName;
                    }
                    if (uiConv.channelAvatar.isEmpty) {
                      final avatarPath = channel.avatar;
                      if (avatarPath.isNotEmpty) {
                        uiConv.channelAvatar = ConversationUtils.getAvatarUrl(
                          avatarPath,
                          WKApiConfig.baseUrl,
                        );
                      } else {
                        // Fallback to server computed avatar endpoint by channel type
                        if (wkConv.channelType == 2) {
                          uiConv.channelAvatar = WKApiConfig.getGroupUrl(
                            wkConv.channelID,
                          );
                        } else {
                          uiConv.channelAvatar = WKApiConfig.getAvatarUrl(
                            wkConv.channelID,
                          );
                        }
                      }
                    }
                    // Mirror other settings as well
                    uiConv.top = channel.top;
                    uiConv.mute = channel.mute;
                  }
                })
                .catchError((_) {}),
          );
        }

        uiConversations.add(uiConv);
      }

      // Wait for channel hydration to reduce placeholder flashes
      if (channelHydrationFutures.isNotEmpty) {
        await Future.wait(channelHydrationFutures);
      }

      // Sort conversations
      _conversations = ConversationUtils.sortConversations(uiConversations);

      // Calculate total unread count
      _calculateTotalUnreadCount();

      developer.log(
        'ConversationProvider: Converted ${_conversations.length} conversations',
        name: 'ConversationProvider',
      );

      notifyListeners();
    } catch (e) {
      developer.log(
        'ConversationProvider: Load conversations failed: $e',
        name: 'ConversationProvider',
      );
      _error = 'Failed to load conversations: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Set up WuKongIM listeners
  void _setupListeners() {
    developer.log(
      'ConversationProvider: Setting up listeners...',
      name: 'ConversationProvider',
    );

    // Listen for conversation updates
    _wuKongService.addConversationRefreshListener('conversation_provider', (
      conversations,
    ) {
      developer.log(
        'ConversationProvider: Received conversation updates: ${conversations.length}',
        name: 'ConversationProvider',
      );
      _handleConversationUpdates(conversations);
    });

    // Listen for channel updates
    _wuKongService.addChannelRefreshListener('conversation_provider', (
      channel,
    ) {
      developer.log(
        'ConversationProvider: Received channel update: ${channel.channelID}',
        name: 'ConversationProvider',
      );
      _handleChannelUpdate(channel);
    });

    // Listen for message updates (for selective preview updates)
    _wuKongService.addMessageRefreshListener('conversation_provider', (
      message,
    ) {
      developer.log(
        'ConversationProvider: Received message update: ${message.channelID}',
        name: 'ConversationProvider',
      );
      _handleMessageUpdate(message);
    });

    // Global notification listener for ALL new messages
    WKIM.shared.messageManager.addOnNewMsgListener('global_notifications', (
      messages,
    ) {
      developer.log(
        'ConversationProvider: Global notification listener received ${messages.length} messages',
        name: 'ConversationProvider',
      );
      // Print raw message JSON to help debug mention payloads
      for (final m in messages) {
        try {
          developer.log(
            '❤️ConversationProvider: RAW incoming message JSON: ${m.content}',
            name: 'ConversationProvider',
          );
        } catch (_) {}
      }
      _handleGlobalNotifications(messages);
    });
  }

  /// Handle global notifications for all new messages
  void _handleGlobalNotifications(List<WKMsg> messages) async {
    if (_loginProvider == null) return;

    // Get current user settings for notifications
    final settings = _loginProvider!.currentUser?.setting;
    final bool allowNotifications = (settings?.newMsgNotice ?? 1) == 1;
    final bool showDetail = (settings?.msgShowDetail ?? 1) == 1;
    final bool playSound = (settings?.voiceOn ?? 1) == 1;
    final bool vibrate = (settings?.shockOn ?? 1) == 1;
    final currentUid = _loginProvider!.currentUser?.uid ?? '';

    if (!allowNotifications) return;

    // Check system notification permissions
    final hasPermission = await NotificationService.instance
        .areNotificationsEnabled();
    if (!hasPermission) {
      developer.log(
        'ConversationProvider: System notifications are disabled',
        name: 'ConversationProvider',
      );
      return;
    }

    // Process each message asynchronously to avoid blocking
    for (final msg in messages) {
      _processMessageNotification(
        msg,
        currentUid,
        showDetail,
        playSound,
        vibrate,
      );
    }
  }

  /// Process individual message notification
  void _processMessageNotification(
    WKMsg msg,
    String currentUid,
    bool showDetail,
    bool playSound,
    bool vibrate,
  ) async {
    // Skip messages from self
    if (msg.fromUID == currentUid) return;

    // Skip typing messages and system messages
    if (msg.contentType == 99 || msg.contentType < 0) return;

    // Skip notification if user is currently in this chat and screen is foreground
    if (_isChatScreenForeground &&
        msg.channelID == _currentActiveChannelId &&
        msg.channelType == _currentActiveChannelType) {
      developer.log(
        'ConversationProvider: Skipping notification for active chat ${msg.channelID}',
        name: 'ConversationProvider',
      );
      return;
    }

    // Get channel info to check mute status and get display name
    WKChannel? channel;
    try {
      channel = await WKIM.shared.channelManager.getChannel(
        msg.channelID,
        msg.channelType,
      );
    } catch (_) {
      // If we can't get channel info, proceed with notification
    }

    // Check if this conversation is muted
    if (channel?.mute == 1) {
      developer.log(
        'ConversationProvider: Skipping notification for muted conversation ${msg.channelID}',
        name: 'ConversationProvider',
      );
      return;
    }

    developer.log(
      'ConversationProvider: Showing notification for message from ${msg.fromUID} in ${msg.channelID}',
      name: 'ConversationProvider',
    );

    // Get display name based on channel type
    String displayName;
    if (msg.channelType == WKChannelType.group) {
      // For group messages, use group name from channel
      displayName = channel?.channelName.isNotEmpty == true
          ? channel!.channelName
          : 'Group Chat';
    } else {
      // For personal messages, show sender name
      displayName = msg.getFrom()?.channelName.isNotEmpty == true
          ? msg.getFrom()!.channelName
          : msg.fromUID;
    }

    // Get message text
    final text = () {
      try {
        return msg.messageContent?.displayText() ?? '';
      } catch (_) {
        return '';
      }
    }();

    // Show notification
    NotificationService.instance.showNewMessageNotification(
      conversationId: msg.channelID,
      senderName: displayName,
      messageText: text.isNotEmpty ? text : 'New message',
      showDetail: showDetail,
      playSound: playSound,
      vibrate: vibrate,
    );
  }

  /// Handle conversation updates from WuKongIM with selective updates
  void _handleConversationUpdates(
    List<WKUIConversationMsg> updatedConversations,
  ) {
    try {
      if (updatedConversations.isEmpty) return;

      final updatedUIConversations = <UIConversation>[];
      bool hasChanges = false;

      for (final updatedConv in updatedConversations) {
        bool isUpdated = false;

        // Find existing conversation and selectively update it
        for (int i = 0; i < _conversations.length; i++) {
          final existingConv = _conversations[i];

          if (existingConv.msg.channelID == updatedConv.channelID &&
              existingConv.msg.channelType == updatedConv.channelType) {
            // Determine what needs to be updated
            final updateFlags = _determineUpdateFlags(
              existingConv.msg,
              updatedConv,
            );

            if (updateFlags.hasUpdates) {
              // Apply selective updates
              _applySelectiveUpdates(existingConv, updatedConv, updateFlags);
              hasChanges = true;
            }

            isUpdated = true;
            break;
          }
        }

        // If not found, add as new conversation
        if (!isUpdated) {
          final newConv = UIConversation(updatedConv);
          // Mark all flags for new conversation
          newConv.updateFlags = ConversationUpdateFlags.newMessage();
          updatedUIConversations.add(newConv);
          hasChanges = true;
        }
      }

      // Add new conversations
      if (updatedUIConversations.isNotEmpty) {
        _conversations.addAll(updatedUIConversations);
      }

      // Only sort and notify if there were actual changes
      if (hasChanges) {
        // Sort conversations
        _conversations = ConversationUtils.sortConversations(_conversations);

        // Calculate total unread count
        _calculateTotalUnreadCount();

        notifyListeners();

        developer.log(
          'ConversationProvider: Applied selective updates for ${updatedConversations.length} conversations',
          name: 'ConversationProvider',
        );
      }
    } catch (e) {
      developer.log(
        'ConversationProvider: Handle conversation updates failed: $e',
        name: 'ConversationProvider',
      );
    }
  }

  /// Determine which update flags should be set based on changes
  ConversationUpdateFlags _determineUpdateFlags(
    WKUIConversationMsg oldMsg,
    WKUIConversationMsg newMsg,
  ) {
    final flags = ConversationUpdateFlags();

    // Check if message content changed (new message)
    if (oldMsg.lastMsgTimestamp != newMsg.lastMsgTimestamp) {
      flags.isResetContent = true;
      flags.isResetTime = true;
    }

    // Check if unread count changed
    if (oldMsg.unreadCount != newMsg.unreadCount) {
      flags.isResetCounter = true;
    }

    return flags;
  }

  /// Apply selective updates to existing conversation
  void _applySelectiveUpdates(
    UIConversation existingConv,
    WKUIConversationMsg newMsg,
    ConversationUpdateFlags updateFlags,
  ) {
    // Update the message data
    existingConv.msg = newMsg;

    // Set update flags for UI to respond to
    existingConv.updateFlags = updateFlags;

    // Reset cached content if content needs refresh
    if (updateFlags.isResetContent) {
      existingConv.lastContent = '';
    }

    // Note: reminders update removed due to API compatibility
  }

  /// Handle message updates for selective preview updates
  void _handleMessageUpdate(WKMsg message) {
    try {
      bool updated = false;

      for (int i = 0; i < _conversations.length; i++) {
        if (_conversations[i].msg.channelID == message.channelID &&
            _conversations[i].msg.channelType == message.channelType) {
          // Only update if this is a newer message
          if (message.timestamp > _conversations[i].msg.lastMsgTimestamp) {
            // Set flags for new message (includes full refresh to move item to top)
            final updateFlags = ConversationUpdateFlags.newMessage();

            // Update conversation with new message info
            _conversations[i].msg.lastMsgTimestamp = message.timestamp;
            _conversations[i].lastContent = ''; // Reset to trigger reload
            _conversations[i].updateFlags = updateFlags;

            updated = true;

            developer.log(
              'ConversationProvider: Updated message preview for ${message.channelID}',
              name: 'ConversationProvider',
            );
            break;
          }
        }
      }

      if (updated) {
        // Re-sort conversations to bring updated one to top
        _conversations = ConversationUtils.sortConversations(_conversations);
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        'ConversationProvider: Handle message update failed: $e',
        name: 'ConversationProvider',
      );
    }
  }

  /// Handle channel updates from WuKongIM
  void _handleChannelUpdate(WKChannel channel) {
    try {
      bool updated = false;

      for (int i = 0; i < _conversations.length; i++) {
        if (_conversations[i].msg.channelID == channel.channelID &&
            _conversations[i].msg.channelType == channel.channelType) {
          // Set channel info update flag
          _conversations[i].updateFlags.isRefreshChannelInfo = true;

          _conversations[i].msg.setWkChannel(channel);
          _conversations[i].channelAvatar = ConversationUtils.getAvatarUrl(
            channel.avatar,
            WKApiConfig.baseUrl,
          );
          _conversations[i].channelName = channel.channelRemark.isNotEmpty
              ? channel.channelRemark
              : channel.channelName;
          _conversations[i].top = channel.top;
          _conversations[i].mute = channel.mute;
          updated = true;
          break;
        }
      }

      if (updated) {
        // Re-sort conversations in case top status changed
        _conversations = ConversationUtils.sortConversations(_conversations);
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        'ConversationProvider: Handle channel update failed: $e',
        name: 'ConversationProvider',
      );
    }
  }

  /// Calculate total unread count
  void _calculateTotalUnreadCount() {
    _totalUnreadCount = 0;
    for (final conversation in _conversations) {
      if (!conversation.isMuted) {
        _totalUnreadCount += conversation.msg.unreadCount;
      }
    }
  }

  /// Refresh conversations and force refresh all channel info
  Future<void> refreshConversations() async {
    await _loadConversations();
    // Also force refresh all channel info to get latest data from server
    await forceRefreshAllChannelInfo();
  }

  /// Refresh conversations quietly without showing loading indicators
  /// This is used for background/periodic refreshes
  Future<void> refreshConversationsQuietly() async {
    try {
      await _loadConversations();
      // Also force refresh all channel info to get latest data from server
      // but without setting the _isRefreshingChannelInfo flag
      await _forceRefreshAllChannelInfoQuietly();
    } catch (e) {
      developer.log(
        'ConversationProvider: Error during quiet refresh: $e',
        name: 'ConversationProvider',
      );
      // Don't set error state for background refreshes
    }
  }

  /// Force refresh all channel information from server
  Future<void> forceRefreshAllChannelInfo() async {
    if (_conversations.isEmpty) return;

    _isRefreshingChannelInfo = true;
    notifyListeners();

    developer.log(
      'ConversationProvider: Force refreshing channel info for ${_conversations.length} conversations',
      name: 'ConversationProvider',
    );

    final List<Future<void>> refreshFutures = [];

    for (final conversation in _conversations) {
      final channelId = conversation.msg.channelID;
      final channelType = conversation.msg.channelType;

      // Create future for refreshing this channel's info
      final refreshFuture = _wuKongService.channelInfoManager
          .forceRefreshChannelInfo(channelId, channelType)
          .then((channel) {
            if (channel != null) {
              // Update conversation with fresh channel info
              conversation.channelName = channel.channelRemark.isNotEmpty
                  ? channel.channelRemark
                  : channel.channelName;

              final avatarPath = channel.avatar;
              if (avatarPath.isNotEmpty) {
                conversation.channelAvatar = ConversationUtils.getAvatarUrl(
                  avatarPath,
                  WKApiConfig.baseUrl,
                );
              } else {
                // Fallback to server computed avatar endpoint by channel type
                if (channelType == 2) {
                  conversation.channelAvatar = WKApiConfig.getGroupUrl(
                    channelId,
                  );
                } else {
                  conversation.channelAvatar = WKApiConfig.getAvatarUrl(
                    channelId,
                  );
                }
              }

              conversation.top = channel.top;
              conversation.mute = channel.mute;

              // Mark as channel info updated
              conversation.updateFlags.isRefreshChannelInfo = true;
            }
          })
          .catchError((e) {
            developer.log(
              'ConversationProvider: Failed to refresh channel info for $channelId: $e',
              name: 'ConversationProvider',
            );
          });

      refreshFutures.add(refreshFuture);
    }

    // Wait for all channel info refreshes to complete
    await Future.wait(refreshFutures);

    // Re-sort conversations in case top status changed
    _conversations = ConversationUtils.sortConversations(_conversations);

    _isRefreshingChannelInfo = false;

    developer.log(
      'ConversationProvider: Completed force refresh of all channel info',
      name: 'ConversationProvider',
    );

    notifyListeners();
  }

  /// Force refresh all channel information from server quietly (without UI indicators)
  /// This is used for background/periodic refreshes
  Future<void> _forceRefreshAllChannelInfoQuietly() async {
    if (_conversations.isEmpty) return;

    // Don't set _isRefreshingChannelInfo to avoid showing loading indicators

    developer.log(
      'ConversationProvider: Quietly force refreshing channel info for ${_conversations.length} conversations',
      name: 'ConversationProvider',
    );

    final List<Future<void>> refreshFutures = [];

    for (final conversation in _conversations) {
      final channelId = conversation.msg.channelID;
      final channelType = conversation.msg.channelType;

      // Create future for refreshing this channel's info
      final refreshFuture = _wuKongService.channelInfoManager
          .forceRefreshChannelInfo(channelId, channelType)
          .then((channel) {
            if (channel != null) {
              // Update conversation with fresh channel info
              conversation.channelName = channel.channelRemark.isNotEmpty
                  ? channel.channelRemark
                  : channel.channelName;

              final avatarPath = channel.avatar;
              if (avatarPath.isNotEmpty) {
                conversation.channelAvatar = ConversationUtils.getAvatarUrl(
                  avatarPath,
                  WKApiConfig.baseUrl,
                );
              } else {
                // Fallback to server computed avatar endpoint by channel type
                if (channelType == 2) {
                  conversation.channelAvatar = WKApiConfig.getGroupUrl(
                    channelId,
                  );
                } else {
                  conversation.channelAvatar = WKApiConfig.getAvatarUrl(
                    channelId,
                  );
                }
              }

              conversation.top = channel.top;
              conversation.mute = channel.mute;

              // Mark as channel info updated
              conversation.updateFlags.isRefreshChannelInfo = true;
            }
          })
          .catchError((e) {
            developer.log(
              'ConversationProvider: Failed to quietly refresh channel info for $channelId: $e',
              name: 'ConversationProvider',
            );
          });

      refreshFutures.add(refreshFuture);
    }

    // Wait for all channel info refreshes to complete
    await Future.wait(refreshFutures);

    // Re-sort conversations in case top status changed
    _conversations = ConversationUtils.sortConversations(_conversations);

    developer.log(
      'ConversationProvider: Completed quiet force refresh of all channel info',
      name: 'ConversationProvider',
    );

    // Still notify listeners to update UI with fresh data, but without loading indicators
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = '';
    notifyListeners();
  }

  /// Clear all data and reset state (called on logout)
  void clear() {
    developer.log(
      'ConversationProvider: Clearing all data...',
      name: 'ConversationProvider',
    );

    // Clear all conversation data
    _conversations = [];
    _totalUnreadCount = 0;
    _error = '';

    // Reset connection state
    _isConnected = false;
    _connectionStatus = 'Disconnected';

    // Remove listeners before resetting
    _wuKongService.removeConversationRefreshListener('conversation_provider');
    _wuKongService.removeChannelRefreshListener('conversation_provider');
    _wuKongService.removeMessageRefreshListener('conversation_provider');

    // Reset initialization flag to allow reinitialize on next login
    _isInitialized = false;
    _isLoading = false;

    // Dispose WuKongIM service
    _wuKongService.dispose();

    notifyListeners();

    developer.log(
      'ConversationProvider: Clear completed',
      name: 'ConversationProvider',
    );
  }

  /// Dispose resources
  @override
  void dispose() {
    developer.log(
      'ConversationProvider: Disposing...',
      name: 'ConversationProvider',
    );

    // Remove listeners
    _wuKongService.removeConversationRefreshListener('conversation_provider');
    _wuKongService.removeChannelRefreshListener('conversation_provider');
    _wuKongService.removeMessageRefreshListener('conversation_provider');

    // Dispose WuKongIM service
    _wuKongService.dispose();

    super.dispose();
  }
}
