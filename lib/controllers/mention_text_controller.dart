import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/mention_entity.dart';
import '../models/wk_mention_text_content.dart';
import '../utils/logger.dart';

/// Custom TextEditingController for handling @ mentions
/// Based on Android source analysis from chat-mentions.md
class MentionTextController extends TextEditingController {
  List<MentionEntity> _entities = [];
  String? _currentMentionQuery;
  int? _currentMentionStart;

  // Callbacks
  Function(String query, int position)? onMentionTriggered;
  Function()? onMentionCancelled;
  Function(List<MentionEntity> entities)? onEntitiesChanged;

  MentionTextController({
    String? text,
    this.onMentionTriggered,
    this.onMentionCancelled,
    this.onEntitiesChanged,
  }) : super(text: text);

  /// Get current mention entities
  List<MentionEntity> get entities => List.unmodifiable(_entities);

  /// Get current mention query (text after @)
  String? get currentMentionQuery => _currentMentionQuery;

  /// Get current mention start position
  int? get currentMentionStart => _currentMentionStart;

  /// Check if currently in mention mode
  bool get isInMentionMode => _currentMentionQuery != null;

  @override
  set text(String newText) {
    final oldText = text;
    final oldSelection = selection;

    super.text = newText;

    // Update entities after text change
    _updateEntitiesAfterTextChange(oldText, newText, oldSelection);

    // Detect mention trigger
    _detectMentionTrigger();
  }

  @override
  set selection(TextSelection newSelection) {
    super.selection = newSelection;

    // Re-detect mention trigger when cursor moves
    _detectMentionTrigger();
  }

  /// Add a mention entity
  void addMention({
    required String userId,
    required String displayName,
    required int startPosition,
    required int endPosition,
  }) {
    Logger.service(
      'MentionTextController',
      '🏷️ Adding mention: $displayName ($userId) at $startPosition-$endPosition',
    );
    final mentionText = '@$displayName ';

    // Replace text
    final beforeMention = text.substring(0, startPosition);
    final afterMention = text.substring(endPosition);
    final newText = beforeMention + mentionText + afterMention;

    // Create mention entity
    final entity = MentionEntity.mention(
      userId: userId,
      offset: startPosition,
      length: mentionText.length,
      displayName: displayName,
    );

    // Update entities list
    _entities.add(entity);

    // Update text without triggering text change detection
    super.text = newText;

    // Update cursor position
    selection = TextSelection.collapsed(
      offset: startPosition + mentionText.length,
    );

    // Clear mention mode without triggering cancelled callback
    _clearMentionModeQuietly();

    // Notify listeners
    onEntitiesChanged?.call(_entities);
  }

  /// Remove mention entity at position
  void removeMentionAtPosition(int position) {
    _entities.removeWhere((entity) => entity.containsPosition(position));
    onEntitiesChanged?.call(_entities);
  }

  /// Clear all mentions
  void clearMentions() {
    Logger.service(
      'MentionTextController',
      '🧹 Clearing ${_entities.length} mentions and mention mode',
    );

    _entities.clear();
    _clearMentionModeQuietly(); // Also clear mention mode state
    onEntitiesChanged?.call(_entities);

    Logger.service(
      'MentionTextController',
      '✅ Mentions cleared, entities: ${_entities.length}',
    );
  }

  /// Get WKMentionTextContent for sending
  WKMentionTextContent getMentionTextContent() {
    return WKMentionTextContent.withMentions(
      content: text,
      entities: _entities,
    );
  }

