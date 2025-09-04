import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../models/login_models.dart';
import '../config/constants.dart';

/// Login service that handles all authentication-related API calls
/// Replicates the functionality from Android LoginService.java and LoginModel.java
class LoginService {
  static final LoginService _instance = LoginService._internal();
  factory LoginService() => _instance;
  LoginService._internal();

  late http.Client _client;

  void initialize() {
    _client = http.Client();
    _initializeApiUrl();
  }

  void _initializeApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? apiUrl = prefs.getString(WKConstants.apiBaseUrlKey);

    if (apiUrl == null || apiUrl.isEmpty) {
      apiUrl = WKApiConfig.defaultBaseUrl;
      WKApiConfig.initBaseURL(apiUrl);
    } else {
      WKApiConfig.initBaseURLIncludeIP(apiUrl);
    }
  }

  /// Get device information for login requests
  Future<DeviceInfo> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return DeviceInfo(
        deviceId: WKConstants.getDeviceID(),
        deviceName: androidInfo.model,
        deviceModel: '${androidInfo.brand} ${androidInfo.model}',
      );
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return DeviceInfo(
        deviceId: WKConstants.getDeviceID(),
        deviceName: iosInfo.name,
        deviceModel: iosInfo.model,
      );
    } else {
      return DeviceInfo(
        deviceId: WKConstants.getDeviceID(),
        deviceName: 'Unknown Device',
        deviceModel: 'Unknown Model',
      );
    }
  }

  /// Login with username and password
  /// POST /user/login
  Future<LoginResult> login(String username, String password) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final requestBody = {
        'username': username,
        'password': password,
        'device': deviceInfo.toJson(),
      };

      final response = await _client.post(
        Uri.parse('${WKApiConfig.baseUrl}user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final userInfo = UserInfoEntity.fromJson(jsonDecode(response.body));
        await _saveLoginInfo(userInfo);
        return LoginResult.success(userInfo);
      } else {
        final errorData = jsonDecode(response.body);

        // Handle device lock error (code 110)
        if (response.statusCode == HttpResponseCode.deviceLockRequired) {
          final userInfo = UserInfoEntity(
            phone: errorData['phone'],
            uid: errorData['uid'],
          );
          return LoginResult.deviceLockRequired(userInfo);
        }

        return LoginResult.error(
          response.statusCode,
          errorData['msg'] ?? 'Login failed',
        );
      }
    } catch (e) {
      return LoginResult.error(
        HttpResponseCode.error,
        'Network error: ${e.toString()}',
      );
    }
  }

  /// Web login confirmation
  /// GET /user/grant_login
  Future<CommonResponse> webLoginConfirm(String authCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(WKConstants.tokenKey);
      if (token == null || token.isEmpty) {
        return CommonResponse(
          status: HttpResponseCode.error,
          msg: 'Token not found. Please login first.',
        );
      }

      final headers = {
        'Content-Type': 'application/json',
        'token': token,
        'package': AppInfo.packageName,
        'os': Platform.isIOS ? 'iOS' : 'Android',
        'appid': 'wukongchat',
        'model': 'flutter_app',
        'version': '1.0',
      };

      final response = await _client.get(
        Uri.parse('${WKApiConfig.baseUrl}user/grant_login?auth_code=$authCode'),
        headers: headers,
      );

      return CommonResponse.fromJson(jsonDecode(response.body));
    } catch (e) {
      return CommonResponse(
        status: HttpResponseCode.error,
        msg: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Get list of countries with country codes
  /// GET /common/countries
  Future<List<CountryCodeEntity>> getCountries() async {
    try {
      final response = await _client.get(
        Uri.parse('${WKApiConfig.baseUrl}common/countries'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CountryCodeEntity.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load countries');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Send SMS verification code for registration
  /// POST /user/sms/registercode
  Future<VerfiCodeResult> registerCode(String zone, String phone) async {
    try {
      final requestBody = {'zone': zone, 'phone': phone};

      final response = await _client.post(
        Uri.parse('${WKApiConfig.baseUrl}user/sms/registercode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return VerfiCodeResult.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['msg'] ?? 'Failed to send verification code');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Send SMS verification code for password reset
  /// POST /user/sms/forgetpwd
  Future<CommonResponse> forgetPwd(String zone, String phone) async {
    try {
      final requestBody = {'zone': zone, 'phone': phone};

      final response = await _client.post(
        Uri.parse('${WKApiConfig.baseUrl}user/sms/forgetpwd'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      return CommonResponse.fromJson(jsonDecode(response.body));
    } catch (e) {
      return CommonResponse(
        status: HttpResponseCode.error,
        msg: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Reset password with verification code
  /// POST /user/pwdforget
  Future<CommonResponse> pwdForget(
    String zone,
    String phone,
    String code,
    String pwd,
  ) async {
    try {
      final requestBody = {
        'zone': zone,
        'phone': phone,
        'code': code,
        'pwd': pwd,
      };

      final response = await _client.post(
        Uri.parse('${WKApiConfig.baseUrl}user/pwdforget'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      return CommonResponse.fromJson(jsonDecode(response.body));
    } catch (e) {
      return CommonResponse(
        status: HttpResponseCode.error,
        msg: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Save login information to local storage (public method)
  Future<void> saveUserInfo(UserInfoEntity userInfo) async {
    await _saveLoginInfo(userInfo);
  }

  /// Save login information to local storage
  Future<void> _saveLoginInfo(UserInfoEntity userInfo) async {
    final prefs = await SharedPreferences.getInstance();

    // Save user info
    await prefs.setString(
      WKConstants.userInfoKey,
      jsonEncode(userInfo.toJson()),
    );

    // Save tokens and user data
    if (userInfo.token != null) {
      await prefs.setString(WKConstants.tokenKey, userInfo.token!);
    }

    if (userInfo.imToken != null) {
      await prefs.setString(WKConstants.imTokenKey, userInfo.imToken!);
    } else if (userInfo.token != null) {
      await prefs.setString(WKConstants.imTokenKey, userInfo.token!);
    }

    if (userInfo.uid != null) {
      await prefs.setString(WKConstants.uidKey, userInfo.uid!);
    }

    if (userInfo.name != null) {
      await prefs.setString(WKConstants.userNameKey, userInfo.name!);
    }
  }

  /// Register new user
  /// POST /user/register
  Future<LoginResult> register(
    String code,
    String zone,
    String name,
    String phone,
    String password,
    String inviteCode,
  ) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final requestBody = {
        'code': code,
        'zone': zone,
        'name': name,
        'phone': phone,
        'password': password,
        'invite_code': inviteCode,
        'device': deviceInfo.toJson(),
      };

      final response = await _client.post(
        Uri.parse('${WKApiConfig.baseUrl}user/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final userInfo = UserInfoEntity.fromJson(jsonDecode(response.body));
        await _saveLoginInfo(userInfo);
        return LoginResult.success(userInfo);
      } else {
        final errorData = jsonDecode(response.body);
        return LoginResult.error(
          response.statusCode,
          errorData['msg'] ?? 'Registration failed',
        );
      }
    } catch (e) {
      return LoginResult.error(
        HttpResponseCode.error,
        'Network error: ${e.toString()}',
      );
    }
  }

  /// Update user information
  /// PUT /user/current
  Future<CommonResponse> updateUserInfo(String key, String value) async {
    try {
      print('🔍 UPDATE USER INFO DEBUG: Starting update for $key = $value');

      // Get authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(WKConstants.tokenKey);

      if (token == null) {
        print('🔍 UPDATE USER INFO DEBUG: ❌ No token found');
        return CommonResponse(
          status: HttpResponseCode.error,
          msg: 'Authentication token not found',
        );
      }

      final requestBody = {key: value};
      final url = '${WKApiConfig.baseUrl}user/current';
      final headers = {
        'Content-Type': 'application/json',
        'token': token,
        'package': 'com.test.demo',
        'os': 'iOS',
        'appid': 'wukongchat',
        'model': 'flutter_app',
        'version': '1.0',
      };

      print('🔍 UPDATE USER INFO DEBUG: URL: $url');
      print('🔍 UPDATE USER INFO DEBUG: Headers: $headers');
      print('🔍 UPDATE USER INFO DEBUG: Body: ${jsonEncode(requestBody)}');

      final response = await _client.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print(
        '🔍 UPDATE USER INFO DEBUG: Response status: ${response.statusCode}',
      );
      print('🔍 UPDATE USER INFO DEBUG: Response body: ${response.body}');

      final result = CommonResponse.fromJson(jsonDecode(response.body));
      print(
        '🔍 UPDATE USER INFO DEBUG: Parsed result: status=${result.status}, msg=${result.msg}',
      );

      return result;
    } catch (e) {
      print('🔍 UPDATE USER INFO DEBUG: ❌ Exception: $e');
      return CommonResponse(
        status: HttpResponseCode.error,
        msg: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Send login authentication verification code (for device lock)
  /// POST /user/sms/login_check_phone
  Future<CommonResponse> sendLoginAuthVerifCode(String uid) async {
    try {
      final requestBody = {'uid': uid};

      final response = await _client.post(
        Uri.parse('${WKApiConfig.baseUrl}user/sms/login_check_phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      return CommonResponse.fromJson(jsonDecode(response.body));
    } catch (e) {
      return CommonResponse(
        status: HttpResponseCode.error,
        msg: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Check login authentication (device lock verification)
  /// POST /user/login/check_phone
  Future<LoginResult> checkLoginAuth(String uid, String code) async {
    try {
      final requestBody = {'uid': uid, 'code': code};

      final response = await _client.post(
        Uri.parse('${WKApiConfig.baseUrl}user/login/check_phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final userInfo = UserInfoEntity.fromJson(jsonDecode(response.body));
        await _saveLoginInfo(userInfo);
        return LoginResult.success(userInfo);
      } else {
        final errorData = jsonDecode(response.body);
        return LoginResult.error(
          response.statusCode,
          errorData['msg'] ?? 'Authentication failed',
        );
      }
    } catch (e) {
      return LoginResult.error(
        HttpResponseCode.error,
        'Network error: ${e.toString()}',
      );
    }
  }

  /// Quit PC login
  /// POST /user/pc/quit
  Future<CommonResponse> quitPc() async {
    try {
      final response = await _client.post(
        Uri.parse('${WKApiConfig.baseUrl}user/pc/quit'),
        headers: {'Content-Type': 'application/json'},
      );

      return CommonResponse.fromJson(jsonDecode(response.body));
    } catch (e) {
      return CommonResponse(
        status: HttpResponseCode.error,
        msg: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Update user settings
  /// PUT /user/my/setting
  Future<CommonResponse> updateUserSetting(String key, int value) async {
    try {
      final requestBody = {key: value};

      final response = await _client.put(
        Uri.parse('${WKApiConfig.baseUrl}user/my/setting'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      return CommonResponse.fromJson(jsonDecode(response.body));
    } catch (e) {
      return CommonResponse(
        status: HttpResponseCode.error,
        msg: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Get third-party authentication code (for QR login)
  /// GET /user/thirdlogin/authcode
  Future<ThirdAuthCode> getAuthCode() async {
    try {
      final response = await _client.get(
        Uri.parse('${WKApiConfig.baseUrl}user/thirdlogin/authcode'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return ThirdAuthCode.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to get auth code');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Get user QR code data
  /// GET /user/qrcode
  Future<UserQr> getUserQrCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(WKConstants.tokenKey);

      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client.get(
        Uri.parse('${WKApiConfig.baseUrl}user/qrcode'),
        headers: {'Content-Type': 'application/json', 'token': token},
      );

      if (response.statusCode == 200) {
        return UserQr.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to get user QR code');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Get third-party authentication status
  /// GET /user/thirdlogin/authstatus
  Future<ThirdLoginResult> getAuthStatus(String authcode) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '${WKApiConfig.baseUrl}user/thirdlogin/authstatus?authcode=$authcode',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = ThirdLoginResult.fromJson(jsonDecode(response.body));

        // If login successful, save user info
        if (result.status == 1 && result.result != null) {
          final userInfo = UserInfoEntity.fromJson(result.result);
          await _saveLoginInfo(userInfo);
        }

        return result;
      } else {
        throw Exception('Failed to get auth status');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Get current user info from local storage
  Future<UserInfoEntity?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(WKConstants.userInfoKey);

      if (userJson != null) {
        return UserInfoEntity.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save last login info (phone and zone) for auto-fill
  Future<void> saveLastLoginInfo(String phone, String zone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WKConstants.lastLoginPhoneKey, phone);
    await prefs.setString(WKConstants.lastLoginZoneKey, zone);
  }

  /// Get last login info (phone and zone) for auto-fill
  Future<Map<String, String?>> getLastLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'phone': prefs.getString(WKConstants.lastLoginPhoneKey),
      'zone': prefs.getString(WKConstants.lastLoginZoneKey),
    };
  }

  /// Clear user session (but keep last login info for auto-fill)
  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(WKConstants.userInfoKey);
    await prefs.remove(WKConstants.tokenKey);
    await prefs.remove(WKConstants.imTokenKey);
    await prefs.remove(WKConstants.uidKey);
    await prefs.remove(WKConstants.userNameKey);
    // Note: We intentionally keep lastLoginPhoneKey and lastLoginZoneKey
    // for auto-fill functionality
  }

  /// Update base API URL
  Future<void> updateBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WKConstants.apiBaseUrlKey, url);
    WKApiConfig.initBaseURLIncludeIP(url);
  }

  void dispose() {
    _client.close();
  }
}

/// Login result wrapper to handle different response types
class LoginResult {
  final bool isSuccess;
  final UserInfoEntity? userInfo;
  final int? errorCode;
  final String? errorMessage;
  final bool isDeviceLockRequired;

  LoginResult._({
    required this.isSuccess,
    this.userInfo,
    this.errorCode,
    this.errorMessage,
    this.isDeviceLockRequired = false,
  });

  factory LoginResult.success(UserInfoEntity userInfo) {
    return LoginResult._(isSuccess: true, userInfo: userInfo);
  }

  factory LoginResult.error(int code, String message) {
    return LoginResult._(
      isSuccess: false,
      errorCode: code,
      errorMessage: message,
    );
  }

  factory LoginResult.deviceLockRequired(UserInfoEntity userInfo) {
    return LoginResult._(
      isSuccess: false,
      userInfo: userInfo,
      errorCode: HttpResponseCode.deviceLockRequired,
      isDeviceLockRequired: true,
    );
  }
}
