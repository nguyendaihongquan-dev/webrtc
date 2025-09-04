import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qgim_client_flutter/widgets/chatview/chatview.dart';
import '../controllers/mention_text_controller.dart';
import '../widgets/mention_text_field.dart';
import '../models/wk_mention_text_content.dart';
import '../utils/logger.dart';

/// Custom send message widget with mention support
/// Replaces default ChatView text field with MentionTextField
class MentionSendMessageWidget extends StatefulWidget {
  final ReplyMessage? replyMessage;
  final String? channelId;
  final int? channelType;
  final Function(
    String message,
    ReplyMessage replyMessage,
    MessageType messageType,
  )?
  onSendTap;
  final Function(
    WKMentionTextContent mentionContent,
    ReplyMessage replyMessage,
  )?
  onMentionSendTap;
  final Function(TypeWriterStatus status)? onMessageTyping;

  const MentionSendMessageWidget({
    Key? key,
    this.replyMessage,
    this.channelId,
    this.channelType,
    this.onSendTap,
    this.onMentionSendTap,
    this.onMessageTyping,
  }) : super(key: key);

  @override
  State<MentionSendMessageWidget> createState() =>
      _MentionSendMessageWidgetState();
}

class _MentionSendMessageWidgetState extends State<MentionSendMessageWidget> {
  MentionTextController? _mentionController;
  bool _isComposing = false;

  @override
  void dispose() {
    _mentionController?.dispose();
    super.dispose();
  }

  void _onControllerReady(MentionTextController controller) {
    _mentionController = controller;
    Logger.service('MentionSendMessageWidget', 'MentionTextController ready');
  }

  void _onTextChanged(String text) {
    setState(() {
      _isComposing = text.trim().isNotEmpty;
    });

    // Handle typing status
    if (text.trim().isNotEmpty) {
      widget.onMessageTyping?.call(TypeWriterStatus.typing);
    } else {
      widget.onMessageTyping?.call(TypeWriterStatus.typed);
    }
  }

  void _onSendPressed() {
    if (_mentionController == null || !_isComposing) return;

    final text = _mentionController!.text.trim();
    if (text.isEmpty) return;

    // 🔧 FIX: Get mention content with entities
    final mentionContent = _mentionController!.getMentionTextContent();

    Logger.service(
      'MentionSendMessageWidget',
      '🏷️ Sending message: "$text" with ${mentionContent.mentionEntities.length} mentions',
    );

    // Log mention details for debugging
    for (final entity in mentionContent.mentionEntities) {
      Logger.service(
        'MentionSendMessageWidget',
        '🏷️ Mention entity: ${entity.displayName} (${entity.value}) at ${entity.offset}-${entity.offset + entity.length}',
      );
    }

    // 🔧 FIX: Use mention-specific callback if available and has mentions
    if (widget.onMentionSendTap != null &&
        mentionContent.mentionEntities.isNotEmpty) {
      Logger.service('MentionSendMessageWidget', '🏷️ Using mention callback');
      widget.onMentionSendTap!(
        mentionContent,
        widget.replyMessage ?? const ReplyMessage(),
      );
    } else {
      // Fallback to regular text callback
      Logger.service(
        'MentionSendMessageWidget',
        '📝 Using regular text callback',
      );
      widget.onSendTap?.call(
        text,
        widget.replyMessage ?? const ReplyMessage(),
        MessageType.text,
      );
    }

    // Clear text field
    _mentionController!.clear();
    setState(() {
      _isComposing = false;
    });

    widget.onMessageTyping?.call(TypeWriterStatus.typed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply message preview
            if (widget.replyMessage?.messageId.isNotEmpty == true)
              _buildReplyPreview(),

            // Input row
            Row(
              children: [
                // Attachment button
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  color: const Color(0xFF6B7280),
                  onPressed: () {
                    // TODO: Handle attachment
                  },
                ),

                // Mention text field
                Expanded(
                  child: MentionTextField(
                    channelId: widget.channelId,
                    channelType: widget.channelType,
                    hintText: 'Type a message...',
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
                    backgroundColor: const Color(0xFFF7F8FA),
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _onSendPressed(),
                    onControllerReady: _onControllerReady,
                    maxLines: 5,
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                Container(
                  decoration: BoxDecoration(
                    color: _isComposing
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF6B7280),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isComposing ? _onSendPressed : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final replyMessage = widget.replyMessage!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: const Color(0xFF3B82F6), width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${replyMessage.replyBy}',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  replyMessage.message,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: const Color(0xFF6B7280),
            onPressed: () {
              // TODO: Clear reply message
            },
          ),
        ],
      ),
    );
  }

  /// Get mention text content for sending
  WKMentionTextContent? getMentionTextContent() {
    return _mentionController?.getMentionTextContent();
  }
}
