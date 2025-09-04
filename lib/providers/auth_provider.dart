import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/type/const.dart' as wk_types;
import '../models/user_model.dart';
import '../models/login_models.dart';
import '../services/login_service.dart';
import '../services/attachment_uploader.dart';
import '../config/constants.dart';

/// Login provider that manages all authentication state and flows
/// Replicates the functionality from Android LoginPresenter.java
class LoginProvider extends ChangeNotifier {
  final LoginService _loginService = LoginService();

  // User state
  UserInfoEntity? _currentUser;
  bool _isLoading = false;
  String _error = '';
  bool _isInitialized = false; // Track if initial load is complete

  // Country codes
  List<CountryCodeEntity> _countries = [];
  bool _isLoadingCountries = false;

  // Registration state
  bool _isRegistering = false;
  String _registrationError = '';

  // Device lock authentication state
  bool _isDeviceLockRequired = false;
  String? _deviceLockUid;
  String? _deviceLockPhone;

  // Third-party login state
  bool _isThirdPartyLogin = false;
  String? _authCode;

  // App configuration
  WKAPPConfig? _appConfig;

  // Getters
  UserInfoEntity? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  String get error => _error;

  List<CountryCodeEntity> get countries => _countries;
  bool get isLoadingCountries => _isLoadingCountries;

  bool get isRegistering => _isRegistering;
  String get registrationError => _registrationError;

  bool get isDeviceLockRequired => _isDeviceLockRequired;
  String? get deviceLockUid => _deviceLockUid;
  String? get deviceLockPhone => _deviceLockPhone;

  bool get isThirdPartyLogin => _isThirdPartyLogin;
  String? get authCode => _authCode;

  WKAPPConfig? get appConfig => _appConfig;

  LoginProvider() {
    _loginService.initialize();
    _loadCurrentUser();
  }

