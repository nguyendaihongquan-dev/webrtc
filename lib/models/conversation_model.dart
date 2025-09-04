import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';

import 'conversation_update_flags.dart';

/// UI model for conversation display
class UIConversation {
  String lastContent = '';
  String channelAvatar = '';
  String channelName = '';
  WKUIConversationMsg msg;
  int top = 0;
  int mute = 0;
  List<WKReminder>? reminders;

  /// Update flags to control selective UI refreshes
  ConversationUpdateFlags updateFlags = ConversationUpdateFlags();

  UIConversation(this.msg) {
    // Initialize top and mute from channel info
    msg.getWkChannel().then((channel) {
      if (channel != null) {
        top = channel.top;
        mute = channel.mute;
      }
    });
  }

  /// Get unread count as string for display
  String getUnreadCount() {
    if (msg.unreadCount > 0) {
      return '${msg.unreadCount}';
    }
    return '';
  }

  /// Get formatted time for display
  String getFormattedTime() {
    final timestamp = msg.lastMsgTimestamp;
    if (timestamp == 0) return '';

    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if conversation is pinned
  bool get isPinned => top == 1;

  /// Check if conversation is muted
  bool get isMuted => mute == 1;

  /// Get channel type display name
  String get channelTypeDisplay {
    switch (msg.channelType) {
      case 1: // Personal
        return 'Personal';
      case 2: // Group
        return 'Group';
      default:
        return 'Unknown';
    }
  }

  /// Convenience: check if the user is currently online (for personal chats)
  Future<bool> isPeerOnline() async {
    if (msg.channelType != 1) return false;
    try {
      final channel = await WKIM.shared.channelManager.getChannel(
        msg.channelID,
        msg.channelType,
      );
      return channel?.online == 1;
    } catch (_) {
      return false;
    }
  }
}

/// Utility class for conversation operations
class ConversationUtils {
  /// Sort conversations by timestamp (newest first) and pinned status
  static List<UIConversation> sortConversations(
    List<UIConversation> conversations,
  ) {
    conversations.sort((a, b) {
      // First sort by pinned status (pinned conversations first)
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // Then sort by timestamp (newest first)
      return b.msg.lastMsgTimestamp.compareTo(a.msg.lastMsgTimestamp);
    });

    return conversations;
  }

  /// Format timestamp to readable string
  static String formatDateTime(int timestamp) {
    if (timestamp == 0) return '';

    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  /// Get avatar URL for channel
  static String getAvatarUrl(String? avatar, String baseUrl) {
    if (avatar == null || avatar.isEmpty) {
      return '';
    }

    if (avatar.startsWith('http')) {
      return avatar;
    }

    return '$baseUrl/$avatar';
  }
}
