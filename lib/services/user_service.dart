import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../utils/logger.dart';
import '../models/user_model.dart';
import '../models/search_user_model.dart';

/// User service that handles all user-related API calls
/// Based on Android UserService.java and UserModel.java
class UserService {
  UserService._();
  static final UserService _instance = UserService._();
  factory UserService() => _instance;

  /// Create Dio instance with proper authentication headers
  Future<Dio?> _createDio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(WKConstants.tokenKey) ?? '';

      if (token.isEmpty) {
        Logger.warning('UserService: Missing token for API call');
        return null;
      }

      final dio = Dio();
      final base = WKApiConfig.baseUrl.isNotEmpty
          ? WKApiConfig.baseUrl
          : '${WKApiConfig.defaultBaseUrl}/v1/';

      dio.options.baseUrl = base;
      dio.options.headers = {
        'Content-Type': 'application/json',
        'token': token,
        'package': 'com.test.demo',
        'os': 'iOS',
        'appid': 'wukongchat',
        'model': 'flutter_app',
        'version': '1.0',
      };

      return dio;
    } catch (e) {
      Logger.error('UserService: Failed to create Dio', error: e);
      return null;
    }
  }

  /// Get user information
  /// GET /users/{uid}?group_no={groupNo}
  Future<UserInfoResponse> getUserInfo(String uid, {String? groupNo}) async {
    try {
      final dio = await _createDio();
      if (dio == null) {
        return UserInfoResponse.error('Failed to create HTTP client');
      }

      final queryParams = <String, dynamic>{};
      if (groupNo != null && groupNo.isNotEmpty) {
        queryParams['group_no'] = groupNo;
      }

      Logger.service(
        'UserService',
        'Getting user info for uid: $uid, groupNo: $groupNo',
      );

      final response = await dio.get(
        '/users/$uid',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final userInfo = ContactCardUserInfo.fromJson(response.data);
        return UserInfoResponse.success(userInfo);
      } else {
        return UserInfoResponse.error(
          'Failed to get user info: ${response.statusCode}',
        );
      }
    } catch (e) {
      Logger.error('UserService: Failed to get user info', error: e);
      return UserInfoResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Update user remark (friend nickname)
  /// PUT /friend/remark
  Future<ApiResponse> updateUserRemark(String uid, String remark) async {
    try {
      final dio = await _createDio();
      if (dio == null) {
        return ApiResponse.error('Failed to create HTTP client');
      }

      final requestBody = {'uid': uid, 'remark': remark};

      Logger.service(
        'UserService',
        'Updating remark for uid: $uid, remark: $remark',
      );

      final response = await dio.put('/friend/remark', data: requestBody);

      if (response.statusCode == 200) {
        return ApiResponse.success('Remark updated successfully');
      } else {
        final errorMsg = response.data?['msg'] ?? 'Failed to update remark';
        return ApiResponse.error(errorMsg);
      }
    } catch (e) {
      Logger.error('UserService: Failed to update remark', error: e);
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Add user to blacklist
  /// POST /user/blacklist/{uid}
  Future<ApiResponse> addBlackList(String uid) async {
    try {
      final dio = await _createDio();
      if (dio == null) {
        return ApiResponse.error('Failed to create HTTP client');
      }

      Logger.service('UserService', 'Adding user to blacklist: $uid');

      final response = await dio.post('/user/blacklist/$uid');

      if (response.statusCode == 200) {
        return ApiResponse.success('User added to blacklist');
      } else {
        final errorMsg = response.data?['msg'] ?? 'Failed to add to blacklist';
        return ApiResponse.error(errorMsg);
      }
    } catch (e) {
      Logger.error('UserService: Failed to add to blacklist', error: e);
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Remove user from blacklist
  /// DELETE /user/blacklist/{uid}
  Future<ApiResponse> removeBlackList(String uid) async {
    try {
      final dio = await _createDio();
      if (dio == null) {
        return ApiResponse.error('Failed to create HTTP client');
      }

      Logger.service('UserService', 'Removing user from blacklist: $uid');

      final response = await dio.delete('/user/blacklist/$uid');

      if (response.statusCode == 200) {
        return ApiResponse.success('User removed from blacklist');
      } else {
        final errorMsg =
            response.data?['msg'] ?? 'Failed to remove from blacklist';
        return ApiResponse.error(errorMsg);
      }
    } catch (e) {
      Logger.error('UserService: Failed to remove from blacklist', error: e);
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Search user by phone number or App ID
  /// GET /user/search?keyword={keyword}
  /// Matches Android SearchService.searchUser()
  Future<SearchUserResponse> searchUser(String keyword) async {
    try {
      final dio = await _createDio();
      if (dio == null) {
        return SearchUserResponse.error('Failed to create HTTP client');
      }

      if (keyword.trim().isEmpty) {
        return SearchUserResponse.error('Search keyword cannot be empty');
      }

      Logger.service('UserService', 'Searching user with keyword: $keyword');

      final response = await dio.get(
        '/user/search',
        queryParameters: {'keyword': keyword.trim()},
      );

      if (response.statusCode == 200) {
        final searchResult = SearchUserEntity.fromJson(response.data);

        // Check if user is already a friend (like Android logic)
        if (searchResult.isUserFound && searchResult.data != null) {
          // In Android, they check: channel.follow == 1 && channel.isDeleted == 0
          // For now, we'll use the follow field from the API response
          final isAlreadyFriend = searchResult.data!.follow == 1;

          final updatedResult = SearchUserEntity(
            exist: searchResult.exist,
            showApply:
                !isAlreadyFriend, // Don't show "Add Friend" if already friends
            data: searchResult.data,
            status: searchResult.status,
          );

          return SearchUserResponse.success(updatedResult);
        }

        return SearchUserResponse.success(searchResult);
      } else {
        return SearchUserResponse.error(
          'Search failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      Logger.error('UserService: Failed to search user', error: e);
      return SearchUserResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Apply to add friend
  /// POST /friend/apply
  Future<ApiResponse> applyAddFriend(
    String uid, {
    String? vercode,
    String? remark,
  }) async {
    try {
      final dio = await _createDio();
      if (dio == null) {
        return ApiResponse.error('Failed to create HTTP client');
      }

      final requestBody = <String, dynamic>{'to_uid': uid};

      if (vercode != null && vercode.isNotEmpty) {
        requestBody['vercode'] = vercode;
      }

      if (remark != null && remark.isNotEmpty) {
        requestBody['remark'] = remark;
      }

      Logger.service('UserService', 'Applying to add friend: $uid');
      Logger.service('UserService', 'Request body: $requestBody');

      final response = await dio.post('/friend/apply', data: requestBody);

      Logger.service('UserService', 'Response status: ${response.statusCode}');
      Logger.service('UserService', 'Response data: ${response.data}');

      if (response.statusCode == 200) {
        return ApiResponse.success('Friend request sent', data: response.data);
      } else {
        final errorMsg =
            response.data?['msg'] ?? 'Failed to send friend request';
        Logger.service('UserService', 'Error response: $errorMsg');
        return ApiResponse.error(errorMsg, data: response.data);
      }
    } catch (e) {
      Logger.error('UserService: Failed to apply add friend', error: e);
      
      // Enhanced error logging for DioException
      if (e.toString().contains('DioException')) {
        final dioError = e as DioException;
        Logger.error('UserService: DioException details', error: {
          'type': dioError.type.toString(),
          'message': dioError.message,
          'response': dioError.response?.data,
          'statusCode': dioError.response?.statusCode,
          'requestData': dioError.requestOptions.data,
          'requestPath': dioError.requestOptions.path,
          'requestMethod': dioError.requestOptions.method,
        });
        
        final errorDetails = dioError.response?.data;
        if (errorDetails != null && errorDetails is Map) {
          final errorMsg = errorDetails['msg'] ?? errorDetails['message'] ?? 'Unknown server error';
          return ApiResponse.error('Server error: $errorMsg', data: errorDetails);
        }
      }
      
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Delete friend
  /// DELETE /friends/{uid}
  Future<ApiResponse> deleteFriend(String uid) async {
    try {
      final dio = await _createDio();
      if (dio == null) {
        return ApiResponse.error('Failed to create HTTP client');
      }

      Logger.service('UserService', 'Deleting friend: $uid');

      final response = await dio.delete('/friends/$uid');

      if (response.statusCode == 200) {
        return ApiResponse.success('Friend deleted successfully');
      } else {
        final errorMsg = response.data?['msg'] ?? 'Failed to delete friend';
        return ApiResponse.error(errorMsg);
      }
    } catch (e) {
      Logger.error('UserService: Failed to delete friend', error: e);
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }
}

/// Response wrapper for user info API calls
class UserInfoResponse {
  final bool isSuccess;
  final String message;
  final ContactCardUserInfo? userInfo;

  UserInfoResponse._({
    required this.isSuccess,
    required this.message,
    this.userInfo,
  });

  factory UserInfoResponse.success(ContactCardUserInfo userInfo) {
    return UserInfoResponse._(
      isSuccess: true,
      message: 'Success',
      userInfo: userInfo,
    );
  }

  factory UserInfoResponse.error(String message) {
    return UserInfoResponse._(isSuccess: false, message: message);
  }
}

/// Generic API response wrapper
class ApiResponse {
  final bool isSuccess;
  final String message;
  final dynamic data; // optional raw data payload

  ApiResponse._({required this.isSuccess, required this.message, this.data});

  factory ApiResponse.success(String message, {dynamic data}) {
    return ApiResponse._(isSuccess: true, message: message, data: data);
  }

  factory ApiResponse.error(String message, {dynamic data}) {
    return ApiResponse._(isSuccess: false, message: message, data: data);
  }
}
