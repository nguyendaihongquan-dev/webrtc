import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../common/network_avatar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:ionicons/ionicons.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

import '../../models/conversation_model.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../services/wukong_service.dart';
import '../../services/contacts_service.dart';
import '../../services/group_service.dart';
import '../../services/msg_service.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../utils/system_message_formatter.dart';
import '../../utils/logger.dart';

class ConversationItem extends StatefulWidget {
  final UIConversation conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ConversationItem({
    super.key,
    required this.conversation,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<ConversationItem> {
  String _channelName = '';
  String _channelAvatar = '';
  String _lastContent = '';

  // Value notifiers for selective UI updates
  final ValueNotifier<String> _channelNameNotifier = ValueNotifier('');
  final ValueNotifier<String> _channelAvatarNotifier = ValueNotifier('');
  final ValueNotifier<String> _lastContentNotifier = ValueNotifier('');
  final ValueNotifier<String> _timeNotifier = ValueNotifier('');
  final ValueNotifier<int> _unreadCountNotifier = ValueNotifier(0);
  final ValueNotifier<String> _typingIndicatorNotifier = ValueNotifier('');
  // Online status for personal chats
  final ValueNotifier<bool> _onlineNotifier = ValueNotifier(false);
  // User status text for personal chats (online/offline/last seen)
  final ValueNotifier<String> _userStatusNotifier = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _initializeNotifiers();
    _loadChannelInfo();
    _loadLastMessage();
    _setupChannelUpdateListener();
  }

  /// Initialize value notifiers with current data
  void _initializeNotifiers() {
    _channelName = widget.conversation.channelName;
    _channelNameNotifier.value = _channelName;

    final initialAvatar = _resolveAvatarUrl(
      widget.conversation.channelAvatar,
      widget.conversation.msg.channelID,
      widget.conversation.msg.channelType,
    );
    _channelAvatar = initialAvatar;
    _channelAvatarNotifier.value = initialAvatar;
    _lastContentNotifier.value = widget.conversation.lastContent;
    _timeNotifier.value = widget.conversation.getFormattedTime();
    _unreadCountNotifier.value = widget.conversation.msg.unreadCount;

    // Initialize presence status immediately if possible
    _initializePresenceStatus();
  }

  /// Initialize presence status from cached channel if available
  void _initializePresenceStatus() {
    if (widget.conversation.msg.channelType == 1) {
      // Try to get cached channel info immediately for presence
      widget.conversation.msg
          .getWkChannel()
          .then((channel) {
            if (channel != null && mounted) {
              final isOnline = channel.online == 1;
              if (_onlineNotifier.value != isOnline) {
                _onlineNotifier.value = isOnline;
              }
              _updateUserStatusText(channel);
            }
          })
          .catchError((error) {
            // Silently ignore - will be updated via channel refresh listener
          });
    }
  }

  @override
  void didUpdateWidget(ConversationItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle selective updates based on update flags
    final updateFlags = widget.conversation.updateFlags;

    if (updateFlags.hasUpdates) {
      _processSelectiveUpdates(updateFlags);
      // Clear flags after processing
      updateFlags.resetFlags();
    }
  }

  @override
  void dispose() {
    // Remove channel update listener
    WuKongService().removeChannelRefreshListener(
      'conversation_item_${widget.conversation.msg.channelID}',
    );

    // Dispose value notifiers
    _channelNameNotifier.dispose();
    _channelAvatarNotifier.dispose();
    _lastContentNotifier.dispose();
    _timeNotifier.dispose();
    _unreadCountNotifier.dispose();
    _typingIndicatorNotifier.dispose();
    _onlineNotifier.dispose();
    _userStatusNotifier.dispose();

    super.dispose();
  }

  /// Process selective updates based on update flags
  void _processSelectiveUpdates(dynamic updateFlags) {
    // If full refresh is requested, update all components
    if (updateFlags.isFullRefresh) {
      _updateChannelInfo();
      _updateMessageContent();
      _updateTime();
      _updateUnreadCount();
      return; // Full refresh covers everything
    }

    // Otherwise, do selective updates
    if (updateFlags.isRefreshChannelInfo) {
      _updateChannelInfo();
    }

    if (updateFlags.isResetContent) {
      _updateMessageContent();
    }

    if (updateFlags.isResetTime) {
      _updateTime();
    }

    if (updateFlags.isResetCounter) {
      _updateUnreadCount();
    }

    if (updateFlags.isResetTyping) {
      _updateTypingIndicator(updateFlags);
    }
  }

  /// Update channel info (name, avatar)
  void _updateChannelInfo() {
    if (widget.conversation.channelName.isNotEmpty &&
        _channelNameNotifier.value != widget.conversation.channelName) {
      _channelName = widget.conversation.channelName;
      _channelNameNotifier.value = _channelName;
    }

    // Only update avatar when we have a concrete avatar value to avoid
    // reverting to default endpoint URLs during list refreshes
    if (widget.conversation.channelAvatar.isNotEmpty) {
      final resolvedAvatar = _resolveAvatarUrl(
        widget.conversation.channelAvatar,
        widget.conversation.msg.channelID,
        widget.conversation.msg.channelType,
      );
      if (_channelAvatarNotifier.value != resolvedAvatar) {
        _channelAvatar = resolvedAvatar;
        _channelAvatarNotifier.value = resolvedAvatar;
      }
    }
  }

  /// Update message content
  void _updateMessageContent() {
    _loadLastMessage();
  }

  /// Update timestamp
  void _updateTime() {
    final newTime = widget.conversation.getFormattedTime();
    if (_timeNotifier.value != newTime) {
      _timeNotifier.value = newTime;
    }
  }

  /// Update unread count
  void _updateUnreadCount() {
    final newCount = widget.conversation.msg.unreadCount;
    if (_unreadCountNotifier.value != newCount) {
      _unreadCountNotifier.value = newCount;
    }
  }

  /// Update typing indicator
  void _updateTypingIndicator(dynamic updateFlags) {
    if (updateFlags.isTypingExpired) {
      _typingIndicatorNotifier.value = '';
    } else {
      final typingText = widget.conversation.msg.channelType == 2
          ? '${updateFlags.typingUserName} is typing...'
          : 'typing...';
      _typingIndicatorNotifier.value = typingText;

      // Auto-clear typing indicator after 8 seconds
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) {
          _typingIndicatorNotifier.value = '';
        }
      });
    }
  }

  /// Setup channel update listener for real-time channel info updates
  void _setupChannelUpdateListener() {
    final listenerId = 'conversation_item_${widget.conversation.msg.channelID}';

    WuKongService().addChannelRefreshListener(listenerId, (channel) {
      if (channel.channelID == widget.conversation.msg.channelID && mounted) {
        final newChannelName = channel.channelRemark.isNotEmpty
            ? channel.channelRemark
            : channel.channelName;

        // Only update if we have a non-empty name to avoid flickering
        if (newChannelName.isNotEmpty && newChannelName != _channelName) {
          _channelName = newChannelName;
          _channelNameNotifier.value = newChannelName;

          final newAvatar = _resolveAvatarUrl(
            channel.avatar,
            widget.conversation.msg.channelID,
            widget.conversation.msg.channelType,
          );
          _channelAvatar = newAvatar;
          _channelAvatarNotifier.value = newAvatar;
        }

        // Update online status for personal chats
        if (widget.conversation.msg.channelType == 1) {
          final isOnline = channel.online == 1;
          if (_onlineNotifier.value != isOnline) {
            _onlineNotifier.value = isOnline;
          }
          // Update user status text
          _updateUserStatusText(channel);
        }
      }
    });
  }

  /// Load channel information with optimized caching
  void _loadChannelInfo() {
    if (widget.conversation.channelName.isEmpty) {
      // Trigger channel info fetch from API (handled by ChannelInfoManager)
      WKIM.shared.channelManager.fetchChannelInfo(
        widget.conversation.msg.channelID,
        widget.conversation.msg.channelType,
      );

      // Try to get cached channel info immediately
      _tryGetCachedChannelInfo();
    } else {
      // Use channel info from conversation if available
      _channelName = widget.conversation.channelName;
      _channelAvatar = _resolveAvatarUrl(
        widget.conversation.channelAvatar,
        widget.conversation.msg.channelID,
        widget.conversation.msg.channelType,
      );
      _channelNameNotifier.value = _channelName;
      _channelAvatarNotifier.value = _channelAvatar;

      // Also try to get cached channel info for presence even when we have name
      _tryGetCachedChannelInfo();
    }
  }

  /// Try to get cached channel information
  void _tryGetCachedChannelInfo() {
    widget.conversation.msg
        .getWkChannel()
        .then((channel) {
          if (channel != null && mounted) {
            final channelName = channel.channelRemark.isNotEmpty
                ? channel.channelRemark
                : channel.channelName;

            if (channelName.isNotEmpty && channelName != _channelName) {
              _channelName = channelName;
              _channelNameNotifier.value = channelName;

              final newAvatar = _resolveAvatarUrl(
                channel.avatar,
                widget.conversation.msg.channelID,
                widget.conversation.msg.channelType,
              );
              _channelAvatar = newAvatar;
              _channelAvatarNotifier.value = newAvatar;
            }

            // Initialize online indicator from cached channel
            if (widget.conversation.msg.channelType == 1) {
              final isOnline = channel.online == 1;
              if (_onlineNotifier.value != isOnline) {
                _onlineNotifier.value = isOnline;
              }
              // Initialize user status text
              _updateUserStatusText(channel);
            }
          }
        })
        .catchError((error) {
          // Silently ignore errors - channel update listener will handle updates
          // when the API call completes
        });
  }

  /// Load last message content
  void _loadLastMessage() {
    if (widget.conversation.lastContent.isEmpty) {
      widget.conversation.msg.getWkMsg().then((msg) async {
        if (msg != null && mounted) {
          // Get current user ID for system message formatting
          final authProvider = Provider.of<LoginProvider>(
            context,
            listen: false,
          );
          final currentUserId = authProvider.currentUser?.uid;

          // Use system message formatter to handle both regular and system messages
          final newContent =
              await SystemMessageFormatter.formatMessageForConversationList(
                msg,
                currentUserId,
              );

          _lastContent = newContent;
          _lastContentNotifier.value = newContent;
        }
      });
    } else {
      _lastContent = widget.conversation.lastContent;
      _lastContentNotifier.value = _lastContent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnreadMessages = widget.conversation.msg.unreadCount > 0;
    final isPinned = widget.conversation.isPinned;
    final isMuted = widget.conversation.isMuted;

    // Background color based on pinned status
    final Color itemColor = isPinned
        ? const Color.fromARGB(255, 235, 247, 255) // Light blue for pinned
        : const Color(0xFFFAFBFC);

    // Determine slidable extent based on number of actions
    final int actionCount =
        2 /* pin + delete */ + 1 /* mute */ + (hasUnreadMessages ? 1 : 0);
    final double computedExtent = (actionCount * 0.23) + 0.03;
    final double extentRatio = computedExtent > 1.0 ? 1.0 : computedExtent;

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: extentRatio,
        children: [
          // Pin/Unpin action
          CustomSlidableAction(
            onPressed: (_) => _onPinConversation(),
            flex: isPinned ? 3 : 2,
            backgroundColor: const Color(0xFF3B82F6),
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPinned ? Ionicons.pin_outline : Ionicons.pin,
                  color: Colors.white,
                  size: 20.0,
                ),
                const SizedBox(height: 4.0),
                Text(
                  isPinned ? 'Unpin' : 'Pin',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Mute/Unmute action
          CustomSlidableAction(
            onPressed: (_) => _onToggleMute(),
            flex: 2,
            backgroundColor: const Color(0xFF6B7280),
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isMuted
                      ? Ionicons.notifications_outline
                      : Ionicons.notifications_off_outline,
                  color: Colors.white,
                  size: 20.0,
                ),
                const SizedBox(height: 4.0),
                Text(
                  isMuted ? 'Unmute' : 'Mute',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Mark as read action (only if unread messages exist)
          if (hasUnreadMessages)
            CustomSlidableAction(
              onPressed: (_) => _onMarkAsRead(),
              flex: 3,
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Ionicons.checkmark_done_outline,
                    color: Colors.white,
                    size: 20.0,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Mark Read',
                    style: GoogleFonts.notoSansSc(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),

          // Delete action
          CustomSlidableAction(
            onPressed: (_) => _onDeleteConversation(),
            flex: 2,
            backgroundColor: const Color(0xFFEF4444),
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Ionicons.trash_outline, color: Colors.white, size: 20.0),
                const SizedBox(height: 4.0),
                Text(
                  'Delete',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: Container(
        color: itemColor,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  // Avatar with online indicator
                  _buildAvatar(),
                  const SizedBox(width: 16.0),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and time row
                        Row(
                          children: [
                            Expanded(
                              child: ValueListenableBuilder<String>(
                                valueListenable: _channelNameNotifier,
                                builder: (context, channelName, child) {
                                  final bool isGroup =
                                      widget.conversation.msg.channelType == 2;
                                  return Row(
                                    children: [
                                      if (isGroup) ...[
                                        Icon(
                                          Ionicons.people_outline,
                                          size: 16.0,
                                          color: const Color(0xFF6B7280),
                                        ),
                                        const SizedBox(width: 6.0),
                                      ],
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                channelName.isNotEmpty
                                                    ? channelName
                                                    : 'Loading...',
                                                style: GoogleFonts.notoSansSc(
                                                  fontSize: 16.0,
                                                  fontWeight: hasUnreadMessages
                                                      ? FontWeight.w900
                                                      : FontWeight.w500,
                                                  color: const Color(
                                                    0xFF374151,
                                                  ),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            ValueListenableBuilder<String>(
                              valueListenable: _timeNotifier,
                              builder: (context, time, child) {
                                return Text(
                                  time,
                                  style: GoogleFonts.notoSansSc(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF6B7280),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),

                        // Message and badges row
                        Row(
                          children: [
                            Expanded(
                              child: ValueListenableBuilder<String>(
                                valueListenable: _typingIndicatorNotifier,
                                builder: (context, typingText, child) {
                                  // Show typing indicator if someone is typing
                                  if (typingText.isNotEmpty) {
                                    return Text(
                                      typingText,
                                      style: GoogleFonts.notoSansSc(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF3B82F6),
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }

                                  // Show last message content for all chats
                                  return ValueListenableBuilder<String>(
                                    valueListenable: _lastContentNotifier,
                                    builder: (context, lastContent, __) {
                                      final text = (lastContent.isNotEmpty
                                          ? lastContent
                                          : 'No messages');
                                      return Text(
                                        text,
                                        style: GoogleFonts.notoSansSc(
                                          fontSize: 14.0,
                                          fontWeight: hasUnreadMessages
                                              ? FontWeight.w900
                                              : FontWeight.w400,
                                          color: const Color(0xFF6B7280),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8.0),

                            // Unread indicator or muted indicator
                            _buildUnreadIndicator(),

                            // Camera button
                            const SizedBox(width: 8.0),
                            _buildCameraButton(),
                          ],
                        ),
                      ],
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

  Widget _buildAvatar() {
    return ValueListenableBuilder<String>(
      valueListenable: _channelAvatarNotifier,
      builder: (context, channelAvatar, child) {
        return Stack(
          children: [
            Container(
              width: 56.0,
              height: 56.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    offset: const Offset(2, 2),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.9),
                    offset: const Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: NetworkAvatar(
                imageUrl: channelAvatar,
                displayName: _channelName.isNotEmpty
                    ? _channelName
                    : widget.conversation.msg.channelID,
                size: 52.0,
              ),
            ),
            // User status indicator for personal chats (online dot or offline text)
            if (widget.conversation.msg.channelType == 1)
              ValueListenableBuilder<String>(
                valueListenable: _userStatusNotifier,
                builder: (context, userStatus, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _onlineNotifier,
                    builder: (context, isOnline, child) {
                      if (isOnline) {
                        // Show green dot for online
                        return Positioned(
                          right: 4.0,
                          bottom: 4.0,
                          child: Container(
                            width: 16.0,
                            height: 16.0,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ), // Green for online
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: const Color(0xFFF8FAFC),
                                width: 2.0,
                              ),
                            ),
                          ),
                        );
                      } else if (userStatus.isNotEmpty) {
                        // Show offline status text
                        return Positioned(
                          right: 2.0,
                          bottom: 2.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              // Unified green color for offline time badge (same family as online dot)
                              color: const Color(0xFF10B981),
                              // More rounded pill shape
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: const Color(0xFFF8FAFC),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              userStatus.contains('minutes ago')
                                  ? userStatus.replaceAll(' minutes ago', 'm')
                                  : userStatus.contains('hours ago')
                                  ? userStatus.replaceAll(' hours ago', 'h')
                                  : userStatus.contains('Just now')
                                  ? 'now'
                                  : userStatus.contains('Last seen')
                                  ? 'offline'
                                  : userStatus,
                              style: GoogleFonts.notoSansSc(
                                fontSize: 8.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // Removed old default avatar builder; NetworkAvatar handles placeholders

  String _resolveAvatarUrl(String? avatar, String channelId, int channelType) {
    final String avatarStr = avatar ?? '';
    if (avatarStr.isNotEmpty) {
      return ConversationUtils.getAvatarUrl(avatarStr, WKApiConfig.baseUrl);
    }
    // Fallback to server endpoint by channel type
    if (channelType == 2) {
      return WKApiConfig.getGroupUrl(channelId);
    }
    return WKApiConfig.getAvatarUrl(channelId);
  }

  /// Update user status text for personal chats (online/offline/last seen)
  void _updateUserStatusText(WKChannel channel) {
    if (widget.conversation.msg.channelType != 1) return;

    String statusText = '';
    if (channel.online == 1) {
      String device = 'Phone';
      if (channel.deviceFlag == 1) {
        device = 'Web';
      } else if (channel.deviceFlag == 2) {
        device = 'PC';
      }
      statusText = '$device online';
    } else {
      if (channel.lastOffline > 0) {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final diff = nowSec - channel.lastOffline;
        if (diff <= 60) {
          statusText = 'Just now';
        } else {
          final minutes = diff ~/ 60;
          if (minutes < 60) {
            statusText = '$minutes minutes ago';
          } else {
            final hours = minutes ~/ 60;
            if (hours < 24) {
              statusText = '$hours hours ago';
            } else {
              // Fallback to date time
              final dt = DateTime.fromMillisecondsSinceEpoch(
                channel.lastOffline * 1000,
              );
              final fmt = DateFormat('yyyy-MM-dd HH:mm');
              statusText = 'Last seen ${fmt.format(dt)}';
            }
          }
        }
      }
    }

    if (_userStatusNotifier.value != statusText) {
      _userStatusNotifier.value = statusText;
    }
  }

  // Unread indicator with muted state support
  Widget _buildUnreadIndicator() {
    if (widget.conversation.isMuted) {
      return Container(
        width: 24.0,
        height: 24.0,
        decoration: const BoxDecoration(
          color: Color(0xFFE5E7EB),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Ionicons.notifications_off_outline,
            size: 14.0,
            color: const Color(0xFF6B7280),
          ),
        ),
      );
    } else {
      final count = widget.conversation.msg.unreadCount;
      if (count <= 0) return const SizedBox();

      return Container(
        constraints: const BoxConstraints(minWidth: 24.0, minHeight: 24.0),
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: GoogleFonts.notoSansSc(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  // Camera button
  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: _onTapCamera,
      child: Container(
        width: 36.0,
        height: 36.0,
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(1, 1),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Ionicons.camera_outline,
            size: 18.0,
            color: const Color(0xFF3B82F6),
          ),
        ),
      ),
    );
  }

  // Sliding action handlers
  void _onPinConversation() {
    _toggleTop();
  }

  void _onMarkAsRead() {
    _markConversationAsRead();
  }

  void _onDeleteConversation() {
    _confirmAndDeleteConversation();
  }

  void _onTapCamera() async {
    try {
      // Use wechat_camera_picker for camera
      final AssetEntity? entity = await CameraPicker.pickFromCamera(
        context,
        pickerConfig: CameraPickerConfig(
          enableRecording: false, // Only photos
          maximumRecordingDuration: const Duration(seconds: 15),
          theme: CameraPicker.themeData(Theme.of(context).primaryColor),
        ),
      );

      if (entity != null) {
        final File? file = await entity.file;
        if (file != null && mounted) {
          final String imagePath = file.path;

          Logger.service(
            'ConversationItem',
            'Camera captured image: $imagePath, navigating to chat',
          );

          // Navigate to chat screen with the captured image
          Navigator.pushNamed(
            context,
            AppRoutes.chat,
            arguments: {
              'channelId': widget.conversation.msg.channelID,
              'channelType': widget.conversation.msg.channelType,
              'aroundOrderSeq': 0,
              'imagePath': imagePath, // Pass the captured image
            },
          );
        }
      }
    } catch (e) {
      Logger.error('Camera error in ConversationItem', error: e);
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTop() async {
    try {
      final channelId = widget.conversation.msg.channelID;
      final channelType = widget.conversation.msg.channelType;
      final bool currentlyPinned = widget.conversation.isPinned;
      final int newTop = currentlyPinned ? 0 : 1;

      bool success = false;
      if (channelType == WKChannelType.personal) {
        success = await ContactsService().updateUserSettingForFriend(
          channelId,
          'top',
          newTop,
        );
      } else if (channelType == WKChannelType.group) {
        success = await GroupService().updateGroupSettingInt(
          channelId,
          'top',
          newTop,
        );
      }

      if (!mounted) return;
      if (success) {
        // Update local SDK channel cache to trigger UI refresh
        final channel = await WKIM.shared.channelManager.getChannel(
          channelId,
          channelType,
        );
        if (channel != null) {
          channel.top = newTop;
          WKIM.shared.channelManager.addOrUpdateChannel(channel);
        }
        // Update UI model immediately
        setState(() => widget.conversation.top = newTop);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${currentlyPinned ? 'unpin' : 'pin'}'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Operation failed')));
    }
  }

  Future<void> _onToggleMute() async {
    try {
      final channelId = widget.conversation.msg.channelID;
      final channelType = widget.conversation.msg.channelType;
      final bool currentlyMuted = widget.conversation.isMuted;
      final int newMute = currentlyMuted ? 0 : 1;

      bool success = false;
      if (channelType == WKChannelType.group) {
        success = await GroupService().updateGroupSettingInt(
          channelId,
          'mute',
          newMute,
        );
      } else if (channelType == WKChannelType.personal) {
        success = await ContactsService().updateUserSettingForFriend(
          channelId,
          'mute',
          newMute,
        );
      }

      if (!mounted) return;
      if (success) {
        // Update local SDK channel cache to trigger UI refresh
        final channel = await WKIM.shared.channelManager.getChannel(
          channelId,
          channelType,
        );
        if (channel != null) {
          channel.mute = newMute;
          WKIM.shared.channelManager.addOrUpdateChannel(channel);
        }
        setState(() => widget.conversation.mute = newMute);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${currentlyMuted ? 'unmute' : 'mute'}'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Operation failed')));
    }
  }

  Future<void> _markConversationAsRead() async {
    try {
      final channelId = widget.conversation.msg.channelID;
      final channelType = widget.conversation.msg.channelType;
      await WKIM.shared.conversationManager.updateRedDot(
        channelId,
        channelType,
        0,
      );
      // Update local UI immediately
      setState(() {
        widget.conversation.msg.unreadCount = 0;
        _unreadCountNotifier.value = 0;
      });
    } catch (_) {
      // No-op
    }
  }

  Future<void> _confirmAndDeleteConversation() async {
    final channelId = widget.conversation.msg.channelID;
    final channelType = widget.conversation.msg.channelType;
    final bool pinned = widget.conversation.isPinned;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('This will clear messages and remove the chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // 1) Offset messages on server (like Android MsgModel.offsetMsg)
      try {
        final baseUrl = WKApiConfig.baseUrl.isNotEmpty
            ? WKApiConfig.baseUrl
            : '${WKApiConfig.defaultBaseUrl}/v1/';
        final login = Provider.of<LoginProvider>(context, listen: false);
        final token = login.currentUser?.token ?? '';
        final dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            headers: {
              'Content-Type': 'application/json',
              'token': token,
              'package': 'com.test.demo',
              'os': 'iOS',
              'appid': 'wukongchat',
              'model': 'flutter_app',
              'version': '1.0',
            },
          ),
        );
        await MsgService(dio).offsetMsg(channelId, channelType);
      } catch (_) {}

      // 2) Clear unread red dot
      try {
        await WKIM.shared.conversationManager.updateRedDot(
          channelId,
          channelType,
          0,
        );
      } catch (_) {}

      // 3) Remove top if pinned (mirror Android)
      if (pinned) {
        try {
          if (channelType == WKChannelType.personal) {
            await ContactsService().updateUserSettingForFriend(
              channelId,
              'top',
              0,
            );
          } else if (channelType == WKChannelType.group) {
            await GroupService().updateGroupSettingInt(channelId, 'top', 0);
          }
        } catch (_) {}
      }

      // 4) Clear messages locally and delete conversation
      await WKIM.shared.messageManager.clearWithChannel(channelId, channelType);
      await WKIM.shared.conversationManager.deleteMsg(channelId, channelType);

      // 5) Refresh conversation list
      try {
        if (!mounted) return;
        final provider = Provider.of<ConversationProvider>(
          context,
          listen: false,
        );
        await provider.refreshConversations();
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Delete failed')));
    }
  }
}
