import 'user_model.dart';

/// Search user result entity
/// Replicates Android SearchUserEntity.java
class SearchUserEntity {
  /// Whether user exists (1 = exists, 0 = not found)
  final int exist;

  /// Whether to show apply/add friend button
  final bool showApply;

  /// User information (null if user not found)
  final ContactCardUserInfo? data;

  /// Friend request status (0 = none, 1 = pending, 2 = accepted)
  final int status;

  SearchUserEntity({
    required this.exist,
    this.showApply = true,
    this.data,
    this.status = 0,
  });

  factory SearchUserEntity.fromJson(Map<String, dynamic> json) {
    return SearchUserEntity(
      exist: json['exist'] ?? 0,
      showApply: json['show_apply'] ?? true,
      data: json['data'] != null
          ? ContactCardUserInfo.fromJson(json['data'])
          : null,
      status: json['status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exist': exist,
      'show_apply': showApply,
      'data': data?.toJson(),
      'status': status,
    };
  }

  /// Create "not found" search result
  factory SearchUserEntity.notFound() {
    return SearchUserEntity(exist: 0, showApply: false, data: null, status: 0);
  }

  /// Create "found" search result
  factory SearchUserEntity.found(
    ContactCardUserInfo userData, {
    bool showApply = true,
  }) {
    return SearchUserEntity(
      exist: 1,
      showApply: showApply,
      data: userData,
      status: 0,
    );
  }

  /// Whether user was found
  bool get isUserFound => exist == 1 && data != null;

  /// Whether user is not found
  bool get isUserNotFound => exist == 0 || data == null;
}

/// API response wrapper for search user
class SearchUserResponse {
  final bool success;
  final String message;
  final SearchUserEntity? result;

  SearchUserResponse({
    required this.success,
    required this.message,
    this.result,
  });

  factory SearchUserResponse.success(SearchUserEntity result) {
    return SearchUserResponse(
      success: true,
      message: 'Search completed successfully',
      result: result,
    );
  }

  factory SearchUserResponse.error(String message) {
    return SearchUserResponse(success: false, message: message, result: null);
  }
}
