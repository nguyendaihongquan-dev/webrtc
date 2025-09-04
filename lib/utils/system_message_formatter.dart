import 'dart:convert';
import 'package:wukongimfluttersdk/entity/msg.dart';

/// Utility class for formatting system messages consistently
/// across chat screen and conversation list
class SystemMessageFormatter {
  /// Format system message content similar to Android StringUtils.getShowContent
  static String formatSystemContent(String contentJson, String? currentUserId) {
    try {
      if (contentJson.isEmpty) return '';
      final Map<String, dynamic> root = json.decode(contentJson);
      String template = root['content']?.toString() ?? '';
      final List<dynamic>? extra = root['extra'] as List<dynamic>?;
      final List<String> names = [];

      if (extra != null && extra.isNotEmpty) {
        for (final e in extra) {
          if (e is Map<String, dynamic>) {
            String name = e['name']?.toString() ?? '';
            final uid = e['uid']?.toString() ?? '';
            if (uid.isNotEmpty && uid == currentUserId) {
              name = '你'; // Match Android R.string.str_you
            }
            names.add(name);
          }
        }
      }

      if (template.isEmpty) return '';

      // Replace placeholders {0},{1}... like Java MessageFormat
      for (var i = 0; i < names.length; i++) {
        template = template.replaceAll('{$i}', names[i]);
      }

      return template;
    } catch (_) {
      return '';
    }
  }

  /// Format message content for conversation list display
  /// Handles both regular messages and system messages
  static Future<String> formatMessageForConversationList(
    WKMsg msg,
    String? currentUserId,
  ) async {
    final int contentType = msg.contentType;

    // Handle system messages (contentType 1000-2000 or -5 for revoke)
    if ((contentType >= 1000 && contentType <= 2000) || contentType == -5) {
      String sysText = formatSystemContent(msg.content, currentUserId).trim();

      if (sysText.isEmpty && msg.messageContent != null) {
        // Fallback to messageContent display text
        try {
          sysText = msg.messageContent!.displayText();
        } catch (_) {}
      }

      if (sysText.isEmpty) sysText = 'System';
      return sysText;
    }

    // Handle time prompts
    if (contentType == -2) {
      return msg.content.isNotEmpty ? msg.content : 'Time';
    }

    // Handle unread dividers
    if (contentType == -1) {
      return msg.content.isNotEmpty ? msg.content : 'The following is new news';
    }

    // Handle regular messages
    if (msg.messageContent != null) {
      return msg.messageContent!.displayText();
    }

    return 'Unknown message type';
  }
}
