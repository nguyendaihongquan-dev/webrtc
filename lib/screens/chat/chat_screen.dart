// ignore_for_file: unused_element

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/selection_provider.dart';
import 'package:qgim_client_flutter/widgets/chatview/chatview.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/model/wk_card_content.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../models/wk_mention_text_content.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/system_message_formatter.dart';
import '../../services/group_service.dart';
import '../../services/channel_info_manager.dart';
import '../../utils/logger.dart';
import '../../config/constants.dart';
import '../../models/conversation_model.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/video_call/video_call_button.dart';
import '../../models/video_call_model.dart';
import '../../config/routes.dart';

class ChatScreen extends StatefulWidget {
  final String channelId;
  final int channelType;
  final int
  initialAroundOrderSeq; // Android parity: unreadStartMsgOrderSeq/tips/lastPreview
  final String? imagePath; // Optional image to send immediately
  const ChatScreen({
    super.key,
    required this.channelId,
    this.channelType = WKChannelType.personal,
    this.initialAroundOrderSeq = 0,
    this.imagePath,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatProvider _chatProvider;
  late ChatController _chatController;
  late String _currentUserId;
  final Set<String> _processedMessageIds = {};
  String? _lastChannelName;
  bool _isInitialized = false;
  bool _isLoadingUserNames = false;
  final ValueNotifier<int> _messageCountNotifier = ValueNotifier(0);
  int? _memberCount;
  // Selection state (Android parity: multipleChoiceView)
  bool _selectionMode = false;
  // Move selected ids to ChangeNotifier to avoid rebuilding whole screen
  late SelectedIds _selectedIds;
  // Chat permissions and UI state (mirror Android: ban/forbidden)
  WKChannel? _channel;
  WKChannelMember? _selfMember;
  bool _isBan = false; // group banned
  bool _isForbidden = false; // cannot send due to global/members mute
  // epoch seconds for member mute end
  Timer? _forbiddenTimer;
  String _forbiddenText = '禁言中';

  bool get _isInputEnabled => !_isBan && !_isForbidden;

  @override
  void initState() {
    super.initState();
    _selectedIds = SelectedIds();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // Mark chat as foreground (visible) to control auto-read behavior
    _chatProvider.setChatForeground(true);

    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    _currentUserId = loginProvider.currentUser?.uid ?? 'unknown';

    Logger.debug('ChatScreen initState - currentUserId: $_currentUserId');

    // Initialize chat users
    final currentUser = ChatUser(
      id: _currentUserId,
      name: loginProvider.currentUser?.name ?? 'Current User',
      profilePhoto: _getCurrentUserAvatarUrl(loginProvider),
    );

    // Initialize ChatController
    _chatController = ChatController(
      initialMessageList: [],
      scrollController: ScrollController(),
      currentUser: currentUser,
      otherUsers: [], // Will be populated when messages are loaded
    );

    // Initialize chat after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _setupPermissionListeners();
      await _loadInitialPermissions();
      // Force a fresh channel info fetch to populate status/forbidden from API
      await ChannelInfoManager().fetchChannelInfo(
        widget.channelId,
        widget.channelType,
      );
      _initializeChat();
      _setupMessageStatusListener();
      _setupClearChannelListener();
      _fetchGroupMemberCount();
    });
  }

  @override
  void dispose() {
    // Mark chat as background (not visible) to stop auto-read on new messages
    try {
      _chatProvider.setChatForeground(false);
    } catch (_) {}
    // Remove the direct message status listener using same key pattern
    final listenerKey = 'chat_screen_${widget.channelId}';
    WKIM.shared.messageManager.removeOnRefreshMsgListener(listenerKey);

    WKIM.shared.messageManager.removeClearChannelMsgListener(
      'chat_screen_clear_${widget.channelId}',
    );
    WKIM.shared.channelManager.removeOnRefreshListener(
      'chat_screen_perm_${widget.channelId}',
    );
    WKIM.shared.channelMemberManager.removeRefreshMemberListener(
      'chat_screen_perm_${widget.channelId}',
    );
    _stopForbiddenTimer();
    Logger.debug('ChatScreen: Removed WuKongIM listener: $listenerKey');

    _chatController.dispose();
    _processedMessageIds.clear();
    _messageCountNotifier.dispose();
    super.dispose();
  }

  void _setupPermissionListeners() {
    // Channel refresh listener
    WKIM.shared.channelManager.addOnRefreshListener(
      'chat_screen_perm_${widget.channelId}',
      (channel) {
        if (channel.channelID == widget.channelId &&
            channel.channelType == widget.channelType) {
          _channel = channel;
          _refreshPermissions();
        }
      },
    );

    // Member refresh listener (updates may come in batches)
    WKIM.shared.channelMemberManager.addOnRefreshMemberListener(
      'chat_screen_perm_${widget.channelId}',
      (member, isEnd) {
        if (member.channelID == widget.channelId &&
            member.channelType == widget.channelType &&
            member.memberUID == _currentUserId) {
          _selfMember = member;
          _refreshPermissions();
        }
      },
    );
  }

  Future<void> _loadInitialPermissions() async {
    try {
      _channel = await WKIM.shared.channelManager.getChannel(
        widget.channelId,
        widget.channelType,
      );
      if (widget.channelType == WKChannelType.group) {
        _selfMember = await WKIM.shared.channelMemberManager.getMember(
          widget.channelId,
          widget.channelType,
          _currentUserId,
        );
      } else {
        _selfMember = null;
      }
    } catch (e) {
      Logger.warning('Failed to load initial permissions: $e');
    }
    _refreshPermissions();
  }

  void _refreshPermissions() {
    bool ban = false;
    bool forbidden = false;
    int expiration = 0;
    String hint = '禁言中';

    final ch = _channel;
    final me = _selfMember;

    if (ch != null) {
      // Treat non-normal status as banned (e.g., status = 2 blacklist/disabled)
      if (ch.status != 1 && widget.channelType == WKChannelType.group) {
        ban = true;
        hint = '此群已被封禁';
      }

      // Group-wide mute
      if (!ban &&
          ch.forbidden == 1 &&
          widget.channelType == WKChannelType.group) {
        // Owners/managers often bypass; allow if role > 0
        final role = me?.role ?? 0;
        if (role == 0) {
          forbidden = true;
          hint = '已开启全员禁言';
        }
      }
    }

    // Member-specific mute window
    if (!ban && !forbidden && me != null) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (me.forbiddenExpirationTime > nowSec) {
        forbidden = true;
        expiration = me.forbiddenExpirationTime;
        hint = _formatMuteCountdown(expiration - nowSec);
        _startForbiddenTimer(expiration);
      } else {
        _stopForbiddenTimer();
      }
    } else {
      _stopForbiddenTimer();
    }