  /// Load current user from local storage
  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await _loginService.getCurrentUser();
    } catch (e) {
      // Ignore errors during initialization
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Clear error messages
  void clearError() {
    _error = '';
    _registrationError = '';
    notifyListeners();
  }

  /// Login with username and password
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = '';
    _isDeviceLockRequired = false;
    notifyListeners();

    try {
      final result = await _loginService.login(username, password);

      if (result.isSuccess && result.userInfo != null) {
        _currentUser = result.userInfo;
        // Ensure user info is saved to local storage
        await _loginService.saveUserInfo(result.userInfo!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else if (result.isDeviceLockRequired && result.userInfo != null) {
        // Handle device lock requirement
        _isDeviceLockRequired = true;
        _deviceLockUid = result.userInfo!.uid;
        _deviceLockPhone = result.userInfo!.phone;
        _error = 'Device verification required';
        _isLoading = false;
        notifyListeners();
        return false;
      } else {
        _error = result.errorMessage ?? ErrorMessages.loginFailed;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '${ErrorMessages.networkError}: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load countries list for phone registration
  Future<void> loadCountries() async {
    if (_countries.isNotEmpty) return; // Already loaded

    _isLoadingCountries = true;
    notifyListeners();

    try {
      _countries = await _loginService.getCountries();
      _isLoadingCountries = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load countries: ${e.toString()}';
      _isLoadingCountries = false;
      notifyListeners();
    }
  }

  /// Register new user
  Future<bool> register({
    required String code,
    required String zone,
    required String name,
    required String phone,
    required String password,
    String inviteCode = '',
  }) async {
    _isRegistering = true;
    _registrationError = '';
    notifyListeners();

    try {
      final result = await _loginService.register(
        code,
        zone,
        name,
        phone,
        password,
        inviteCode,
      );

      if (result.isSuccess && result.userInfo != null) {
        _currentUser = result.userInfo;
        _isRegistering = false;
        notifyListeners();
        return true;
      } else {
        _registrationError =
            result.errorMessage ?? ErrorMessages.registerFailed;
        _isRegistering = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _registrationError = '${ErrorMessages.networkError}: ${e.toString()}';
      _isRegistering = false;
      notifyListeners();
      return false;
    }
  }

  /// Send SMS verification code for registration
  Future<bool> sendRegisterCode(String zone, String phone) async {
    try {
      final result = await _loginService.registerCode(zone, phone);
      return result.exist != null;
    } catch (e) {
      _error = 'Failed to send verification code: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Send SMS verification code for password reset
  Future<bool> sendForgetPasswordCode(String zone, String phone) async {
    try {
      final result = await _loginService.forgetPwd(zone, phone);
      return result.status == HttpResponseCode.success;
    } catch (e) {
      _error = 'Failed to send verification code: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Reset password with verification code
  Future<bool> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final result = await _loginService.pwdForget(
        zone,
        phone,
        code,
        newPassword,
      );
      _isLoading = false;

      if (result.status == HttpResponseCode.success) {
        notifyListeners();
        return true;
      } else {
        _error = result.msg ?? 'Password reset failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '${ErrorMessages.networkError}: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send device lock verification code
  Future<bool> sendDeviceLockCode() async {
    if (_deviceLockUid == null) return false;

    try {
      final result = await _loginService.sendLoginAuthVerifCode(
        _deviceLockUid!,
      );
      return result.status == HttpResponseCode.success;
    } catch (e) {
      _error = 'Failed to send verification code: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Verify device lock with SMS code
  Future<bool> verifyDeviceLock(String code) async {
    if (_deviceLockUid == null) return false;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final result = await _loginService.checkLoginAuth(_deviceLockUid!, code);

      if (result.isSuccess && result.userInfo != null) {
        _currentUser = result.userInfo;
        _isDeviceLockRequired = false;
        _deviceLockUid = null;
        _deviceLockPhone = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.errorMessage ?? 'Device verification failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '${ErrorMessages.networkError}: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Start third-party login (QR code)
  Future<bool> startThirdPartyLogin() async {
    _isThirdPartyLogin = true;
    _error = '';
    notifyListeners();

    try {
      final result = await _loginService.getAuthCode();
      _authCode = result.authcode;
      notifyListeners();
      return _authCode != null && _authCode!.isNotEmpty;
    } catch (e) {
      _error = 'Failed to get auth code: ${e.toString()}';
      _isThirdPartyLogin = false;
      notifyListeners();
      return false;
    }
  }

  /// Check third-party login status
  Future<bool> checkThirdPartyLoginStatus() async {
    if (_authCode == null) return false;

    try {
      final result = await _loginService.getAuthStatus(_authCode!);

      if (result.status == 1) {
        // Login successful
        _currentUser = await _loginService.getCurrentUser();
        _isThirdPartyLogin = false;
        _authCode = null;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Update user information
  Future<bool> updateUserInfo(String key, String value) async {
    try {
      final result = await _loginService.updateUserInfo(key, value);

      if (result.status == HttpResponseCode.success) {
        // Update local user info
        if (_currentUser != null) {
          switch (key) {
            case 'name':
              _currentUser = _currentUser!.copyWith(name: value);
              break;
            case 'sex':
              _currentUser = _currentUser!.copyWith(sex: int.tryParse(value));
              break;
            case 'short_no':
              _currentUser = _currentUser!.copyWith(
                shortNo: value,
                shortStatus: 1, // Mark as set (matches Android logic)
              );
              break;
            // Add other fields as needed
          }
          // Save updated user info to local storage
          await _loginService.saveUserInfo(_currentUser!);
          notifyListeners();
        }
        return true;
      } else {
        _error = result.msg ?? 'Update failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '${ErrorMessages.networkError}: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Upload and update the current user's avatar to mirror Android behavior
  /// 1) POST multipart 'file' to /users/{uid}/avatar?uuid=ts
  /// 2) Update WKChannel avatarCacheKey via SDK to bust caches
  /// 3) Update local user.avatar to WKApiConfig.getAvatarUrl(uid)?key=cacheKey
  Future<bool> uploadAvatar(String localPath) async {
    try {
      print('🎭 AVATAR UPLOAD: Starting upload process');

      if (_currentUser?.uid == null || _currentUser!.uid!.isEmpty) {
        print('🎭 AVATAR UPLOAD: ❌ User not logged in');
        _error = 'User not logged in';
        notifyListeners();
        return false;
      }

      final uid = _currentUser!.uid!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final uploadUrl = '${WKApiConfig.baseUrl}users/$uid/avatar?uuid=$ts';

      print('🎭 AVATAR UPLOAD: UID: $uid');
      print('🎭 AVATAR UPLOAD: Upload URL: $uploadUrl');
      print('🎭 AVATAR UPLOAD: Local file path: $localPath');

      final uploadedPath = await AttachmentUploader().upload(
        uploadUrl,
        localPath,
      );

      print('🎭 AVATAR UPLOAD: Upload result path: $uploadedPath');

      if (uploadedPath == null || uploadedPath.isEmpty) {
        print('🎭 AVATAR UPLOAD: ❌ Upload failed - no path returned');
        _error = 'Failed to upload avatar';
        notifyListeners();
        return false;
      }

      // Check if upload was successful but server didn't return actual path
      bool uploadSuccess = uploadedPath == 'SUCCESS' || uploadedPath.isNotEmpty;
      if (!uploadSuccess) {
        print('🎭 AVATAR UPLOAD: ❌ Upload failed - invalid response');
        _error = 'Failed to upload avatar';
        notifyListeners();
        return false;
      }

      print(
        '🎭 AVATAR UPLOAD: ✅ Upload successful, proceeding with cache update',
      );

      // Update avatar cache key in SDK so all avatar widgets refresh like Android
      final cacheKey = DateTime.now().microsecondsSinceEpoch.toString();
      print('🎭 AVATAR UPLOAD: Generated cache key: $cacheKey');

      await WKIM.shared.channelManager.updateAvatarCacheKey(
        uid,
        wk_types.WKChannelType.personal,
        cacheKey,
      );
      print('🎭 AVATAR UPLOAD: ✅ Updated SDK avatar cache key');

      // Update local user info avatar url to computed endpoint + cache key
      final newAvatarUrl = '${WKApiConfig.getAvatarUrl(uid)}?key=$cacheKey';
      print('🎭 AVATAR UPLOAD: New avatar URL: $newAvatarUrl');

      _currentUser = _currentUser!.copyWith(avatar: newAvatarUrl);
      await _loginService.saveUserInfo(_currentUser!);
      notifyListeners();

      print('🎭 AVATAR UPLOAD: ✅ Upload completed successfully');
      return true;
    } catch (e, stackTrace) {
      print('🎭 AVATAR UPLOAD: ❌ Exception occurred: $e');
      print('🎭 AVATAR UPLOAD: ❌ Stack trace: $stackTrace');
      _error = '${ErrorMessages.networkError}: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> updateUserSettingLocal(String key, bool value) async {
    if (_currentUser == null) return;

    final current = _currentUser!;
    final setting = current.setting;

    final updated = UserInfoSetting(
      searchByPhone: setting?.searchByPhone,
      searchByShort: setting?.searchByShort,
      newMsgNotice: key == 'new_msg_notice'
          ? (value ? 1 : 0)
          : (setting?.newMsgNotice ?? 1),
      msgShowDetail: key == 'msg_show_detail'
          ? (value ? 1 : 0)
          : (setting?.msgShowDetail ?? 1),
      voiceOn: key == 'voice_on' ? (value ? 1 : 0) : (setting?.voiceOn ?? 1),
      shockOn: key == 'shock_on' ? (value ? 1 : 0) : (setting?.shockOn ?? 1),
      deviceLock: setting?.deviceLock,
      offlineProtection: setting?.offlineProtection,
    );

    _currentUser = current.copyWith(setting: updated);
    await _loginService.saveUserInfo(_currentUser!);
    notifyListeners();
  }

  /// Save last login info for auto-fill
  Future<void> saveLastLoginInfo(String phone, String zone) async {
    try {
      await _loginService.saveLastLoginInfo(phone, zone);
    } catch (e) {
      // Silently fail - this is not critical functionality
    }
  }

  /// Get last login info for auto-fill
  Future<Map<String, String?>> getLastLoginInfo() async {
    try {
      return await _loginService.getLastLoginInfo();
    } catch (e) {
      return {'phone': null, 'zone': null};
    }
  }

  /// Update base API URL
  Future<void> updateBaseUrl(String url) async {
    try {
      await _loginService.updateBaseUrl(url);
    } catch (e) {
      _error = 'Failed to update base URL: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _loginService.clearUserSession();
      _currentUser = null;
      _error = '';
      _isDeviceLockRequired = false;
      _deviceLockUid = null;
      _deviceLockPhone = null;
      _isThirdPartyLogin = false;
      _authCode = null;
      notifyListeners();
    } catch (e) {
      // Even if clearing fails, reset local state
      _currentUser = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _loginService.dispose();
    super.dispose();
  }
}
