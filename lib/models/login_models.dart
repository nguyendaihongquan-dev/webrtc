/// Country code entity for phone number registration
class CountryCodeEntity {
  final String? code;
  final String? icon;
  final String? name;
  final String? pying;

  CountryCodeEntity({this.code, this.icon, this.name, this.pying});

  factory CountryCodeEntity.fromJson(Map<String, dynamic> json) {
    return CountryCodeEntity(
      code: json['code'],
      icon: json['icon'],
      name: json['name'],
      pying: json['pying'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'icon': icon, 'name': name, 'pying': pying};
  }

  CountryCodeEntity copyWith({
    String? code,
    String? icon,
    String? name,
    String? pying,
  }) {
    return CountryCodeEntity(
      code: code ?? this.code,
      icon: icon ?? this.icon,
      name: name ?? this.name,
      pying: pying ?? this.pying,
    );
  }
}

/// Verification code result for SMS verification
class VerfiCodeResult {
  final int? exist;

  VerfiCodeResult({this.exist});

  factory VerfiCodeResult.fromJson(Map<String, dynamic> json) {
    return VerfiCodeResult(exist: json['exist']);
  }

  Map<String, dynamic> toJson() {
    return {'exist': exist};
  }
}

/// Third-party authentication code for QR login
class ThirdAuthCode {
  final String? authcode;

  ThirdAuthCode({this.authcode});

  factory ThirdAuthCode.fromJson(Map<String, dynamic> json) {
    return ThirdAuthCode(authcode: json['authcode']);
  }

  Map<String, dynamic> toJson() {
    return {'authcode': authcode};
  }
}

/// User QR code data (matching Android UserQr.java)
class UserQr {
  final String data;

  UserQr({required this.data});

  factory UserQr.fromJson(Map<String, dynamic> json) {
    return UserQr(data: json['data'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'data': data};
  }
}

/// Third-party login result
class ThirdLoginResult {
  final int? status;
  final dynamic result; // Can be UserInfoEntity or other types

  ThirdLoginResult({this.status, this.result});

  factory ThirdLoginResult.fromJson(Map<String, dynamic> json) {
    return ThirdLoginResult(status: json['status'], result: json['result']);
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'result': result};
  }
}

/// Common response for API calls
class CommonResponse {
  final int? status;
  final String? msg;

  CommonResponse({this.status, this.msg});

  factory CommonResponse.fromJson(Map<String, dynamic> json) {
    return CommonResponse(status: json['status'], msg: json['msg']);
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'msg': msg};
  }
}

/// App configuration entity
class WKAPPConfig {
  final int? version;
  final String? webUrl;
  final int? phoneSearchOff;
  final int? shortnoEditOff;
  final int? revokeSecond;
  final int? registerInviteOn;
  final int? sendWelcomeMessageOn;
  final int? inviteSystemAccountJoinGroupOn;
  final int? registerUserMustCompleteInfoOn;
  final int? canModifyApiUrl;

  WKAPPConfig({
    this.version,
    this.webUrl,
    this.phoneSearchOff,
    this.shortnoEditOff,
    this.revokeSecond,
    this.registerInviteOn,
    this.sendWelcomeMessageOn,
    this.inviteSystemAccountJoinGroupOn,
    this.registerUserMustCompleteInfoOn,
    this.canModifyApiUrl,
  });

  factory WKAPPConfig.fromJson(Map<String, dynamic> json) {
    return WKAPPConfig(
      version: json['version'],
      webUrl: json['web_url'],
      phoneSearchOff: json['phone_search_off'],
      shortnoEditOff: json['shortno_edit_off'],
      revokeSecond: json['revoke_second'],
      registerInviteOn: json['register_invite_on'],
      sendWelcomeMessageOn: json['send_welcome_message_on'],
      inviteSystemAccountJoinGroupOn:
          json['invite_system_account_join_group_on'],
      registerUserMustCompleteInfoOn:
          json['register_user_must_complete_info_on'],
      canModifyApiUrl: json['can_modify_api_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'web_url': webUrl,
      'phone_search_off': phoneSearchOff,
      'shortno_edit_off': shortnoEditOff,
      'revoke_second': revokeSecond,
      'register_invite_on': registerInviteOn,
      'send_welcome_message_on': sendWelcomeMessageOn,
      'invite_system_account_join_group_on': inviteSystemAccountJoinGroupOn,
      'register_user_must_complete_info_on': registerUserMustCompleteInfoOn,
      'can_modify_api_url': canModifyApiUrl,
    };
  }
}

/// Device information for login requests
class DeviceInfo {
  final String? deviceId;
  final String? deviceName;
  final String? deviceModel;

  DeviceInfo({this.deviceId, this.deviceName, this.deviceModel});

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['device_id'],
      deviceName: json['device_name'],
      deviceModel: json['device_model'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'device_model': deviceModel,
    };
  }
}

/// HTTP response codes
class HttpResponseCode {
  static const int success = 200;
  static const int error = 500;
  static const int deviceLockRequired =
      110; // Special code for device lock authentication
}
