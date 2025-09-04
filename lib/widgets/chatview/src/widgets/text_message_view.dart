import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';

import 'dart:convert';

import '../extensions/extensions.dart';
import '../models/chat_bubble.dart';
import '../models/config_models/link_preview_configuration.dart';
import '../models/config_models/message_reaction_configuration.dart';
import '../utils/constants/constants.dart';
import 'link_preview.dart';
import 'reaction_widget.dart';
import '../../../mention_rich_text.dart';
import '../../../../models/mention_entity.dart';

class TextMessageView extends StatelessWidget {
  const TextMessageView({
    Key? key,
    required this.isMessageBySender,
    required this.message,
    this.chatBubbleMaxWidth,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.messageReactionConfig,
    this.highlightMessage = false,
    this.highlightColor,
    this.groupId,
  }) : super(key: key);

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides message instance of chat.
  final Message message;

  /// Allow users to give max width of chat bubble.
  final double? chatBubbleMaxWidth;

  /// Provides configuration of chat bubble appearance from other user of chat.
  final ChatBubble? inComingChatBubbleConfig;

  /// Provides configuration of chat bubble appearance from current user of chat.
  final ChatBubble? outgoingChatBubbleConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents message should highlight.
  final bool highlightMessage;

  /// Allow user to set color of highlighted message.
  final Color? highlightColor;

  /// Group ID for mention context (optional)
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textMessage = message.message;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth:
                chatBubbleMaxWidth ?? MediaQuery.of(context).size.width * 0.75,
          ),
          padding:
              _padding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin:
              _margin ??
              EdgeInsets.fromLTRB(
                5,
                0,
                6,
                message.reaction.reactions.isNotEmpty ? 15 : 2,
              ),
          decoration: BoxDecoration(
            color: highlightMessage ? highlightColor : _color,
            borderRadius: _borderRadius(textMessage),
          ),
          child: textMessage.isUrl
              ? LinkPreview(
                  linkPreviewConfig: _linkPreviewConfig,
                  url: textMessage,
                )
              : _buildMessageText(context, textMessage, textTheme),
        ),
        if (message.reaction.reactions.isNotEmpty)
          ReactionWidget(
            key: key,
            isMessageBySender: isMessageBySender,
            reaction: message.reaction,
            messageReactionConfig: messageReactionConfig,
          ),
      ],
    );
  }

  EdgeInsetsGeometry? get _padding => isMessageBySender
      ? outgoingChatBubbleConfig?.padding
      : inComingChatBubbleConfig?.padding;

  EdgeInsetsGeometry? get _margin => isMessageBySender
      ? outgoingChatBubbleConfig?.margin
      : inComingChatBubbleConfig?.margin;

  LinkPreviewConfiguration? get _linkPreviewConfig => isMessageBySender
      ? outgoingChatBubbleConfig?.linkPreviewConfig
      : inComingChatBubbleConfig?.linkPreviewConfig;

  TextStyle? get _textStyle => isMessageBySender
      ? outgoingChatBubbleConfig?.textStyle
      : inComingChatBubbleConfig?.textStyle;

  /// Build message text with mention styling (bold mentions)
  Widget _buildMessageText(
    BuildContext context,
    String textMessage,
    TextTheme textTheme,
  ) {
    // Extract actual text content if encoded with mention data
    String actualText = textMessage;
    if (textMessage.startsWith('__MENTION_DATA__|')) {
      final parts = textMessage.split('|');
      if (parts.length >= 3) {
        actualText = parts
            .sublist(2)
            .join('|'); // Join remaining parts in case text contains |
      }
    }

    // Try to parse mention data from message
    final mentionData = _parseMentionData();

    if (mentionData != null && mentionData['entities'] != null) {
      // Has mentions, use MentionRichText with tap functionality
      final entities = (mentionData['entities'] as List)
          .map((e) => MentionEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return MentionRichText(
        text: actualText,
        entities: entities,
        textStyle:
            _textStyle ??
            textTheme.bodyMedium!.copyWith(color: Colors.white, fontSize: 16),
        mentionStyle:
            (_textStyle ??
                    textTheme.bodyMedium!.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ))
                .copyWith(fontWeight: FontWeight.bold),
        onMentionTap: (userId, displayName, groupId) {
          handleMentionTap(context, userId, displayName, groupId);
        },
        groupId: groupId,
      );
    }

    // No mentions, use regular Text widget
    return Text(
      actualText, // Use actual text content
      style:
          _textStyle ??
          textTheme.bodyMedium!.copyWith(color: Colors.white, fontSize: 16),
    );
  }

  /// Parse mention data from message content
  Map<String, dynamic>? _parseMentionData() {
    try {
      // Only parse mention data if message contains encoded mention data from server
      if (message.message.startsWith('__MENTION_DATA__|')) {
        final parts = message.message.split('|');
        if (parts.length >= 3) {
          final mentionJson = parts[1];
          return jsonDecode(mentionJson) as Map<String, dynamic>;
        }
      }

      // 🔧 REMOVED: Fallback detection for simple @ patterns
      // Only real mentions (with server data) should be bold, not regular @ text
    } catch (e) {
      // Ignore parsing errors, fallback to regular text
    }
    return null;
  }

  BorderRadiusGeometry _borderRadius(String message) => isMessageBySender
      ? outgoingChatBubbleConfig?.borderRadius ??
            (message.length < 37
                ? BorderRadius.circular(replyBorderRadius1)
                : BorderRadius.circular(replyBorderRadius2))
      : inComingChatBubbleConfig?.borderRadius ??
            (message.length < 29
                ? BorderRadius.circular(replyBorderRadius1)
                : BorderRadius.circular(replyBorderRadius2));

  Color get _color => isMessageBySender
      ? outgoingChatBubbleConfig?.color ?? Colors.purple
      : inComingChatBubbleConfig?.color ?? Colors.grey.shade500;
}
