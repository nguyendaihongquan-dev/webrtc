import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'mention_entity.dart';
import '../utils/logger.dart';
import 'dart:convert';

/// Extended WKTextContent with mention support
/// Based on Android source analysis from chat-mentions.md
class WKMentionTextContent extends WKTextContent {
  List<MentionEntity> _mentionEntities = [];
  MentionInfo? _mentionInfo;
  bool mentionAll = false;

  WKMentionTextContent(super.content);

  /// Get mention entities
  List<MentionEntity> get mentionEntities =>
      List.unmodifiable(_mentionEntities);

  /// Get mention info
  MentionInfo? get customMentionInfo => _mentionInfo;

  /// Create with mentions
  WKMentionTextContent.withMentions({
    required String content,
    required List<MentionEntity> entities,
    this.mentionAll = false,
  }) : super(content) {
    _mentionEntities = List.from(entities);
    // Auto-generate mention info from entities
    _mentionInfo = MentionInfo.fromEntities(_mentionEntities);
  }

  /// Add mention entity
  void addMention(MentionEntity entity) {
    _mentionEntities.add(entity);
    _updateMentionInfo();
  }

  /// Remove mention entity
  void removeMention(MentionEntity entity) {
    _mentionEntities.removeWhere((e) => e == entity);
    _updateMentionInfo();
  }

  /// Remove mentions by user ID
  void removeMentionsByUserId(String userId) {
    _mentionEntities.removeWhere((e) => e.value == userId);
    _updateMentionInfo();
  }

  /// Update mention info from entities
  void _updateMentionInfo() {
    _mentionInfo = MentionInfo.fromEntities(_mentionEntities);
  }

  /// Get all mentioned user IDs
  List<String> getMentionedUserIds() {
    return _mentionInfo?.uids ?? [];
  }

  /// Check if user is mentioned
  bool isUserMentioned(String userId) {
    return _mentionInfo?.containsUser(userId) ?? false;
  }

  /// Update entity offsets after text change
  void updateEntitiesAfterTextChange(int changePosition, int lengthChange) {
    for (int i = 0; i < _mentionEntities.length; i++) {
      final entity = _mentionEntities[i];
      if (entity.offset > changePosition) {
        // Adjust offset for entities after change position
        _mentionEntities[i] = entity.copyWith(
          offset: entity.offset + lengthChange,
        );
      } else if (entity.offset <= changePosition &&
          changePosition < entity.offset + entity.length) {
        // Entity contains the change position - might need to remove or adjust
        // For now, we'll remove the entity as it's been modified
        _mentionEntities.removeAt(i);
        i--; // Adjust index after removal
      }
    }
    _updateMentionInfo();
  }

  /// Validate entities against current content
  void validateEntities() {
    final validEntities = <MentionEntity>[];

    for (final entity in _mentionEntities) {
      // Check if entity is within content bounds
      if (entity.offset >= 0 &&
          entity.offset + entity.length <= content.length) {
        // Check if the text at entity position starts with @
        final entityText = content.substring(
          entity.offset,
          entity.offset + entity.length,
        );
        if (entityText.startsWith('@')) {
          validEntities.add(entity);
        }
      }
    }

    _mentionEntities = validEntities;
    _updateMentionInfo();
  }

  @override
  Map<String, dynamic> encodeJson() {
    final json = super.encodeJson();

    // Add mention-specific fields according to Android format
    if (_mentionEntities.isNotEmpty) {
      json['entities'] = _mentionEntities.map((e) => e.toJson()).toList();
    }

    if (_mentionInfo != null && _mentionInfo!.uids.isNotEmpty) {
      // Keep legacy key used in our client
      json['mention_info'] = _mentionInfo!.toJson();
      // Add server/web compatible key (observed in incoming messages)
      json['mention'] = _mentionInfo!.toJson(); // { uids: [...] }
    }

    json['mention_all'] = mentionAll ? 1 : 0;

    // 🔧 ADD: Debug log to see what's being sent
    Logger.service(
      'WKMentionTextContent',
      '🏷️ Encoding mention message JSON: ${jsonEncode(json)}',
    );

    return json;
  }

  @override
  WKMentionTextContent decodeJson(Map<String, dynamic> json) {
    // Decode base text content
    super.decodeJson(json);

    // Decode mention-specific fields
    mentionAll = WKDBConst.readInt(json, 'mention_all') == 1;

    // Decode entities
    final entitiesJson = json['entities'] as List<dynamic>?;
    if (entitiesJson != null) {
      _mentionEntities = entitiesJson
          .map((e) => MentionEntity.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Decode mention info
    final mentionInfoJson = json['mention_info'] as Map<String, dynamic>?;
    final mentionJson = json['mention'] as Map<String, dynamic>?; // server key
    final rawMention = mentionInfoJson ?? mentionJson;
    if (rawMention != null) {
      _mentionInfo = MentionInfo.fromJson(rawMention);
    }

    return this;
  }

  /// Create a copy with updated content and adjusted entities
  WKMentionTextContent copyWithContent(String newContent) {
    final newMentionContent = WKMentionTextContent(newContent);
    newMentionContent._mentionEntities = List.from(_mentionEntities);
    newMentionContent.mentionAll = mentionAll;
    newMentionContent._updateMentionInfo();
    newMentionContent.validateEntities();
    return newMentionContent;
  }

  @override
  String toString() {
    return 'WKMentionTextContent(content: $content, entities: ${_mentionEntities.length}, mentionAll: $mentionAll)';
  }
}
