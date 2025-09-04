/// Mention entity model for @ mentions functionality
/// Based on Android source analysis from chat-mentions.md
class MentionEntity {
  final String type; // "mention"
  final String value; // User ID thực
  final int offset; // Vị trí bắt đầu trong text
  final int length; // Độ dài text "@username"
  final String displayName; // Tên hiển thị (@username)

  const MentionEntity({
    required this.type,
    required this.value,
    required this.offset,
    required this.length,
    required this.displayName,
  });

  /// Create mention entity with default type
  factory MentionEntity.mention({
    required String userId,
    required int offset,
    required int length,
    required String displayName,
  }) {
    return MentionEntity(
      type: 'mention',
      value: userId,
      offset: offset,
      length: length,
      displayName: displayName,
    );
  }

  /// Convert to JSON for server payload (excludes displayName)
  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'offset': offset,
    'length': length,
  };

  /// Create from JSON
  factory MentionEntity.fromJson(Map<String, dynamic> json) {
    return MentionEntity(
      type: json['type'] ?? 'mention',
      value: json['value'] ?? '',
      offset: json['offset'] ?? 0,
      length: json['length'] ?? 0,
      displayName: json['displayName'] ?? '', // This won't be in server JSON
    );
  }

  /// Create copy with updated fields
  MentionEntity copyWith({
    String? type,
    String? value,
    int? offset,
    int? length,
    String? displayName,
  }) {
    return MentionEntity(
      type: type ?? this.type,
      value: value ?? this.value,
      offset: offset ?? this.offset,
      length: length ?? this.length,
      displayName: displayName ?? this.displayName,
    );
  }

  /// Check if this entity contains the given position
  bool containsPosition(int position) {
    return position >= offset && position < offset + length;
  }

  /// Check if this entity overlaps with another entity
  bool overlapsWith(MentionEntity other) {
    return !(offset + length <= other.offset ||
        other.offset + other.length <= offset);
  }

  @override
  String toString() {
    return 'MentionEntity(type: $type, value: $value, offset: $offset, length: $length, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MentionEntity &&
        other.type == type &&
        other.value == value &&
        other.offset == offset &&
        other.length == length &&
        other.displayName == displayName;
  }

  @override
  int get hashCode {
    return type.hashCode ^
        value.hashCode ^
        offset.hashCode ^
        length.hashCode ^
        displayName.hashCode;
  }
}

/// Mention info for server payload
/// Contains list of mentioned user IDs
class MentionInfo {
  final List<String> uids;

  const MentionInfo({required this.uids});

  /// Create from list of mention entities
  factory MentionInfo.fromEntities(List<MentionEntity> entities) {
    final uids = entities.map((e) => e.value).toSet().toList();
    return MentionInfo(uids: uids);
  }

  /// Convert to JSON for server payload
  Map<String, dynamic> toJson() => {'uids': uids};

  /// Create from JSON
  factory MentionInfo.fromJson(Map<String, dynamic> json) {
    final uidsJson = json['uids'] as List<dynamic>?;
    final uids = uidsJson?.map((e) => e.toString()).toList() ?? <String>[];
    return MentionInfo(uids: uids);
  }

  /// Check if contains user ID
  bool containsUser(String userId) {
    return uids.contains(userId);
  }

  /// Add user ID if not already present
  MentionInfo addUser(String userId) {
    if (uids.contains(userId)) return this;
    return MentionInfo(uids: [...uids, userId]);
  }

  /// Remove user ID
  MentionInfo removeUser(String userId) {
    return MentionInfo(uids: uids.where((uid) => uid != userId).toList());
  }

  @override
  String toString() {
    return 'MentionInfo(uids: $uids)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MentionInfo &&
        other.uids.length == uids.length &&
        other.uids.every((uid) => uids.contains(uid));
  }

  @override
  int get hashCode {
    return uids.fold(0, (prev, uid) => prev ^ uid.hashCode);
  }
}
