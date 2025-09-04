import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import '../controllers/mention_text_controller.dart';
import '../widgets/mention_suggestions.dart';
import '../services/group_service.dart';
import '../models/mention_entity.dart';
import '../utils/logger.dart';

/// Custom text field with @ mention support
/// Based on Android source analysis from chat-mentions.md
class MentionTextField extends StatefulWidget {
  final String? channelId;
  final int? channelType;
  final String? hintText;
  final TextStyle? hintStyle;
  final TextStyle? textStyle;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final Function(MentionTextController)? onControllerReady;
  final bool enabled;
  final int? maxLines;
  final EdgeInsets? contentPadding;

  const MentionTextField({
    Key? key,
    this.channelId,
    this.channelType,
    this.hintText,
    this.hintStyle,
    this.textStyle,
    this.borderRadius,
    this.backgroundColor,
    this.onChanged,
    this.onSubmitted,
    this.onControllerReady,
    this.enabled = true,
    this.maxLines = 1,
    this.contentPadding,
  }) : super(key: key);

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  late MentionTextController _controller;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    
    _controller = MentionTextController(
      onMentionTriggered: _onMentionTriggered,
      onMentionCancelled: _onMentionCancelled,
      onEntitiesChanged: _onEntitiesChanged,
    );
    
    _focusNode.addListener(_onFocusChanged);
    
    // Notify parent that controller is ready
    widget.onControllerReady?.call(_controller);
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onMentionTriggered(String query, int position) {
    // Only show suggestions for group chats
    if (widget.channelType != WKChannelType.group || widget.channelId == null) {
      return;
    }
    
    Logger.service('MentionTextField', 'Mention triggered: "$query" at position $position');
    
    setState(() {
      _showSuggestions = true;
      _currentQuery = query;
    });
    
    _showOverlay();
  }

  void _onMentionCancelled() {
    Logger.service('MentionTextField', 'Mention cancelled');
    
    setState(() {
      _showSuggestions = false;
      _currentQuery = '';
    });
    
    _hideOverlay();
  }

  void _onEntitiesChanged(List<MentionEntity> entities) {
    Logger.service('MentionTextField', 'Entities changed: ${entities.length} mentions');
    // Could notify parent about entities change if needed
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onMemberSelected(GroupMemberEntity member) {
    if (_controller.currentMentionStart == null) return;
    
    // Determine display name (prioritize remark over name)
    final displayName = (member.remark?.isNotEmpty == true) 
        ? member.remark! 
        : (member.name?.isNotEmpty == true ? member.name! : member.uid);
    
    Logger.service('MentionTextField', 'Member selected: $displayName (${member.uid})');
    
    // Calculate end position (start + @ + query length)
    final startPos = _controller.currentMentionStart!;
    final endPos = startPos + 1 + _currentQuery.length; // +1 for @
    
    // Add mention
    _controller.addMention(
      userId: member.uid,
      displayName: displayName,
      startPosition: startPos,
      endPosition: endPos,
    );
    
    // Notify parent of text change
    widget.onChanged?.call(_controller.text);
  }

  void _showOverlay() {
    if (_overlayEntry != null || !_showSuggestions || widget.channelId == null) {
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32, // Account for padding
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 8), // Small gap below text field
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: MentionSuggestions(
              groupId: widget.channelId!,
              query: _currentQuery,
              onMemberSelected: _onMemberSelected,
              maxHeight: 200,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        style: widget.textStyle ?? GoogleFonts.notoSansSc(
          color: const Color(0xFF374151),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Type a message...',
          hintStyle: widget.hintStyle ?? GoogleFonts.notoSansSc(
            color: const Color(0xFF6B7280),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: widget.backgroundColor ?? const Color(0xFFF7F8FA),
          contentPadding: widget.contentPadding ?? const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (text) {
          widget.onChanged?.call(text);
        },
        onSubmitted: (text) {
          widget.onSubmitted?.call(text);
        },
      ),
    );
  }
}

/// Extension to get MentionTextController from MentionTextField
extension MentionTextFieldExtension on MentionTextField {
  /// Get the mention text content for sending
  /// This should be called from the parent widget that has access to the controller
  static getMentionTextContent(MentionTextController controller) {
    return controller.getMentionTextContent();
  }
}
