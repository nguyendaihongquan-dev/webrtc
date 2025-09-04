/// API configuration constants
class WKApiConfig {
  static String baseUrl = '';
  static String baseWebUrl = '';

  // Default base URL from Android source
  static const String defaultBaseUrl = 'http://45.204.13.113:8099';

  static void initBaseURL(String apiURL) {
    baseUrl = '$apiURL/v1/';
    baseWebUrl = '$apiURL/web/';
  }

  static void initBaseURLIncludeIP(String apiURL) {
    baseUrl = '$apiURL/v1/';
    baseWebUrl = '$apiURL/web/';
  }

  static String getAvatarUrl(String uid) {
    return '${baseUrl}users/$uid/avatar';
  }

  static String getGroupUrl(String groupId) {
    return '${baseUrl}groups/$groupId/avatar';
  }

  static String getShowUrl(String url) {
    if (url.isEmpty || url.startsWith('http') || url.startsWith('HTTP')) {
      return url;
    } else {
      return baseUrl + url;
    }
  }
}

/// Application constants
class WKConstants {
  static const String refreshContacts = 'refresh_contacts';

  // Notification channel IDs (Android)
  // Default: sound + vibration
  static const String newMsgChannelID = 'wk_new_msg_notification';
  // Sound only (no vibration)
  static const String newMsgChannelSoundOnlyID =
      'wk_new_msg_notification_sound_only';
  // Vibration only (no sound)
  static const String newMsgChannelVibrateOnlyID =
      'wk_new_msg_notification_vibrate_only';
  // Silent (no sound, no vibration)
  static const String newMsgChannelSilentID = 'wk_new_msg_notification_silent';

  static const String newRTCChannelID = 'wk_new_rtc_notification';

  // SharedPreferences keys
  static const String apiBaseUrlKey = 'api_base_url';
  static const String userInfoKey = 'user_info';
  static const String appConfigKey = 'app_config';
  static const String tokenKey = 'wk_token';
  static const String imTokenKey = 'wk_im_token';
  static const String uidKey = 'wk_uid';
  static const String userNameKey = 'wk_name';
  static const String keyboardHeightKey = 'keyboardHeight';
  static const String appModuleKey = 'app_module';

  // Last login info keys (persisted across logout)
  static const String lastLoginPhoneKey = 'last_login_phone';
  static const String lastLoginZoneKey = 'last_login_zone';

  // Device ID generation
  static String? _deviceId;

  static String getDeviceID() {
    _deviceId ??= _generateDeviceId();
    return _deviceId!;
  }

  static String _generateDeviceId() {
    // Generate a unique device ID - in real app this would be more sophisticated
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

/// System account constants
class WKSystemAccount {
  static const String systemTeam = 'u_10000';
  static const String systemFileHelper = 'fileHelper';
  static const String systemTeamShortNo = '10000';
  static const String systemFileHelperShortNo = '20000';
}

/// App information
class AppInfo {
  static const String appName = 'QGIM';
  static const String packageName = 'com.test.demo';
}

/// Login validation constants
class LoginValidation {
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 16;
  static const int chinesePhoneLength = 11;
  static const String defaultCountryCode = '0086';
}

/// Error messages
class ErrorMessages {
  static const String nameNotNull = 'Name cannot be empty';
  static const String pwdNotNull = 'Password cannot be empty';
  static const String phoneError = 'Invalid phone number';
  static const String pwdLengthError = 'Password must be 6-16 characters';
  static const String agreeAuthTips =
      'Please agree to the terms and conditions';
  static const String nicknameNotNull = 'Nickname cannot be empty';
  static const String loginFailed = 'Login failed';
  static const String registerFailed = 'Registration failed';
  static const String networkError = 'Network error';
  static const String unknownError = 'Unknown error occurred';
}

/// UI Constants
class UIConstants {
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 8.0;
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
}