    setState(() {
      _isBan = ban;
      _isForbidden = forbidden;
      _forbiddenText = hint;
    });
  }

  void _startForbiddenTimer(int expirationSec) {
    _forbiddenTimer?.cancel();
    // Update once per second to refresh countdown hint
    _forbiddenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (nowSec >= expirationSec) {
        _stopForbiddenTimer();
        _refreshPermissions();
      } else {
        setState(() {
          _forbiddenText = _formatMuteCountdown(expirationSec - nowSec);
        });
      }
    });
  }

  void _stopForbiddenTimer() {
    _forbiddenTimer?.cancel();
    _forbiddenTimer = null;
  }

  String _formatMuteCountdown(int remainingSec) {
    if (remainingSec <= 0) return '禁言已解除';
    final d = remainingSec ~/ 86400;
    final h = (remainingSec % 86400) ~/ 3600;
    final m = (remainingSec % 3600) ~/ 60;
    final s = remainingSec % 60;
    if (d > 0) return '禁言中，约${d}天后解禁';
    if (h > 0) return '禁言中，约${h}小时后解禁';
    if (m > 0) return '禁言中，${m}分后解禁';
    return '禁言中，${s}秒后解禁';
  }

  void _initializeChat() async {
    Logger.service('ChatScreen', 'Initializing chat: ${widget.channelId}');
    print(
      '🙏 ChatScreen: Starting chat initialization for ${widget.channelId}',
    );

    // If initialAroundOrderSeq is provided, configure provider to center around
    // and insert unread divider at this position (Android parity)
    if (widget.initialAroundOrderSeq > 0) {
      _chatProvider.setInitialUnreadDivider(widget.initialAroundOrderSeq);
    }
    await _chatProvider.initializeChat(widget.channelId, widget.channelType);
    // Mark all messages as read when entering the chat screen
    try {
      await WKIM.shared.conversationManager.updateRedDot(
        widget.channelId,
        widget.channelType,
        0,
      );
    } catch (_) {}

    Logger.debug(
      'ChatProvider messages count after init: ${_chatProvider.messages.length}',
    );
    print(
      '🙏 ChatScreen: Provider loaded ${_chatProvider.messages.length} messages',
    );

    // Add other user to ChatController
    if (widget.channelType == WKChannelType.personal &&
        widget.channelId != _currentUserId) {
      final otherUser = ChatUser(
        id: widget.channelId,
        name: _getChannelName(_chatProvider),
        profilePhoto: _getProfileImageUrl(),
      );
      _chatController.updateOtherUser(otherUser);
    }

    // Load existing messages after provider has loaded them - Wait for user names to load first
    if (_chatProvider.messages.isNotEmpty) {
      setState(() {
        _isLoadingUserNames = true;
      });
      print('🙏 ChatScreen: Starting to load user names for messages');
      await _loadExistingMessagesWithUserNames();
      setState(() {
        _isLoadingUserNames = false;
      });
      print('🙏 ChatScreen: Finished loading user names for messages');
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      print('🙏 ChatScreen: Chat initialization completed, UI ready to show');

      // Force process messages after state update
      if (_chatProvider.messages.isNotEmpty) {
        _processNewMessages(_chatProvider.messages);
      }
      // Auto-send image if provided from camera capture
      if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
        Logger.service(
          'ChatScreen',
          'Auto-sending captured image: ${widget.imagePath}',
        );
        _handleImageMessage(widget.imagePath!, _chatProvider);
      }
    }
  }

  /// Load existing messages and wait for user names to be properly loaded
  Future<void> _loadExistingMessagesWithUserNames() async {
    // Convert existing WKMsg messages to chatview Message format
    // Sort messages by timestamp to ensure correct order
    final sortedMessages = List<WKMsg>.from(_chatProvider.messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    print(
      '🙏 ChatScreen: Loading ${sortedMessages.length} existing messages with user names',
    );

    final convertedMessages = <Message>[];
    final userIds = <String>{};

    for (final wkMsg in sortedMessages) {
      final message = _convertWKMsgToMessage(wkMsg);
      if (message != null) {
        convertedMessages.add(message);
        _processedMessageIds.add(wkMsg.clientMsgNO);
        // Collect unique user IDs
        if (wkMsg.fromUID != _currentUserId) {
          userIds.add(wkMsg.fromUID);
        }
      }
    }

    print(
      '🙏 ChatScreen: Found ${userIds.length} unique users to load names for: $userIds',
    );

    // For group chats, load all user names FIRST before creating ChatUsers
    if (widget.channelType == WKChannelType.group && userIds.isNotEmpty) {
      print(
        '🙏 ChatScreen: Loading group member names for ${userIds.length} users',
      );
      final userNameMap = <String, String>{};

      for (final userId in userIds) {
        try {
          final displayName = await _getGroupMemberDisplayName(userId);
          if (displayName.isNotEmpty && displayName != userId) {
            userNameMap[userId] = displayName;
            print('🙏 ChatScreen: Loaded name for $userId: $displayName');
          } else {
            userNameMap[userId] = userId;
            print('🙏 ChatScreen: No name found for $userId, using ID');
          }
        } catch (e) {
          userNameMap[userId] = userId;
          print('🙏 ChatScreen: Error loading name for $userId: $e');
        }
      }

      // Now add all users with their correct names
      for (final userId in userIds) {
        if (userId != _currentUserId) {
          final user = ChatUser(
            id: userId,
            name: userNameMap[userId] ?? userId,
            profilePhoto: _getUserAvatarUrl(userId),
          );
          _chatController.updateOtherUser(user);
          print('🙏 ChatScreen: Added user $userId with name: ${user.name}');
        }
      }
    } else {
      // For personal chats, add users directly
      for (final userId in userIds) {
        if (userId != _currentUserId) {
          final user = ChatUser(
            id: userId,
            name: _getUserNameFromId(userId),
            profilePhoto: _getUserAvatarUrl(userId),
          );
          _chatController.updateOtherUser(user);
        }
      }
    }

    print(
      '🙏 ChatScreen: Adding ${convertedMessages.length} messages to chat controller',
    );

    // Initialize messages by adding to initialMessageList before the widget builds
    _chatController.initialMessageList.addAll(convertedMessages);
  }

  void _loadExistingMessages() {
    // Convert existing WKMsg messages to chatview Message format
    // Sort messages by timestamp to ensure correct order
    final sortedMessages = List<WKMsg>.from(_chatProvider.messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    Logger.debug('Loading ${sortedMessages.length} existing messages');

    final convertedMessages = <Message>[];
    final userIds = <String>{};

    for (final wkMsg in sortedMessages) {
      final message = _convertWKMsgToMessage(wkMsg);
      if (message != null) {
        convertedMessages.add(message);
        _processedMessageIds.add(wkMsg.clientMsgNO);
        // Collect unique user IDs
        if (wkMsg.fromUID != _currentUserId) {
          userIds.add(wkMsg.fromUID);
        }
      }
    }

    // Add all unique users to ChatController
    for (final userId in userIds) {
      if (userId != _currentUserId) {
        final user = ChatUser(
          id: userId,
          name: _getUserNameFromId(userId),
          profilePhoto: _getUserAvatarUrl(userId),
        );
        _chatController.updateOtherUser(user);
      }
    }

    // For group chats, asynchronously update user names with aliases
    if (widget.channelType == WKChannelType.group) {
      _updateGroupMemberNames(userIds);
    }

    Logger.debug(
      'Adding ${convertedMessages.length} messages to chat controller',
    );

    // Initialize messages by adding to initialMessageList before the widget builds
    _chatController.initialMessageList.addAll(convertedMessages);
  }

  String _getUserNameFromId(String userId) {
    print('🙏 ChatScreen: Getting user name for ID: $userId');

    // For group chats, try to get member alias/remark first
    if (widget.channelType == WKChannelType.group) {
      try {
        // Use Future.value to handle async call synchronously in this context
        // This is acceptable since we're dealing with cached data
        _getGroupMemberDisplayName(userId).then((name) {
          if (name.isNotEmpty && name != userId) {
            print('🙏 ChatScreen: Async update - got name $name for $userId');
            // Update ChatUser if name changed
            final existingUsers = _chatController.otherUsersMap;
            if (existingUsers.containsKey(userId)) {
              final user = existingUsers[userId]!;
              if (user.name != name) {
                final updatedUser = ChatUser(
                  id: userId,
                  name: name,
                  profilePhoto: user.profilePhoto,
                );
                _chatController.updateOtherUser(updatedUser);
                print(
                  '🙏 ChatScreen: Updated existing user $userId from ${user.name} to $name',
                );
              }
            }
          }
        });

        // For immediate return, try to get from existing ChatUser first
        final existingUsers = _chatController.otherUsersMap;
        if (existingUsers.containsKey(userId)) {
          final existingName = existingUsers[userId]!.name;
          if (existingName.isNotEmpty && existingName != userId) {
            print(
              '🙏 ChatScreen: Using existing cached name: $existingName for $userId',
            );
            return existingName;
          }
        }
      } catch (e) {
        print('🙏 ChatScreen: Failed to get group member name: $e');
        Logger.debug('Failed to get group member name: $e');
      }
    }

    // Try to get name from contacts (for personal chats)
    try {} catch (e) {
      // Ignore error
    }

    // Fallback to channel name or ID
    if (widget.channelType == WKChannelType.personal &&
        userId == widget.channelId) {
      final channelName = _getChannelName(_chatProvider);
      print('🙏 ChatScreen: Using channel name: $channelName for $userId');
      return channelName;
    }

    print('🙏 ChatScreen: No name found, returning ID: $userId');
    return userId;
  }

  /// Update group member names asynchronously with aliases
  Future<void> _updateGroupMemberNames(Set<String> userIds) async {
    print(
      '🙏 ChatScreen: Starting async update of group member names for ${userIds.length} users',
    );
    try {
      for (final userId in userIds) {
        print(
          '🙏 ChatScreen: Getting display name for user $userId in updateGroupMemberNames',
        );
        final displayName = await _getGroupMemberDisplayName(userId);
        if (displayName.isNotEmpty && displayName != userId) {
          // Update ChatUser with the correct display name
          final user = ChatUser(
            id: userId,
            name: displayName,
            profilePhoto: _getUserAvatarUrl(userId),
          );
          _chatController.updateOtherUser(user);
          print(
            '🙏 ChatScreen: Updated user $userId with display name: $displayName',
          );

          // Trigger UI update by refreshing the message list
          try {
            final stream = _chatController.messageStreamController;
            if (!stream.isClosed) {
              stream.sink.add(
                List<Message>.from(_chatController.initialMessageList),
              );
              print(
                '🙏 ChatScreen: Refreshed message list after name update for $userId',
              );
            }
          } catch (e) {
            print('🙏 ChatScreen: Error refreshing message list: $e');
          }
        } else {
          print('🙏 ChatScreen: No valid display name found for user $userId');
        }
      }
      print('🙏 ChatScreen: Completed async update of group member names');
    } catch (e) {
      print('🙏 ChatScreen: Error updating group member names: $e');
      Logger.debug('Error updating group member names: $e');
    }
  }

  /// Get display name for group member, prioritizing alias/remark over real name
  Future<String> _getGroupMemberDisplayName(String userId) async {
    print('🙏 ChatScreen: Getting display name for user $userId');
    try {
      // For group chats, try to get member info from GroupService API
      if (widget.channelType == WKChannelType.group) {
        print(
          '🙏 ChatScreen: Fetching group members for group ${widget.channelId}',
        );
        final members = await GroupService().getGroupMembers(
          widget.channelId,
          limit: 100, // Get enough members to find the user
        );
        print('🙏 ChatScreen: Got ${members.length} group members');

        GroupMemberEntity? member;
        try {
          member = members.firstWhere((m) => m.uid == userId);
          print(
            '🙏 ChatScreen: Found member data for $userId: name=${member.name}, remark=${member.remark}',
          );
        } catch (e) {
          member = null;
          print(
            '🙏 ChatScreen: Member $userId not found in group members list',
          );
        }

        if (member != null) {
          // Prioritize remark (alias) over name
          if (member.remark?.isNotEmpty == true) {
            print(
              '🙏 ChatScreen: Using member alias: ${member.remark} for $userId',
            );
            return member.remark!;
          }
          if (member.name?.isNotEmpty == true) {
            print(
              '🙏 ChatScreen: Using member name: ${member.name} for $userId',
            );
            return member.name!;
          }
          print('🙏 ChatScreen: Member $userId has no name or remark');
        }
      }

      // Fallback to channel info
      print(
        '🙏 ChatScreen: Trying to get channel info for $userId as fallback',
      );
      final channel = await WKIM.shared.channelManager.getChannel(
        userId,
        WKChannelType.personal,
      );
      if (channel != null && channel.channelName.isNotEmpty) {
        print(
          '🙏 ChatScreen: Using channel name: ${channel.channelName} for $userId',
        );
        return channel.channelName;
      }
      print('🙏 ChatScreen: No channel name found for $userId');
    } catch (e) {
      print(
        '🙏 ChatScreen: Error getting group member display name for $userId: $e',
      );
      Logger.debug('Error getting group member display name: $e');
    }

    print('🙏 ChatScreen: Returning userId as fallback for $userId');
    return userId;
  }

  Message? _convertWKMsgToMessage(WKMsg wkMsg) {
    try {
      String displayContent = '';
      MessageType messageType = MessageType.text;
      Map<String, dynamic>? mentionData;

      // Determine special system/time message types using WK contentType
      final int contentType = wkMsg.contentType;
      final DateTime messageTime = DateTime.fromMillisecondsSinceEpoch(
        wkMsg.timestamp * 1000,
      );

      // Centered time prompt (Android: WKContentType.msgPromptTime == -2)
      if (contentType == -2) {
        final String timeText = (wkMsg.content.isNotEmpty)
            ? wkMsg.content
            : DateFormat('HH:mm').format(messageTime);
        return Message(
          id: wkMsg.clientMsgNO,
          // Marker for chatview list to render centered system/time widget
          message: '__SYS__|time|' + timeText,
          createdAt: messageTime,
          sentBy: wkMsg.fromUID,
          messageType: MessageType.custom,
          status: MessageStatus.read,
          replyMessage: const ReplyMessage(),
        );
      }

      // Unread divider (Android: WKContentType.msgPromptNewMsg == -1)
      if (contentType == -1) {
        final String label = wkMsg.content.isNotEmpty
            ? wkMsg.content
            : 'The following is new news';
        return Message(
          id: wkMsg.clientMsgNO,
          message: '__SYS__|unread|' + label,
          createdAt: messageTime,
          sentBy: wkMsg.fromUID,
          messageType: MessageType.custom,
          status: MessageStatus.read,
          replyMessage: const ReplyMessage(),
        );
      }

      // Centered system messages (Android: isSystemMsg 1000..2000) and revoke (-5)
      if ((contentType >= 1000 && contentType <= 2000) || contentType == -5) {
        // Use SystemMessageFormatter for consistent formatting
        String sysText = SystemMessageFormatter.formatSystemContent(
          wkMsg.content,
          _currentUserId,
        ).trim();
        if (sysText.isEmpty && wkMsg.messageContent != null) {
          // Fallback to messageContent display text
          try {
            sysText = wkMsg.messageContent!.displayText();
          } catch (_) {}
        }
        if (sysText.isEmpty) sysText = 'System';

        return Message(
          id: wkMsg.clientMsgNO,
          message: '__SYS__|sys|' + sysText,
          createdAt: messageTime,
          sentBy: wkMsg.fromUID,
          messageType: MessageType.custom,
          status: MessageStatus.read,
          replyMessage: const ReplyMessage(),
        );
      }

      // 🔧 FIX: Check for mention data in multiple ways to handle persistence
      if (wkMsg.messageContent is WKMentionTextContent) {
        // Fresh mention message (just sent)
        final mentionContent = wkMsg.messageContent as WKMentionTextContent;
        displayContent = mentionContent.content;
        mentionData = {
          'entities': mentionContent.mentionEntities
              .map((e) => e.toJson())
              .toList(),
          'mention_info': mentionContent.customMentionInfo?.toJson(),
          'mention_all': mentionContent.mentionAll,
        };
        final mentionJson = jsonEncode(mentionData);
        displayContent =
            '__MENTION_DATA__|$mentionJson|${mentionContent.content}';
      } else if (_tryParseMentionFromContent(wkMsg.content)) {
        // Persisted mention message (loaded from database)
        displayContent = _convertJsonMentionToEncoded(wkMsg.content);
        // Content converted to encoded mention data format
      } else if (wkMsg.messageContent is WKTextContent) {
        final textContent = wkMsg.messageContent as WKTextContent;
        displayContent = textContent.content;
      } else if (wkMsg.messageContent is WKImageContent) {
        final imageContent = wkMsg.messageContent as WKImageContent;
        // Prefer localPath for messages sent by current user to ensure immediate preview
        if (wkMsg.fromUID == _currentUserId &&
            imageContent.localPath.isNotEmpty) {
          displayContent = imageContent.localPath;
        } else if (imageContent.url.isNotEmpty) {
          displayContent = imageContent.url;
        } else if (imageContent.localPath.isNotEmpty) {
          displayContent = imageContent.localPath;
        } else {
          displayContent = '[Image]';
        }
        messageType = MessageType.image;
      } else if (wkMsg.messageContent is WKVoiceContent) {
        final voiceContent = wkMsg.messageContent as WKVoiceContent;
        displayContent = voiceContent.url.isNotEmpty
            ? voiceContent.url
            : (voiceContent.localPath.isNotEmpty
                  ? voiceContent.localPath
                  : '[Voice]');
        messageType = MessageType.voice;
      } else if (wkMsg.messageContent is WKCardContent) {
        final card = wkMsg.messageContent as WKCardContent;
        final data = {
          '__type__': 'card',
          'uid': card.uid,
          'name': card.name,
          'vercode': card.vercode,
        };
        displayContent = jsonEncode(data);
        messageType = MessageType.custom;
      } else if (wkMsg.messageContent != null) {
        displayContent = wkMsg.messageContent!.displayText();
      } else {
        displayContent = 'Unknown message type';
      }

      // Enhanced status mapping to handle all WuKongIM message states
      MessageStatus status = _mapWKMsgStatusToMessageStatus(wkMsg.status);

      // Handle reply message
      ReplyMessage replyMessage = const ReplyMessage();
      if (wkMsg.messageContent != null && wkMsg.messageContent!.reply != null) {
        final wkReply = wkMsg.messageContent!.reply!;

        // Get reply message content
        String replyContent = '';
        if (wkReply.payload != null) {
          replyContent = wkReply.payload!.displayText();
        }

        replyMessage = ReplyMessage(
          message: replyContent,
          replyBy: wkReply.fromUID,
          replyTo: wkReply.fromUID,
          messageId: wkReply.messageId,
          messageType: MessageType.text, // Default to text, could be enhanced
        );
      }

      Logger.debug(
        'ChatScreen: Converting WKMsg ${wkMsg.clientMsgNO} - WK status: ${wkMsg.status} → MessageStatus: $status',
      );

      return Message(
        id: wkMsg.clientMsgNO,
        message: displayContent,
        createdAt: messageTime,
        sentBy: wkMsg.fromUID,
        messageType: messageType,
        status: status,
        replyMessage: replyMessage,
      );
    } catch (e) {
      Logger.error('Error converting WKMsg to Message', error: e);
      return null;
    }
  }

  /// Map WuKongIM message status to ChatView MessageStatus
  /// Using official WKSendMsgResult constants from SDK
  MessageStatus _mapWKMsgStatusToMessageStatus(int wkStatus) {
    Logger.debug('Mapping WK status $wkStatus to MessageStatus');

    switch (wkStatus) {
      case WKSendMsgResult.sendSuccess:
        // Status 1: Sent successfully
        Logger.debug(
          'Message sent successfully (WKSendMsgResult.sendSuccess: $wkStatus)',
        );
        return MessageStatus.delivered;

      case WKSendMsgResult.sendFail:
      case WKSendMsgResult.noRelation:
      case WKSendMsgResult.blackList:
      case WKSendMsgResult.notOnWhiteList:
        // Status 2, 3, 4, 13: Various failure reasons
        Logger.debug('Message failed to send (status: $wkStatus)');
        return MessageStatus.undelivered;

      case WKSendMsgResult.sendLoading:
      default:
        // Status 0 or any other: Sending/pending
        Logger.debug(
          'Message pending (WKSendMsgResult.sendLoading or other: $wkStatus)',
        );
        return MessageStatus.pending;
    }
  }

  String _getChannelName(ChatProvider chatProvider) {
    final channel = chatProvider.currentChannel;
    if (channel == null) {
      Logger.debug(
        'ChatScreen: Channel is null, returning channelId: ${widget.channelId}',
      );
      return widget.channelId;
    }

    Logger.debug(
      'ChatScreen: Channel info - ID: ${channel.channelID}, Name: ${channel.channelName}, Remark: ${channel.channelRemark}',
    );

    // Special display names for system channels
    if (channel.channelID == "u_10000") {
      return "System Notice";
    }
    if (channel.channelID == "fileHelper") {
      return "File Transfer";
    }

    // For personal chats (channelType = 1), try to get name from ContactsProvider
    if (widget.channelType == 1) {
      try {} catch (e) {
        Logger.debug('ChatScreen: Failed to get contact name: $e');
      }
    }

    // Fallback to channel info
    final displayName = channel.channelRemark.isNotEmpty
        ? channel.channelRemark
        : channel.channelName;

    Logger.debug('ChatScreen: Final display name: $displayName');
    return displayName;
  }

  /// Handle typing indicator in chat messages
  void _handleTypingIndicator(bool isTyping) {
    if (_chatController.showTypingIndicator != isTyping) {
      final provider = Provider.of<ChatProvider>(context, listen: false);
      Logger.debug(
        'ChatScreen: Setting typing indicator to $isTyping '
        '(user: ${provider.typingUserName}, userId: ${provider.typingUserId})',
      );
      _chatController.setTypingIndicator = isTyping;
    }
  }

  /// Show message context menu with forward option
  void _showMessageContextMenu(double dx, double dy, Message message) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(dx, dy, dx, dy),
      items: [
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.copy),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red[700]),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.delete,
                style: TextStyle(color: Colors.red[700]),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'copy':
          _copyMessage(message);
          break;
        case 'delete':
          _deleteMessage(message);
          break;
      }
    });
  }

  void _copyMessage(Message message) {
    // TODO: Implement copy functionality
    Logger.debug('Copy message: ${message.id}');
  }

  /// Handle mention message with proper mention data
  Future<void> _handleMentionMessageWithData(
    WKMentionTextContent mentionContent,
    ReplyMessage replyMessage,
  ) async {
    final provider = Provider.of<ChatProvider>(context, listen: false);

    Logger.service(
      'ChatScreen',
      '🏷️ Handling mention message: "${mentionContent.content}" with ${mentionContent.mentionEntities.length} mentions',
    );

    // Log mention details
    for (final entity in mentionContent.mentionEntities) {
      Logger.service(
        'ChatScreen',
        '🏷️ Mention: ${entity.displayName} (${entity.value}) at offset ${entity.offset}',
      );
    }

    try {
      if (replyMessage.messageId.isNotEmpty) {
        await provider.sendMentionTextMessageWithReply(
          mentionContent,
          replyMessage,
        );
      } else {
        await provider.sendMentionTextMessage(mentionContent);
      }

      // Clear draft after successful mention send
      try {
        if (mounted) {}
      } catch (_) {}

      Logger.service('ChatScreen', '🏷️ Mention message sent successfully');
    } catch (e) {
      Logger.error('Failed to send mention message', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.failed_to_send_message(e.toString()),
          ),
        ),
      );
    }
  }

  /// Handle regular text message (fallback)
  Future<void> _handleRegularMessage(
    String message,
    ReplyMessage replyMessage,
    MessageType messageType,
  ) async {
    final provider = Provider.of<ChatProvider>(context, listen: false);

    Logger.service('ChatScreen', '📝 Handling regular message: "$message"');

    if (messageType == MessageType.text) {
      if (replyMessage.messageId.isNotEmpty) {
        await provider.sendTextMessageWithReply(message, replyMessage);
      } else {
        await provider.sendTextMessage(message);
      }
      // Clear draft after successful text send
      try {
        if (mounted) {}
      } catch (_) {}
    } else if (messageType == MessageType.image) {
      await _handleImageMessage(message, provider);
    } else if (messageType == MessageType.voice) {
      await _handleVoiceMessage(message, provider);
    } else if (messageType == MessageType.custom) {
      // Try parse card payload bubbled from input action
      try {
        final data = jsonDecode(message);
        if (data is Map && data['__type__'] == 'card') {
          final uid = data['uid'] as String;
          final name = data['name'] as String;
          final vercode = data['vercode'] as String?;
          await provider.sendCardMessage(
            uid: uid,
            name: name,
            vercode: vercode,
          );
        }
      } catch (_) {
        // ignore non-card custom messages
      }
    }
  }

  int _selfGroupRole = -1; // -1 unknown, 0 normal, 1 admin, 2 owner

  Future<bool> _isCurrentUserGroupManager() async {
    if (widget.channelType != WKChannelType.group) return false;
    if (_selfGroupRole != -1) return _selfGroupRole != 0;
    try {
      final members = await GroupService().getGroupMembers(
        widget.channelId,
        limit: 100,
      );
      String selfUid = _currentUserId;
      final me = members.firstWhere(
        (m) => m.uid == selfUid,
        orElse: () => GroupMemberEntity(uid: '', role: 0, name: null),
      );
      _selfGroupRole = me.role;
      return _selfGroupRole != 0;
    } catch (e) {
      Logger.error('Failed to determine group role', error: e);
      _selfGroupRole = 0;
      return false;
    }
  }

  Future<void> _deleteMessage(Message message) async {
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      // Find the corresponding WKMsg
      final wkMsg = chatProvider.messages.firstWhere(
        (msg) => msg.clientMsgNO == message.id,
        orElse: () => WKMsg(),
      );
      if (wkMsg.clientMsgNO.isEmpty) {
        Logger.warning('Delete: WKMsg not found for ${message.id}');
        return;
      }

      // Determine if we can show "delete for everyone" checkbox
      bool canDeleteForEveryone = false;
      if (wkMsg.status == WKSendMsgResult.sendSuccess) {
        if (widget.channelType == WKChannelType.personal) {
          canDeleteForEveryone = wkMsg.fromUID == _currentUserId;
        } else if (widget.channelType == WKChannelType.group) {
          if (wkMsg.fromUID == _currentUserId) {
            canDeleteForEveryone = true;
          } else {
            canDeleteForEveryone = await _isCurrentUserGroupManager();
          }
        }
      }

      if (!mounted) return;

      if (!canDeleteForEveryone) {
        // Simple confirm dialog → local delete
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.delete_message),
            content: Text(AppLocalizations.of(context)!.delete_message_confirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(context)!.delete),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await chatProvider.deleteLocalMessage(wkMsg.clientMsgNO);
          _removeMessageFromUI(wkMsg.clientMsgNO);
        }
        return;
      }

      // Dialog with checkbox: Delete for everyone
      bool deleteForEveryone = true;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.delete_message),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.delete_message_confirm),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: deleteForEveryone,
                    onChanged: (v) =>
                        setState(() => deleteForEveryone = v ?? false),
                    title: Text(
                      widget.channelType == WKChannelType.group
                          ? AppLocalizations.of(
                              context,
                            )!.delete_for_everyone_group
                          : AppLocalizations.of(context)!.delete_for_both_sides,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, {'ok': false}),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'ok': true,
                    'all': deleteForEveryone,
                  }),
                  child: Text(AppLocalizations.of(context)!.delete),
                ),
              ],
            ),
          );
        },
      );

      if (result != null && result['ok'] == true) {
        final all = result['all'] == true;
        if (all) {
          final ok = await chatProvider.deleteMessagesForEveryone([
            wkMsg.clientMsgNO,
          ]);
          if (ok) {
            _removeMessageFromUI(wkMsg.clientMsgNO);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.deleted_for_everyone,
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.delete_failed),
                ),
              );
            }
          }
        } else {
          await chatProvider.deleteLocalMessage(wkMsg.clientMsgNO);
          _removeMessageFromUI(wkMsg.clientMsgNO);
        }
      }
    } catch (e) {
      Logger.error('Delete message error', error: e);
    }
  }

  void _removeMessageFromUI(String clientMsgNo) {
    try {
      final list = _chatController.initialMessageList;
      final idx = list.indexWhere((m) => m.id == clientMsgNo);
      if (idx != -1) {
        list.removeAt(idx);
        try {
          final stream = _chatController.messageStreamController;
          if (!stream.isClosed) {
            stream.sink.add(List<Message>.from(list));
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Handle image message sending
  Future<void> _handleImageMessage(
    String imagePath,
    ChatProvider provider,
  ) async {
    try {
      Logger.debug('Handling image message: $imagePath');

      // Get image dimensions
      final file = File(imagePath);
      if (!await file.exists()) {
        Logger.error('Image file does not exist: $imagePath');
        return;
      }

      // Get actual image dimensions
      final imageBytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final int width = image.width;
      final int height = image.height;

      image.dispose();

      // Send image message with actual dimensions
      await provider.sendImageMessage(imagePath, width, height);
      Logger.service(
        'ChatScreen',
        'Image message sent successfully with dimensions: ${width}x$height',
      );
    } catch (e) {
      Logger.error('Failed to handle image message', error: e);
      // Fallback to default dimensions if image processing fails
      try {
        await provider.sendImageMessage(imagePath, 300, 300);
        Logger.service(
          'ChatScreen',
          'Image message sent with default dimensions',
        );
      } catch (fallbackError) {
        Logger.error(
          'Failed to send image message with fallback',
          error: fallbackError,
        );
      }
    }
  }

  /// Handle voice message sending
  Future<void> _handleVoiceMessage(
    String voicePath,
    ChatProvider provider,
  ) async {
    try {
      Logger.debug('Handling voice message: $voicePath');

      // Get voice duration
      final file = File(voicePath);
      if (!await file.exists()) {
        Logger.error('Voice file does not exist: $voicePath');
        return;
      }

      // For now, use default duration - you can implement proper audio duration detection
      const int defaultDuration = 5; // 5 seconds

      // Send voice message
      await provider.sendVoiceMessage(voicePath, defaultDuration);
      Logger.service('ChatScreen', 'Voice message sent successfully');
    } catch (e) {
      Logger.error('Failed to handle voice message', error: e);
    }
  }

  /// Load user names for a set of user IDs and return name mapping
  Future<Map<String, String>> _loadUserNamesForUserIds(
    Set<String> userIds,
  ) async {
    print(
      '🙏 ChatScreen: Loading user names for ${userIds.length} users: $userIds',
    );
    final userNameMap = <String, String>{};

    if (widget.channelType == WKChannelType.group) {
      // For group chats, get all user names from API
      for (final userId in userIds) {
        try {
          final displayName = await _getGroupMemberDisplayName(userId);
          if (displayName.isNotEmpty) {
            userNameMap[userId] = displayName;
            print('🙏 ChatScreen: Loaded name for $userId: $displayName');
          } else {
            userNameMap[userId] = userId;
            print('🙏 ChatScreen: No name found for $userId, using ID');
          }
        } catch (e) {
          userNameMap[userId] = userId;
          print('🙏 ChatScreen: Error loading name for $userId: $e');
        }
      }
    } else {
      // For personal chats, use existing logic
      for (final userId in userIds) {
        userNameMap[userId] = _getUserNameFromId(userId);
      }
    }

    print('🙏 ChatScreen: Completed loading user names: $userNameMap');
    return userNameMap;
  }

  void _processNewMessages(List<WKMsg> messages) async {
    // Determine only the new WK messages that haven't been processed yet
    final newWkMsgs = <WKMsg>[];
    for (final m in messages) {
      if (!_processedMessageIds.contains(m.clientMsgNO)) {
        newWkMsgs.add(m);
      }
    }

    if (newWkMsgs.isEmpty) {
      return; // Nothing to do
    }

    print('🙏 ChatScreen: Processing ${newWkMsgs.length} new messages');

    // Sort only the new messages by orderSeq first (fallback to timestamp)
    newWkMsgs.sort((a, b) {
      final ao = a.orderSeq;
      final bo = b.orderSeq;
      if (ao != 0 && bo != 0 && ao != bo) return ao.compareTo(bo);
      return a.timestamp.compareTo(b.timestamp);
    });

    // Collect user IDs from new messages
    final userIds = <String>{};
    for (final wkMsg in newWkMsgs) {
      // Tắt xử lý RTC trong ChatScreen để tránh đúp với listener toàn cục
      try {} catch (_) {}
      if (wkMsg.fromUID != _currentUserId) {
        userIds.add(wkMsg.fromUID);
      }
    }

    print(
      '🙏 ChatScreen: Found ${userIds.length} users in new messages: $userIds',
    );

    // Filter to only new users not already in controller
    final newUserIds = <String>{};
    final existingUsers = _chatController.otherUsersMap;
    for (final userId in userIds) {
      if (!existingUsers.containsKey(userId)) {
        newUserIds.add(userId);
      }
    }

    print(
      '🙏 ChatScreen: ${newUserIds.length} new users need names loaded: $newUserIds',
    );

    // For group chats with new users, load names FIRST before adding messages
    Map<String, String> userNameMap = {};
    if (widget.channelType == WKChannelType.group && newUserIds.isNotEmpty) {
      print('🙏 ChatScreen: Setting loading state for new user names');
      if (mounted) {
        setState(() {
          _isLoadingUserNames = true;
        });
      }

      try {
        userNameMap = await _loadUserNamesForUserIds(newUserIds);
        print('🙏 ChatScreen: Successfully loaded user names: $userNameMap');
      } catch (e) {
        print('🙏 ChatScreen: Error loading user names: $e');
        // Fallback to IDs
        for (final userId in newUserIds) {
          userNameMap[userId] = userId;
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingUserNames = false;
        });
      }
      print('🙏 ChatScreen: Cleared loading state for user names');
    }

    // Insert new converted messages into existing list with minimal churn
    final list = _chatController.initialMessageList;

    int compareByCreatedAt(DateTime a, DateTime b) => a.compareTo(b);

    int findInsertIndex(DateTime createdAt) {
      if (list.isEmpty) return 0;
      // Binary search by createdAt (oldest -> newest ordering)
      int low = 0;
      int high = list.length;
      while (low < high) {
        final mid = (low + high) >> 1;
        final cmp = compareByCreatedAt(list[mid].createdAt, createdAt);
        if (cmp <= 0) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      return low;
    }

    for (final wkMsg in newWkMsgs) {
      final msg = _convertWKMsgToMessage(wkMsg);
      if (msg == null) continue;

      // Track processed ids
      _processedMessageIds.add(wkMsg.clientMsgNO);

      // Insert maintaining ascending order by createdAt
      final insertAt = findInsertIndex(msg.createdAt);
      list.insert(insertAt, msg);
    }

    // Add new users to ChatController with correct names
    for (final userId in newUserIds) {
      final userName = userNameMap[userId] ?? _getUserNameFromId(userId);
      final user = ChatUser(
        id: userId,
        name: userName,
        profilePhoto: _getUserAvatarUrl(userId),
      );
      _chatController.updateOtherUser(user);
      print('🙏 ChatScreen: Added new user $userId with name: $userName');
    }

    // For existing users, just log
    for (final userId in userIds) {
      if (!newUserIds.contains(userId)) {
        print('🙏 ChatScreen: User $userId already exists in controller');
      }
    }

    // DON'T run async update for group chats since we already loaded names
    // This prevents the double-update issue
    if (widget.channelType != WKChannelType.group || newUserIds.isEmpty) {
      print(
        '🙏 ChatScreen: Skipping async group member name update (already loaded or not group chat)',
      );
    }

    // Emit updated list to the stream (copy to avoid listeners holding same reference)
    try {
      final stream = _chatController.messageStreamController;
      if (!stream.isClosed) {
        stream.sink.add(List<Message>.from(list));
        print(
          '🙏 ChatScreen: Emitted updated message list with ${list.length} messages',
        );
      }
    } catch (_) {}

    // Process status updates only for the new messages
    _processMessageStatusUpdates(newWkMsgs);
  }

  /// Process message status updates for existing messages
  void _processMessageStatusUpdates(List<WKMsg> messages) {
    for (final wkMsg in messages) {
      if (_processedMessageIds.contains(wkMsg.clientMsgNO)) {
        // This is an existing message, check if we need to update its status
        final existingMessageIndex = _chatController.initialMessageList
            .indexWhere((msg) => msg.id == wkMsg.clientMsgNO);

        if (existingMessageIndex != -1) {
          final existingMessage =
              _chatController.initialMessageList[existingMessageIndex];
          final newStatus = _mapWKMsgStatusToMessageStatus(wkMsg.status);

          if (existingMessage.status != newStatus) {
            Logger.debug(
              'ChatScreen: Updating message ${wkMsg.clientMsgNO} status from ${existingMessage.status} to $newStatus (WK status: ${wkMsg.status})',
            );

            // Update the message status - this will trigger UI update
            existingMessage.setStatus = newStatus;

            Logger.debug(
              'ChatScreen: Message status updated successfully for ${wkMsg.clientMsgNO}',
            );
          }
        } else {
          Logger.debug(
            'ChatScreen: Message ${wkMsg.clientMsgNO} not found in ChatController for status update',
          );
        }
      }
    }
  }

  String _getProfileImageUrl() {
    // Prefer channel avatar from server; if missing, fall back to server endpoint for both personal and group to keep consistent with conversation list
    final channel = _chatProvider.currentChannel;
    final avatarPath = channel?.avatar ?? '';
    if (avatarPath.isNotEmpty) {
      // If avatar is a relative path, prefix with baseUrl; if it's an absolute URL, return as-is
      return ConversationUtils.getAvatarUrl(avatarPath, WKApiConfig.baseUrl);
    }
    // Fallbacks by channel type to ensure consistency across app
    if (widget.channelType == WKChannelType.group) {
      return WKApiConfig.getGroupUrl(widget.channelId);
    } else {
      return WKApiConfig.getAvatarUrl(widget.channelId);
    }
  }

  String _getCurrentUserAvatarUrl(LoginProvider loginProvider) {
    final avatar = loginProvider.currentUser?.avatar ?? '';
    if (avatar.isNotEmpty) {
      return WKApiConfig.getShowUrl(avatar);
    }
    return WKApiConfig.getAvatarUrl(_currentUserId);
  }

  String _getUserAvatarUrl(String uid) {
    // Use server endpoint for user avatar; UI will use default avatar if empty elsewhere
    return WKApiConfig.getAvatarUrl(uid);
  }

  String? _getUserStatusText(ChatProvider provider) {
    final ch = provider.currentChannel;
    if (ch == null) return null;

    if (widget.channelType == WKChannelType.group) {
      // Show group member count similar to Android
      if (_memberCount != null) return '$_memberCount members';
      return 'Group';
    }

    // Personal chat: show online/device or last seen
    if (ch.online == 1) {
      String device = 'Phone';
      if (ch.deviceFlag == 1) {
        device = 'Web';
      } else if (ch.deviceFlag == 2) {
        device = 'PC';
      }
      return '$device online';
    } else {
      if (ch.lastOffline > 0) {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final diff = nowSec - ch.lastOffline;
        if (diff <= 60) return 'Just now';
        final minutes = diff ~/ 60;
        if (minutes < 60) return '$minutes minutes ago';
        final hours = minutes ~/ 60;
        if (hours < 24) return '$hours hours ago';
        // Fallback to date time
        final dt = DateTime.fromMillisecondsSinceEpoch(ch.lastOffline * 1000);
        final fmt = DateFormat('yyyy-MM-dd HH:mm');
        return 'Last seen ${fmt.format(dt)}';
      }
      return null;
    }
  }

  /// Fetch group member count
  void _fetchGroupMemberCount() async {
    if (widget.channelType != WKChannelType.group) {
      return;
    }

    try {
      final channelInfoManager = ChannelInfoManager();

      // Try to get from cache first, otherwise fetch from API
      int? count =
          channelInfoManager.getCachedMemberCount(widget.channelId) ??
          await channelInfoManager.fetchMemberCountCached(widget.channelId);

      if (count != null && mounted) {
        setState(() {
          _memberCount = count;
        });
        Logger.debug(
          'Updated member count for group ${widget.channelId}: $count',
        );
      }
    } catch (e) {
      Logger.error('Error fetching member count', error: e);
    }
  }

  /// Setup direct listener for message status updates from WuKongIM SDK
  void _setupMessageStatusListener() {
    // Listen directly to WuKongIM message refresh events
    WKIM.shared.messageManager.addOnRefreshMsgListener(
      'chat_screen_${widget.channelId}',
      (msg) {
        Logger.debug(
          'ChatScreen: WuKongIM refresh listener - ${msg.clientMsgNO}, '
          'status: ${msg.status} (${_getStatusDescription(msg.status)})',
        );

        if (msg.channelID == widget.channelId &&
            msg.channelType == widget.channelType) {
          // Update the message status in ChatController
          final existingMessageIndex = _chatController.initialMessageList
              .indexWhere((m) => m.id == msg.clientMsgNO);

          if (existingMessageIndex != -1) {
            final existingMessage =
                _chatController.initialMessageList[existingMessageIndex];
            final newStatus = _mapWKMsgStatusToMessageStatus(msg.status);

            if (existingMessage.status != newStatus) {
              Logger.debug(
                'ChatScreen: Direct update - Message ${msg.clientMsgNO} status from ${existingMessage.status} to $newStatus',
              );

              // Update the message status - this will trigger UI update
              existingMessage.setStatus = newStatus;
            }
          }
        }
      },
    );
  }

  // Listen for clear-channel events from SDK to clear UI immediately
  void _setupClearChannelListener() {
    WKIM.shared.messageManager.addOnClearChannelMsgListener(
      'chat_screen_clear_${widget.channelId}',
      (channelId, channelType) {
        if (channelId == widget.channelId &&
            channelType == widget.channelType) {
          _processedMessageIds.clear();
          _chatController.initialMessageList.clear();
          try {
            final stream = _chatController.messageStreamController;
            if (!stream.isClosed) {
              stream.sink.add([]);
            }
          } catch (_) {}
          if (mounted) setState(() {});
        }
      },
    );
  }

  /// Get human-readable status description for debugging
  String _getStatusDescription(int wkStatus) {
    switch (wkStatus) {
      case WKSendMsgResult.sendLoading:
        return 'Sending';
      case WKSendMsgResult.sendSuccess:
        return 'Success';
      case WKSendMsgResult.sendFail:
        return 'Failed';
      case WKSendMsgResult.noRelation:
        return 'No Relation';
      case WKSendMsgResult.blackList:
        return 'Blacklisted';
      case WKSendMsgResult.notOnWhiteList:
        return 'Not Whitelisted';
      default:
        return 'Unknown($wkStatus)';
    }
  }

  /// Build custom message status widget using WuKongIM SDK status mapping
  /// WKSendMsgResult.sendLoading (0): Đang gửi - Loading spinner
  /// WKSendMsgResult.sendSuccess (1): Gửi thành công - Icon check xanh
  /// WKSendMsgResult.sendFail (2+): Gửi lỗi - Icon error đỏ
  Widget _buildMessageStatusWidget(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        );

      case MessageStatus.delivered:
        return Icon(Icons.check, size: 14, color: Colors.green[400]!);

      case MessageStatus.undelivered:
        return Icon(Icons.error, size: 14, color: Colors.red[400]!);

      case MessageStatus.read:
        return Icon(Icons.check_circle, size: 14, color: Colors.green[400]!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Claymorphism background
      body: _buildChatContent(),
    );
  }

  Widget _buildChatContent() {
    // Only rebuild when loading state changes
    return Selector<ChatProvider, bool>(
      selector: (_, provider) => provider.isLoading,
      builder: (context, isLoading, child) {
        if ((isLoading && !_isInitialized) || _isLoadingUserNames) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        return child!;
      },
      child: AnimationLimiter(
        child: AnimationConfiguration.synchronized(
          duration: const Duration(milliseconds: 450),
          child: SlideAnimation(
            verticalOffset: 50.0,
            curve: Curves.easeOutQuart,
            child: FadeInAnimation(
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(
                          0xFFFAFBFC,
                        ), // Claymorphism content container
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                        boxShadow: [
                          // Claymorphism shadow effect
                          BoxShadow(
                            color: Color(0x08000000),
                            offset: Offset(2, 2),
                            blurRadius: 6,
                          ),
                          BoxShadow(
                            color: Color(0xE6FFFFFF),
                            offset: Offset(-5, -5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          _buildChatView(),
                          // Listen only to typing status changes
                          Selector<ChatProvider, bool>(
                            selector: (_, provider) => provider.isTyping,
                            builder: (context, isTyping, child) {
                              // Use post frame callback to ensure proper timing
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _handleTypingIndicator(isTyping);
                              });
                              return const SizedBox.shrink();
                            },
                          ),
                          // Listen only to new messages
                          Selector<ChatProvider, int>(
                            selector: (_, provider) => provider.messages.length,
                            builder: (context, messageCount, child) {
                              if (_isInitialized) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  final provider = Provider.of<ChatProvider>(
                                    context,
                                    listen: false,
                                  );
                                  _processNewMessages(provider.messages);
                                });
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          // Message status updates are now handled by direct WuKongIM listener
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return Selector<ChatProvider, String>(
      selector: (_, provider) => _getChannelName(provider),
      builder: (context, channelName, _) {
        _lastChannelName = channelName;
        return ChangeNotifierProvider<SelectedIds>.value(
          value: _selectedIds,
          child: Stack(
            children: [
              ChatView(
                appBar: _buildAppBar(),
                chatController: _chatController,
                // 🔧 NEW: Add mention support to default SendMessageWidget
                channelId: widget.channelId,
                channelType: widget.channelType,
                onMentionSendTap: (mentionContent, replyMessage) async {
                  await _handleMentionMessageWithData(
                    mentionContent,
                    replyMessage,
                  );
                },
                onSendTap: (message, replyMessage, messageType) async {
                  // Handle regular text messages (fallback)
                  await _handleRegularMessage(
                    message,
                    replyMessage,
                    messageType,
                  );
                },
                // TODO: Implement message long press handler when ChatView supports it
                // onMessageLongPress: _showMessageContextMenu,
                chatViewState: _buildChatViewState(),
                loadMoreData: () async {
                  // Load more messages when scrolling to top (Android parity)
                  final provider = Provider.of<ChatProvider>(
                    context,
                    listen: false,
                  );
                  Logger.debug(
                    'ChatScreen: loadMoreData triggered -> calling provider.loadMessages(loadMore:true) ...',
                  );
                  await provider.loadMessages(loadMore: true);
                  Logger.debug(
                    'ChatScreen: loadMoreData completed. messagesLen=${provider.messages.length}, hasMore=${provider.hasMoreMessages}',
                  );
                },
                isLastPage: !Provider.of<ChatProvider>(
                  context,
                  listen: false,
                ).hasMoreMessages,
                loadingWidget: const Center(child: CircularProgressIndicator()),
                chatBubbleConfig: ChatBubbleConfiguration(
                  outgoingChatBubbleConfig: ChatBubble(
                    color: const Color(0xFF3B82F6), // Claymorphism blue color
                    textStyle: GoogleFonts.notoSansSc(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        const Shadow(
                          color: Color(0x40000000),
                          offset: Offset(0.5, 0.5),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(8),
                    ),
                    receiptsWidgetConfig: ReceiptsWidgetConfig(
                      showReceiptsIn: ShowReceiptsIn
                          .all, // Hiển thị trạng thái cho tất cả tin nhắn
                      receiptsBuilder: _buildMessageStatusWidget,
                    ),
                  ),
                  inComingChatBubbleConfig: ChatBubble(
                    color: const Color(
                      0xFFF7F8FA,
                    ), // Claymorphism light background
                    textStyle: GoogleFonts.notoSansSc(
                      color: const Color(0xFF374151),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        const Shadow(
                          color: Color(0x80FFFFFF),
                          offset: Offset(0.5, 0.5),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(24),
                    ),
                    onMessageRead: (message) {
                      // Handle message read
                      Logger.debug('Message read: ${message.id}');
                    },
                  ),
                ),
                sendMessageConfig: SendMessageConfiguration(
                  // Enable image picker
                  enableCameraImagePicker: true,
                  enableGalleryImagePicker: true,
                  // Enable voice recording
                  allowRecordingVoice: true,
                  imagePickerIconsConfig: ImagePickerIconsConfiguration(
                    cameraIconColor: const Color(0xFF3B82F6),
                    galleryIconColor: const Color(0xFF10B981),
                    // Add a card icon button via custom icon slots
                    galleryImagePickerIcon: const Icon(
                      Icons.image,
                      color: Color(0xFF10B981),
                    ),
                    cameraImagePickerIcon: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  // Voice recording configuration
                  voiceRecordingConfiguration: VoiceRecordingConfiguration(
                    backgroundColor: const Color(
                      0xFFF7F8FA,
                    ), // Claymorphism background
                    recorderIconColor: const Color(0xFF3B82F6),
                    waveStyle: WaveStyle(
                      showMiddleLine: false,
                      waveColor: const Color(0x803B82F6), // 50% opacity
                      extendWaveform: true,
                    ),
                  ),
                  textFieldConfig: TextFieldConfiguration(
                    enabled: _isInputEnabled,
                    hintText: _isInputEnabled
                        ? 'Type a message...'
                        : _forbiddenText,
                    hintStyle: GoogleFonts.notoSansSc(
                      color: const Color(0xFF6B7280),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textStyle: GoogleFonts.notoSansSc(
                      color: const Color(0xFF374151),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    onMessageTyping: (status) {
                      // Handle typing status
                      final provider = Provider.of<ChatProvider>(
                        context,
                        listen: false,
                      );
                      provider.handleTextChanged(status.name);
                    },
                  ),
                  defaultSendButtonColor: const Color(0xFF3B82F6),
                  textFieldBackgroundColor: const Color(
                    0xFFF7F8FA,
                  ), // Claymorphism input background
                  closeIconColor: const Color(0xFF6B7280),
                ),
                emojiPickerSheetConfig: Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    backgroundColor: const Color(
                      0xFFF7F8FA,
                    ), // Claymorphism emoji background
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: const Color(
                      0xFFF8FAFC,
                    ), // Claymorphism action bar background
                    buttonColor: const Color(0xFF6B7280),
                    buttonIconColor: const Color(0xFF374151),
                  ),
                ),
                typeIndicatorConfig: _buildTypeIndicatorConfig(),
                profileCircleConfig: ProfileCircleConfiguration(
                  bottomPadding: 4,
                  circleRadius: 20,
                  profileImageUrl: _getProfileImageUrl(),
                ),
                repliedMessageConfig: RepliedMessageConfiguration(
                  backgroundColor: const Color(0x1A3B82F6), // 10% opacity blue
                  verticalBarColor: const Color(0xFF3B82F6),
                  textStyle: GoogleFonts.notoSansSc(
                    color: const Color(0xFF374151),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  replyTitleTextStyle: GoogleFonts.notoSansSc(
                    color: const Color(0xFF3B82F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                swipeToReplyConfig: const SwipeToReplyConfiguration(
                  replyIconColor: Color(0xFF3B82F6), // Claymorphism blue
                ),
                messageConfig: MessageConfiguration(
                  messageReactionConfig: MessageReactionConfiguration(
                    backgroundColor: const Color(
                      0xFFF8FAFC,
                    ), // Claymorphism background
                    borderColor: const Color(0xFFE5E7EB), // Claymorphism border
                    reactionsBottomSheetConfig:
                        ReactionsBottomSheetConfiguration(
                          backgroundColor: const Color(
                            0xFFF8FAFC,
                          ), // Claymorphism background
                          reactionWidgetDecoration: BoxDecoration(
                            color: const Color(
                              0xFFF7F8FA,
                            ), // Claymorphism component background
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              // Claymorphism shadow
                              const BoxShadow(
                                color: Color(0x0A000000),
                                offset: Offset(2, 2),
                                blurRadius: 4,
                              ),
                              const BoxShadow(
                                color: Color(0xE6FFFFFF),
                                offset: Offset(-2, -2),
                                blurRadius: 4,
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xB3FFFFFF),
                              width: 1,
                            ),
                          ),
                        ),
                  ),
                  customMessageBuilder: (message) {
                    // Render card payload bubbled via input (MessageType.custom)
                    // and (optional) system-time or other custom uses fallback to text
                    try {
                      final data = jsonDecode(message.message);
                      if (data is Map && data['__type__'] == 'card') {
                        final String name = (data['name'] ?? '') as String;
                        final String uid = (data['uid'] ?? '') as String;
                        final bool isMe = _currentUserId == message.sentBy;
                        return InkWell(
                          onTap: () {
                            // Debug log for card tap
                            print('=== Card Tap Debug ===');
                            print('Card UserId: $uid');
                            print('Card Name: $name');
                            print('ChannelId: ${widget.channelId}');
                            print('ChannelType: ${widget.channelType}');
                            print(
                              'GroupId: ${widget.channelType == WKChannelType.group ? widget.channelId : null}',
                            );
                            print('======================');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                              minWidth: 240,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isMe
                                    ? const Color(0xB3FFFFFF)
                                    : const Color(0xFFE5E7EB),
                              ),
                              boxShadow: [
                                // Subtle elevation for nicer contrast
                                const BoxShadow(
                                  color: Color(0x0A000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(
                                          0xFFEDEFF2,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Color(0xFFBDBDBD),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          name.isNotEmpty ? name : uid,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF111111),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFE5E7EB),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Contact Card',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                      const Spacer(),
                                      Builder(
                                        builder: (_) {
                                          final bool isMe =
                                              _currentUserId == message.sentBy;
                                          final String timeText =
                                              DateFormat('a hh:mm')
                                                  .format(message.createdAt)
                                                  .toUpperCase();
                                          final List<Widget> right = [
                                            Text(
                                              timeText,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          ];
                                          if (isMe) {
                                            IconData icon;
                                            switch (message.status) {
                                              case MessageStatus.read:
                                                icon = Icons.done_all;
                                                break;
                                              case MessageStatus.delivered:
                                              case MessageStatus.pending:
                                                icon = Icons.check;
                                                break;
                                              default:
                                                icon = Icons.access_time;
                                            }
                                            right.add(const SizedBox(width: 6));
                                            right.add(
                                              Icon(
                                                icon,
                                                size: 16,
                                                color: const Color(0xFF9CA3AF),
                                              ),
                                            );
                                          }
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: right,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    } catch (_) {}
                    return Text(
                      message.message,
                      style: GoogleFonts.notoSansSc(fontSize: 14),
                    );
                  },
                  imageMessageConfig: ImageMessageConfiguration(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    borderRadius: BorderRadius.circular(
                      20,
                    ), // Claymorphism rounded corners
                    shareIconConfig: ShareIconConfiguration(
                      defaultIconBackgroundColor: const Color(
                        0xFFF7F8FA,
                      ), // Claymorphism icon background
                      defaultIconColor: const Color(
                        0xFF374151,
                      ), // Claymorphism icon color
                    ),
                  ),
                ),
                featureActiveConfig: const FeatureActiveConfig(
                  lastSeenAgoBuilderVisibility: true,
                  receiptsBuilderVisibility:
                      true, // Hiển thị trạng thái tin nhắn
                  enableScrollToBottomButton: true,
                  enableSwipeToReply: true,
                  enableReactionPopup: true,
                  enableOtherUserProfileAvatar: true,
                  enableOtherUserName: true,
                  enableCurrentUserProfileAvatar:
                      false, // Ẩn avatar của user hiện tại
                  enablePagination: true,
                  enableReplySnackBar: true,
                ),
                reactionPopupConfig: ReactionPopupConfiguration(
                  backgroundColor: const Color(
                    0xFFF8FAFC,
                  ), // Claymorphism background
                  shadow: const BoxShadow(
                    color: Color(0x0A000000), // Claymorphism shadow
                    blurRadius: 20,
                    offset: Offset(4, 4),
                  ),
                ),
                replyPopupConfig: ReplyPopupConfiguration(
                  backgroundColor: const Color(
                    0xFFF8FAFC,
                  ), // Claymorphism background
                  topBorderColor: const Color(
                    0xFFE5E7EB,
                  ), // Claymorphism border
                ),
                onChooseMessage: _onChooseFromContextMenu,
                selectionMode: _selectionMode,
                // selectedIds projection handled below
                onToggleSelect: _toggleSelect,
                // Bubble delete action up to ChatScreen from ChatListWidget
                onDeleteMessage: _deleteMessage,
              ),
              // bottom action bar removed; actions are moved to AppBar when selectionMode == true
            ],
          ),
        );
      },
    );
  }

  ChatViewState _buildChatViewState() {
    // Always return hasMessages to allow ChatView to display messages
    // The ChatView will handle empty state internally
    return ChatViewState.hasMessages;
  }

  TypeIndicatorConfiguration _buildTypeIndicatorConfig() {
    // Always return configuration - the show/hide logic is handled by ChatController
    return TypeIndicatorConfiguration(
      flashingCircleBrightColor: const Color(0xFF3B82F6), // Claymorphism blue
      flashingCircleDarkColor: const Color(0x803B82F6), // 50% opacity
      indicatorSize: 8.0,
      indicatorSpacing: 4.0,
    );
  }

  /// Try to parse mention data from message content (for persisted messages)
  bool _tryParseMentionFromContent(String content) {
    try {
      // Check if content already contains encoded mention data
      if (content.startsWith('__MENTION_DATA__|')) {
        return true;
      }

      // Check if content is JSON with mention fields (from database)
      if (content.startsWith('{')) {
        final json = jsonDecode(content) as Map<String, dynamic>;
        if (json.containsKey('entities') ||
            json.containsKey('mention_info') ||
            json.containsKey('mention')) {
          return true;
        }
      }
    } catch (e) {
      // Not valid JSON or mention data
    }
    return false;
  }

  /// Convert JSON mention data to encoded format for TextMessageView
  String _convertJsonMentionToEncoded(String content) {
    try {
      // If already encoded, return as-is
      if (content.startsWith('__MENTION_DATA__|')) {
        return content;
      }

      // Parse JSON mention data
      if (content.startsWith('{')) {
        final json = jsonDecode(content) as Map<String, dynamic>;

        // Extract actual text content
        final actualContent = (json['content'] ?? '').toString();

        // Case 1: already has detailed entities/mention_info
        if (json.containsKey('entities') || json.containsKey('mention_info')) {
          final mentionData = {
            'entities': json['entities'] ?? [],
            'mention_info': json['mention_info'],
            'mention_all': json['mention_all'] ?? false,
          };
          final mentionJson = jsonEncode(mentionData);
          return '__MENTION_DATA__|$mentionJson|$actualContent';
        }

        // Case 2: server provides only mention.uids → reconstruct entities from text
        if (json.containsKey('mention')) {
          final mention = json['mention'];
          List<dynamic> uidsDyn = [];
          if (mention is Map && mention['uids'] is List) {
            uidsDyn = mention['uids'] as List<dynamic>;
          }
          final uids = uidsDyn.map((e) => e.toString()).toList();

          // Find all @tokens in the text to determine offsets/lengths
          final entities = <Map<String, dynamic>>[];
          final regex = RegExp(r'@[\S]+');
          final matches = regex.allMatches(actualContent).toList();

          for (int i = 0; i < matches.length; i++) {
            final m = matches[i];
            final token = actualContent.substring(m.start, m.end);
            final uid = i < uids.length ? uids[i] : token.replaceFirst('@', '');
            entities.add({
              'type': 'mention',
              'value': uid,
              'offset': m.start,
              'length': m.end - m.start,
            });
          }

          final mentionData = {
            'entities': entities,
            'mention_info': {'uids': uids},
            'mention_all': json['mention_all'] ?? false,
          };
          final mentionJson = jsonEncode(mentionData);
          return '__MENTION_DATA__|$mentionJson|$actualContent';
        }
      }
    } catch (e) {
      Logger.warning('Failed to convert JSON mention data: $e');
    }

    // Fallback to original content
    return content;
  }

  Widget _buildAppBar() {
    return Consumer2<ChatProvider, SelectedIds>(
      builder: (context, provider, selectedIds, child) {
        return Container(
          decoration: const BoxDecoration(color: Color(0xFFFAFBFC)),
          child: ChatViewAppBar(
            backGroundColor: Colors.transparent,
            profilePicture: _getProfileImageUrl(),
            onProfileTap: () {
              // Info navigation removed - just show profile picture
            },
            backArrowColor: const Color(
              0xFF4B5563,
            ), // Màu icon đậm hơn một chút
            chatTitle: _lastChannelName ?? _getChannelName(provider),
            chatTitleTextStyle: GoogleFonts.notoSansSc(
              fontSize: 17, // Size vừa phải
              fontWeight: FontWeight.w600, // Đậm vừa
              color: const Color(0xFF1F2937), // Màu chữ đậm rõ ràng
              letterSpacing: -0.2, // Giãn chữ nhẹ
            ),
            userStatus: _getUserStatusText(provider),
            userStatusTextStyle: GoogleFonts.notoSansSc(
              color: const Color(0xFF6B7280),
              fontSize: 13, // Size nhỏ hơn một chút
              fontWeight: FontWeight.w400, // Nhẹ hơn
              letterSpacing: -0.1,
            ),
            actions: [
              // Video call buttons
              CallButtonsRow(
                onVideoCall: () => _startVideoCall(),
                onAudioCall: () => _startAudioCall(),
                isVideoCallEnabled: _isInputEnabled,
                isAudioCallEnabled: _isInputEnabled,
                callType: widget.channelType == WKChannelType.group
                    ? VideoCallType.group
                    : VideoCallType.p2p,
              ),
            ],
            selectionMode: _selectionMode,
            selectedCount: selectedIds.length,
            onCancelSelection: () {
              setState(() {
                _selectionMode = false;
                _selectedIds.clear();
              });
            },
            onDeleteSelected: _onDeleteSelected,
          ),
        );
      },
    );
  }

  Future<void> _onDeleteSelected() async {
    if (_selectedIds.length == 0) return;
    final provider = Provider.of<ChatProvider>(context, listen: false);
    final selected = provider.messages
        .where((m) => _selectedIds.contains(m.clientMsgNO))
        .toList();

    // Ask user whether to delete for everyone if possible (only when all eligible)
    bool canAll = true;
    for (final m in selected) {
      if (m.status != WKSendMsgResult.sendSuccess) {
        canAll = false;
        break;
      }
      if (widget.channelType == WKChannelType.personal) {
        if (m.fromUID != _currentUserId) {
          canAll = false;
          break;
        }
      } else if (widget.channelType == WKChannelType.group) {
        if (m.fromUID != _currentUserId) {
          // Need admin/owner for deleting others' messages → check once
          canAll = await _isCurrentUserGroupManager();
          if (!canAll) break;
        }
      }
    }

    bool deleteForEveryone = false;
    if (canAll) {
      final res = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          bool checked = true;
          return StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.delete_message),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.delete_message_confirm),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: checked,
                    onChanged: (v) => setState(() => checked = v ?? false),
                    title: Text(
                      widget.channelType == WKChannelType.group
                          ? AppLocalizations.of(
                              context,
                            )!.delete_for_everyone_group
                          : AppLocalizations.of(context)!.delete_for_both_sides,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, {'ok': false}),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, {'ok': true, 'all': checked}),
                  child: Text(AppLocalizations.of(context)!.delete),
                ),
              ],
            ),
          );
        },
      );
      deleteForEveryone =
          (res != null && res['ok'] == true && res['all'] == true);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.delete_message),
          content: Text(AppLocalizations.of(context)!.delete_message_confirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context)!.delete),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (deleteForEveryone) {
      final ok = await provider.deleteMessagesForEveryone(
        selected.map((e) => e.clientMsgNO).toList(),
      );
      if (ok) {
        for (final m in selected) {
          _removeMessageFromUI(m.clientMsgNO);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.deleted_for_everyone),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.delete_failed),
            ),
          );
        }
      }
    } else {
      for (final m in selected) {
        await provider.deleteLocalMessage(m.clientMsgNO);
        _removeMessageFromUI(m.clientMsgNO);
      }
    }

    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  // Enter multi-select mode when user taps "Choose" on a message
  void _onChooseFromContextMenu(Message message) {
    Logger.debug('Choose from context menu: ${message.id}');
    if (!_selectionMode) setState(() => _selectionMode = true);
    _selectedIds.toggle(message.id);
  }

  void _toggleSelect(Message message) {
    _selectedIds.toggle(message.id);
  }

  /// Bắt đầu cuộc gọi video
  Future<void> _startVideoCall() async {
    try {
      final loginProvider = Provider.of<LoginProvider>(context, listen: false);
      final currentUser = loginProvider.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để sử dụng tính năng gọi video'),
          ),
        );
        return;
      }

      // Lấy thông tin channel
      final channel = _chatProvider.currentChannel;
      if (channel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lấy thông tin cuộc trò chuyện'),
          ),
        );
        return;
      }

      // Xác định danh sách participants
      List<String> participants = [];
      if (widget.channelType == WKChannelType.personal) {
        participants = [widget.channelId];
      } else {
        // For group calls, get all members
        try {
          final members = await GroupService().getGroupMembers(
            widget.channelId,
            limit: 100,
          );
          participants = members.map((m) => m.uid).toList();
        } catch (e) {
          Logger.error('Failed to get group members for video call', error: e);
          participants = [widget.channelId]; // Fallback
        }
      }

      // Navigate to video call screen
      AppRoutes.navigateToVideoCall(
        context,
        channelId: widget.channelId,
        callerId: currentUser.uid ?? '',
        callerName: currentUser.name ?? 'Unknown',
        callerAvatar: currentUser.avatar,
        participants: participants,
        callType: widget.channelType == WKChannelType.group
            ? VideoCallType.group
            : VideoCallType.p2p,
        isIncoming: false,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to start video call',
        error: e,
        stackTrace: stackTrace,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể bắt đầu cuộc gọi video: ${e.toString()}'),
        ),
      );
    }
  }

  /// Bắt đầu cuộc gọi audio (voice call)
  Future<void> _startAudioCall() async {
    try {
      // TODO: Implement audio call functionality
      // For now, show a message that audio call is not implemented yet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tính năng gọi thoại sẽ được triển khai trong phiên bản tiếp theo',
          ),
        ),
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to start audio call',
        error: e,
        stackTrace: stackTrace,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể bắt đầu cuộc gọi thoại: ${e.toString()}'),
        ),
      );
    }
  }
}
