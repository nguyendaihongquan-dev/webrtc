import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import '../models/mention_entity.dart';
import '../utils/logger.dart';

/// Widget to display rich text with highlighted mentions
/// Based on Android source analysis from chat-mentions.md
class MentionRichText extends StatefulWidget {
  final String text;
  final List<MentionEntity> entities;
  final TextStyle? textStyle;
  final TextStyle? mentionStyle;
  final Function(String userId, String displayName, String? groupId)?
  onMentionTap;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? groupId;

  const MentionRichText({
    super.key,
    required this.text,
    this.entities = const [],
    this.textStyle,
    this.mentionStyle,
    this.onMentionTap,
    this.maxLines,
    this.overflow,
    this.groupId,
  });

  @override
  State<MentionRichText> createState() => _MentionRichTextState();
}

class _MentionRichTextState extends State<MentionRichText> {
  final Map<String, String> _resolvedNames = {};

  @override
  void initState() {
    super.initState();
    _resolveDisplayNames();
    _setupChannelListener();
  }

  @override
  void dispose() {
    _removeChannelListener();
    super.dispose();
  }

  void _setupChannelListener() {
    // Listen for channel updates to refresh mention names when remark changes
    WKIM.shared.channelManager.addOnRefreshListener(
      'mention_rich_text_${widget.hashCode}',
      (channel) {
        if (channel.channelType == WKChannelType.personal) {
          // Check if this channel is mentioned in our entities
          final hasMention = widget.entities.any(
            (entity) => entity.value == channel.channelID,
          );
          if (hasMention) {
            // Re-resolve display names and refresh UI
            _resolveDisplayNames();
          }
        }
      },
    );
  }

  void _removeChannelListener() {
    WKIM.shared.channelManager.removeOnRefreshListener(
      'mention_rich_text_${widget.hashCode}',
    );
  }