  /// Build TextSpan with mention styling (blue background chips)
  TextSpan buildStyledTextSpan({
    TextStyle? defaultStyle,
    TextStyle? mentionStyle,
  }) {
    if (_entities.isEmpty) {
      return TextSpan(
        text: text,
        style:
            defaultStyle ??
            GoogleFonts.notoSansSc(
              fontSize: 16,
              color: const Color(0xFF374151),
            ),
      );
    }

    final spans = <InlineSpan>[];
    int currentOffset = 0;

    // Sort entities by offset
    final sortedEntities = List<MentionEntity>.from(_entities)
      ..sort((a, b) => a.offset.compareTo(b.offset));

    for (final entity in sortedEntities) {
      // Validate entity bounds
      if (entity.offset < 0 ||
          entity.offset + entity.length > text.length ||
          entity.offset < currentOffset) {
        Logger.warning(
          'MentionTextController: Invalid entity bounds, skipping: $entity',
        );
        continue;
      }

      // Add text before mention
      if (entity.offset > currentOffset) {
        final beforeText = text.substring(currentOffset, entity.offset);
        spans.add(
          TextSpan(
            text: beforeText,
            style:
                defaultStyle ??
                GoogleFonts.notoSansSc(
                  fontSize: 16,
                  color: const Color(0xFF374151),
                ),
          ),
        );
      }

      // Add mention with blue background
      final mentionText = text.substring(
        entity.offset,
        entity.offset + entity.length,
      );

      spans.add(
        WidgetSpan(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6), // Blue background
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              mentionText,
              style:
                  mentionStyle ??
                  GoogleFonts.notoSansSc(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          alignment: PlaceholderAlignment.middle,
        ),
      );

      currentOffset = entity.offset + entity.length;
    }

    // Add remaining text after last mention
    if (currentOffset < text.length) {
      final remainingText = text.substring(currentOffset);
      spans.add(
        TextSpan(
          text: remainingText,
          style:
              defaultStyle ??
              GoogleFonts.notoSansSc(
                fontSize: 16,
                color: const Color(0xFF374151),
              ),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  /// Get TextInputFormatter to prevent partial mention deletion
  TextInputFormatter getMentionInputFormatter() {
    return _MentionInputFormatter(this);
  }

  /// Detect @ mention trigger
  void _detectMentionTrigger() {
    final cursorPosition = selection.baseOffset;
    if (cursorPosition < 0) return;

    // Look for @ pattern before cursor
    final textBeforeCursor = text.substring(0, cursorPosition);
    final mentionPattern = RegExp(r'@(\w*)$');
    final match = mentionPattern.firstMatch(textBeforeCursor);

    if (match != null) {
      // Found @ pattern
      final mentionStart = match.start;
      final query = match.group(1) ?? '';

      if (_currentMentionStart != mentionStart ||
          _currentMentionQuery != query) {
        _currentMentionStart = mentionStart;
        _currentMentionQuery = query;
        onMentionTriggered?.call(query, mentionStart);
      }
    } else {
      // No @ pattern found
      if (_currentMentionQuery != null) {
        _clearMentionMode();
      }
    }
  }

  /// Clear mention mode
  void _clearMentionMode() {
    if (_currentMentionQuery != null) {
      _currentMentionQuery = null;
      _currentMentionStart = null;
      onMentionCancelled?.call();
    }
  }

  /// Clear mention mode without triggering cancelled callback
  void _clearMentionModeQuietly() {
    _currentMentionQuery = null;
    _currentMentionStart = null;
  }

  /// Update entities after text change
  void _updateEntitiesAfterTextChange(
    String oldText,
    String newText,
    TextSelection oldSelection,
  ) {
    if (oldText == newText) return;

    final changeStart = _findChangeStart(oldText, newText);
    final changeEnd = _findChangeEnd(oldText, newText);
    final lengthChange = newText.length - oldText.length;

    // Update entities
    final updatedEntities = <MentionEntity>[];

    for (final entity in _entities) {
      if (entity.offset + entity.length <= changeStart) {
        // Entity is before the change - keep as is
        updatedEntities.add(entity);
      } else if (entity.offset >= changeEnd) {
        // Entity is after the change - adjust offset
        updatedEntities.add(
          entity.copyWith(offset: entity.offset + lengthChange),
        );
      } else {
        // Entity overlaps with change - remove it
        // This handles cases where user edits within a mention
        continue;
      }
    }

    _entities = updatedEntities;
    onEntitiesChanged?.call(_entities);
  }

  /// Find start position of text change
  int _findChangeStart(String oldText, String newText) {
    int i = 0;
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;

    while (i < minLength && oldText[i] == newText[i]) {
      i++;
    }

    return i;
  }

  /// Find end position of text change
  int _findChangeEnd(String oldText, String newText) {
    int oldIndex = oldText.length - 1;
    int newIndex = newText.length - 1;

    while (oldIndex >= 0 &&
        newIndex >= 0 &&
        oldText[oldIndex] == newText[newIndex]) {
      oldIndex--;
      newIndex--;
    }

    return oldIndex + 1;
  }

  @override
  void dispose() {
    _clearMentionMode();
    super.dispose();
  }
}

/// Custom TextInputFormatter that prevents partial deletion of mentions
class _MentionInputFormatter extends TextInputFormatter {
  final MentionTextController controller;

  _MentionInputFormatter(this.controller);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final entities = controller.entities;
    if (entities.isEmpty) {
      return newValue;
    }

    // Check if user is trying to delete within a mention
    final deletedRange = _getDeletedRange(oldValue, newValue);
    if (deletedRange != null) {
      final affectedMention = _findMentionInRange(entities, deletedRange);
      if (affectedMention != null) {
        Logger.service(
          'MentionInputFormatter',
          'Preventing partial deletion of mention: ${affectedMention.displayName}',
        );

        // Delete the entire mention instead
        return _deleteEntireMention(oldValue, affectedMention);
      }
    }

    return newValue;
  }

  /// Get the range of text that was deleted
  _DeletedRange? _getDeletedRange(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length >= oldValue.text.length) {
      return null; // No deletion occurred
    }

    // Find where the deletion happened
    int start = 0;
    while (start < newValue.text.length &&
        start < oldValue.text.length &&
        oldValue.text[start] == newValue.text[start]) {
      start++;
    }

    int oldEnd = oldValue.text.length;
    int newEnd = newValue.text.length;

    while (oldEnd > start &&
        newEnd > start &&
        oldValue.text[oldEnd - 1] == newValue.text[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }

    return _DeletedRange(start, oldEnd);
  }

  /// Find mention that overlaps with the deleted range
  MentionEntity? _findMentionInRange(
    List<MentionEntity> entities,
    _DeletedRange range,
  ) {
    for (final entity in entities) {
      // Check if deletion range overlaps with mention
      if (range.start < entity.offset + entity.length &&
          range.end > entity.offset) {
        return entity;
      }
    }
    return null;
  }

  /// Delete the entire mention and return new TextEditingValue
  TextEditingValue _deleteEntireMention(
    TextEditingValue oldValue,
    MentionEntity mention,
  ) {
    // Remove the entire mention text
    final beforeMention = oldValue.text.substring(0, mention.offset);
    final afterMention = oldValue.text.substring(
      mention.offset + mention.length,
    );
    final newText = beforeMention + afterMention;

    // Remove mention from controller
    controller.removeMentionAtPosition(mention.offset);

    // Set cursor position to where mention was
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: mention.offset),
    );
  }
}

class _DeletedRange {
  final int start;
  final int end;

  _DeletedRange(this.start, this.end);

  @override
  String toString() => 'DeletedRange($start, $end)';
}