  Future<void> _resolveDisplayNames() async {
    if (widget.entities.isEmpty) return;

    for (final entity in widget.entities) {
      try {
        final channel = await WKIM.shared.channelManager.getChannel(
          entity.value,
          WKChannelType.personal,
        );

        if (channel != null) {
          // Prioritize channelRemark over channelName
          final resolvedName = channel.channelRemark.isNotEmpty
              ? channel.channelRemark
              : (channel.channelName.isNotEmpty
                    ? channel.channelName
                    : entity.displayName);

          _resolvedNames[entity.value] = resolvedName;
        } else {
          // Fallback to original display name
          _resolvedNames[entity.value] = entity.displayName;
        }
      } catch (e) {
        Logger.warning(
          'Failed to resolve display name for ${entity.value}: $e',
        );
        _resolvedNames[entity.value] = entity.displayName;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entities.isEmpty) {
      // No mentions, display as regular text
      return Text(
        widget.text,
        style: widget.textStyle ?? _defaultTextStyle(),
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    return RichText(
      text: _buildTextSpan(context),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }

  TextSpan _buildTextSpan(BuildContext context) {
    final spans = <TextSpan>[];
    int currentOffset = 0;

    // Sort entities by offset to ensure correct order
    final sortedEntities = List<MentionEntity>.from(widget.entities)
      ..sort((a, b) => a.offset.compareTo(b.offset));

    for (final entity in sortedEntities) {
      // Validate entity bounds
      if (entity.offset < 0 ||
          entity.offset + entity.length > widget.text.length ||
          entity.offset < currentOffset) {
        Logger.warning(
          'MentionRichText: Invalid entity bounds, skipping: $entity',
        );
        continue;
      }

      // Add text before mention
      if (entity.offset > currentOffset) {
        final beforeText = widget.text.substring(currentOffset, entity.offset);
        spans.add(
          TextSpan(
            text: beforeText,
            style: widget.textStyle ?? _defaultTextStyle(),
          ),
        );
      }

      // Add mention span with resolved display name
      final mentionText = widget.text.substring(
        entity.offset,
        entity.offset + entity.length,
      );

      // Use resolved name if available, otherwise fallback to original
      final displayName = _resolvedNames[entity.value] ?? entity.displayName;

      spans.add(
        TextSpan(
          text: mentionText,
          style: widget.mentionStyle ?? _defaultMentionStyle(),
          recognizer: widget.onMentionTap != null
              ? (TapGestureRecognizer()
                  ..onTap = () {
                    Logger.service(
                      'MentionRichText',
                      'Mention tapped: $displayName (${entity.value})',
                    );
                    widget.onMentionTap!(
                      entity.value,
                      displayName,
                      widget.groupId,
                    );
                  })
              : null,
        ),
      );

      currentOffset = entity.offset + entity.length;
    }

    // Add remaining text after last mention
    if (currentOffset < widget.text.length) {
      final remainingText = widget.text.substring(currentOffset);
      spans.add(
        TextSpan(
          text: remainingText,
          style: widget.textStyle ?? _defaultTextStyle(),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  TextStyle _defaultTextStyle() {
    return GoogleFonts.notoSansSc(fontSize: 16, color: const Color(0xFF374151));
  }

  TextStyle _defaultMentionStyle() {
    return GoogleFonts.notoSansSc(
      fontSize: 16,
      color: const Color(0xFF3B82F6),
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    );
  }
}

/// Helper function to parse mentions from message content
/// This would be used when receiving messages from server
class MentionParser {
  /// Parse mentions from WKMsg content
  /// This is a placeholder - actual implementation would depend on
  /// how WuKongIM SDK handles mention metadata
  static List<MentionEntity> parseFromWKMsg(
    String content,
    Map<String, dynamic>? extras,
  ) {
    final entities = <MentionEntity>[];

    try {
      // Check if message has mention metadata
      if (extras != null) {
        final entitiesJson = extras['entities'] as List<dynamic>?;
        if (entitiesJson != null) {
          for (final entityJson in entitiesJson) {
            if (entityJson is Map<String, dynamic>) {
              final entity = MentionEntity.fromJson(entityJson);
              entities.add(entity);
            }
          }
        }
      }

      // Fallback: simple regex parsing for @mentions
      if (entities.isEmpty) {
        entities.addAll(_parseWithRegex(content));
      }
    } catch (e) {
      Logger.error('MentionParser: Failed to parse mentions', error: e);
    }

    return entities;
  }

  /// Simple regex-based mention parsing as fallback
  static List<MentionEntity> _parseWithRegex(String content) {
    final entities = <MentionEntity>[];
    final mentionPattern = RegExp(r'@(\w+)');
    final matches = mentionPattern.allMatches(content);

    for (final match in matches) {
      final displayName = match.group(1) ?? '';
      entities.add(
        MentionEntity.mention(
          userId:
              displayName, // This would need to be resolved to actual user ID
          offset: match.start,
          length: match.end - match.start,
          displayName: displayName,
        ),
      );
    }

    return entities;
  }

  /// Validate entities against content
  static List<MentionEntity> validateEntities(
    String content,
    List<MentionEntity> entities,
  ) {
    final validEntities = <MentionEntity>[];

    for (final entity in entities) {
      // Check bounds
      if (entity.offset >= 0 &&
          entity.offset + entity.length <= content.length) {
        // Check if text at position starts with @
        final entityText = content.substring(
          entity.offset,
          entity.offset + entity.length,
        );
        if (entityText.startsWith('@')) {
          validEntities.add(entity);
        }
      }
    }

    return validEntities;
  }
}

/// Extension to easily create MentionRichText from message data
extension MessageMentionExtension on String {
  /// Create MentionRichText widget from message content
  Widget toMentionRichText({
    List<MentionEntity>? entities,
    TextStyle? textStyle,
    TextStyle? mentionStyle,
    Function(String userId, String displayName, String? groupId)? onMentionTap,
    int? maxLines,
    TextOverflow? overflow,
    String? groupId,
  }) {
    return MentionRichText(
      text: this,
      entities: entities ?? [],
      textStyle: textStyle,
      mentionStyle: mentionStyle,
      onMentionTap: onMentionTap,
      maxLines: maxLines,
      overflow: overflow,
      groupId: groupId,
    );
  }
}

/// Helper function to handle mention tap and navigate to Contact Card
void handleMentionTap(
  BuildContext context,
  String userId,
  String displayName,
  String? groupId,
) {
  Logger.service(
    'MentionRichText',
    'Navigating to Contact Card for: $displayName ($userId)',
  );

  // Debug log for mention tap
  print('=== Mention Tap Debug ===');
  print('UserId: $userId');
  print('DisplayName: $displayName');
  print('GroupId: $groupId');
  print('========================');
}
