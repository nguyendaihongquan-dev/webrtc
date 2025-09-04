class UserInfoEntity {
  final String? token;
  final String? uid;
  final String? username;
  final String? name;
  final String? imToken;
  final String? shortNo; // 显示的id号
  final int? shortStatus; // 是否已经设置ID
  final int? sex;
  final String? zone; // 区号
  final String? phone; // 手机号
  final String? avatar;
  final int? serverId;
  final String? chatPwd; // 聊天密码
  final String? lockScreenPwd; // 锁屏密码
  final int? lockAfterMinute;
  final String? rsaPublicKey;
  final int? msgExpireSecond;
  final UserInfoSetting? setting;

  UserInfoEntity({
    this.token,
    this.uid,
    this.username,
    this.name,
    this.imToken,
    this.shortNo,
    this.shortStatus,
    this.sex,
    this.zone,
    this.phone,
    this.avatar,
    this.serverId,
    this.chatPwd,
    this.lockScreenPwd,
    this.lockAfterMinute,
    this.rsaPublicKey,
    this.msgExpireSecond,
    this.setting,
  });

  factory UserInfoEntity.fromJson(Map<String, dynamic> json) {
    return UserInfoEntity(
      token: json['token'],
      uid: json['uid'],
      username: json['username'],
      name: json['name'],
      imToken: json['im_token'],
      shortNo: json['short_no'],
      shortStatus: json['short_status'],
      sex: json['sex'],
      zone: json['zone'],
      phone: json['phone'],
      avatar: json['avatar'],
      serverId: json['server_id'],
      chatPwd: json['chat_pwd'],
      lockScreenPwd: json['lock_screen_pwd'],
      lockAfterMinute: json['lock_after_minute'],
      rsaPublicKey: json['rsa_public_key'],
      msgExpireSecond: json['msg_expire_second'],
      setting: json['setting'] != null
          ? UserInfoSetting.fromJson(json['setting'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'uid': uid,
      'username': username,
      'name': name,
      'im_token': imToken,
      'short_no': shortNo,
      'short_status': shortStatus,
      'sex': sex,
      'zone': zone,
      'phone': phone,
      'avatar': avatar,
      'server_id': serverId,
      'chat_pwd': chatPwd,
      'lock_screen_pwd': lockScreenPwd,
      'lock_after_minute': lockAfterMinute,
      'rsa_public_key': rsaPublicKey,
      'msg_expire_second': msgExpireSecond,
      'setting': setting?.toJson(),
    };
  }

  UserInfoEntity copyWith({
    String? token,
    String? uid,
    String? username,
    String? name,
    String? imToken,
    String? shortNo,
    int? shortStatus,
    int? sex,
    String? zone,
    String? phone,
    String? avatar,
    int? serverId,
    String? chatPwd,
    String? lockScreenPwd,
    int? lockAfterMinute,
    String? rsaPublicKey,
    int? msgExpireSecond,
    UserInfoSetting? setting,
  }) {
    return UserInfoEntity(
      token: token ?? this.token,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      name: name ?? this.name,
      imToken: imToken ?? this.imToken,
      shortNo: shortNo ?? this.shortNo,
      shortStatus: shortStatus ?? this.shortStatus,
      sex: sex ?? this.sex,
      zone: zone ?? this.zone,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      serverId: serverId ?? this.serverId,
      chatPwd: chatPwd ?? this.chatPwd,
      lockScreenPwd: lockScreenPwd ?? this.lockScreenPwd,
      lockAfterMinute: lockAfterMinute ?? this.lockAfterMinute,
      rsaPublicKey: rsaPublicKey ?? this.rsaPublicKey,
      msgExpireSecond: msgExpireSecond ?? this.msgExpireSecond,
      setting: setting ?? this.setting,
    );
  }
}

class UserInfoSetting {
  final int? searchByPhone; // 手机号搜索
  final int? searchByShort; // ID搜索
  final int? newMsgNotice; // 显示消息通知
  final int? msgShowDetail; // 显示消息通知详情
  final int? voiceOn; // 通知声音
  final int? shockOn; // 通知震动
  final int? deviceLock; // 是否开启登录设备验证
  final int? offlineProtection; // 离线保护，断网屏保

  UserInfoSetting({
    this.searchByPhone,
    this.searchByShort,
    this.newMsgNotice,
    this.msgShowDetail,
    this.voiceOn,
    this.shockOn,
    this.deviceLock,
    this.offlineProtection,
  });

  factory UserInfoSetting.fromJson(Map<String, dynamic> json) {
    return UserInfoSetting(
      searchByPhone: json['search_by_phone'],
      searchByShort: json['search_by_short'],
      newMsgNotice: json['new_msg_notice'],
      msgShowDetail: json['msg_show_detail'],
      voiceOn: json['voice_on'],
      shockOn: json['shock_on'],
      deviceLock: json['device_lock'],
      offlineProtection: json['offline_protection'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'search_by_phone': searchByPhone,
      'search_by_short': searchByShort,
      'new_msg_notice': newMsgNotice,
      'msg_show_detail': msgShowDetail,
      'voice_on': voiceOn,
      'shock_on': shockOn,
      'device_lock': deviceLock,
      'offline_protection': offlineProtection,
    };
  }

  UserInfoSetting copyWith({
    int? searchByPhone,
    int? searchByShort,
    int? newMsgNotice,
    int? msgShowDetail,
    int? voiceOn,
    int? shockOn,
    int? deviceLock,
    int? offlineProtection,
  }) {
    return UserInfoSetting(
      searchByPhone: searchByPhone ?? this.searchByPhone,
      searchByShort: searchByShort ?? this.searchByShort,
      newMsgNotice: newMsgNotice ?? this.newMsgNotice,
      msgShowDetail: msgShowDetail ?? this.msgShowDetail,
      voiceOn: voiceOn ?? this.voiceOn,
      shockOn: shockOn ?? this.shockOn,
      deviceLock: deviceLock ?? this.deviceLock,
      offlineProtection: offlineProtection ?? this.offlineProtection,
    );
  }
}

/// Contact Card User Info model matching Android UserInfo.java
/// Used for Contact Card screen API response
class ContactCardUserInfo {
  final String uid;
  final String? name;
  final String? username;
  final int mute;
  final int top;
  final int sex;
  final String? category;
  final String? shortNo;
  final int chatPwdOn;
  final int screenshot;
  final int revokeRemind;
  final int receipt;
  final int online;
  final int lastOffline;
  final int follow;
  final String? vercode;
  final String? sourceDesc;
  final String? remark;
  final int isUploadAvatar;
  final int status;
  final int version;
  final int isDeleted;
  final int robot;
  final int beDeleted;
  final int beBlacklist;
  final String? updatedAt;
  final String? createdAt;
  final String? joinGroupInviteUid;
  final String? joinGroupInviteName;
  final String? joinGroupTime;

  ContactCardUserInfo({
    required this.uid,
    this.name,
    this.username,
    this.mute = 0,
    this.top = 0,
    this.sex = 0,
    this.category,
    this.shortNo,
    this.chatPwdOn = 0,
    this.screenshot = 0,
    this.revokeRemind = 0,
    this.receipt = 0,
    this.online = 0,
    this.lastOffline = 0,
    this.follow = 0,
    this.vercode,
    this.sourceDesc,
    this.remark,
    this.isUploadAvatar = 0,
    this.status = 0,
    this.version = 0,
    this.isDeleted = 0,
    this.robot = 0,
    this.beDeleted = 0,
    this.beBlacklist = 0,
    this.updatedAt,
    this.createdAt,
    this.joinGroupInviteUid,
    this.joinGroupInviteName,
    this.joinGroupTime,
  });

  factory ContactCardUserInfo.fromJson(Map<String, dynamic> json) {
    return ContactCardUserInfo(
      uid: json['uid'] ?? '',
      name: json['name'],
      username: json['username'],
      mute: json['mute'] ?? 0,
      top: json['top'] ?? 0,
      sex: json['sex'] ?? 0,
      category: json['category'],
      shortNo: json['short_no'],
      chatPwdOn: json['chat_pwd_on'] ?? 0,
      screenshot: json['screenshot'] ?? 0,
      revokeRemind: json['revoke_remind'] ?? 0,
      receipt: json['receipt'] ?? 0,
      online: json['online'] ?? 0,
      lastOffline: json['last_offline'] ?? 0,
      follow: json['follow'] ?? 0,
      vercode: json['vercode'],
      sourceDesc: json['source_desc'],
      remark: json['remark'],
      isUploadAvatar: json['is_upload_avatar'] ?? 0,
      status: json['status'] ?? 0,
      version: json['version'] ?? 0,
      isDeleted: json['is_deleted'] ?? 0,
      robot: json['robot'] ?? 0,
      beDeleted: json['be_deleted'] ?? 0,
      beBlacklist: json['be_blacklist'] ?? 0,
      updatedAt: json['updated_at'],
      createdAt: json['created_at'],
      joinGroupInviteUid: json['join_group_invite_uid'],
      joinGroupInviteName: json['join_group_invite_name'],
      joinGroupTime: json['join_group_time'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'mute': mute,
      'top': top,
      'sex': sex,
      'category': category,
      'short_no': shortNo,
      'chat_pwd_on': chatPwdOn,
      'screenshot': screenshot,
      'revoke_remind': revokeRemind,
      'receipt': receipt,
      'online': online,
      'last_offline': lastOffline,
      'follow': follow,
      'vercode': vercode,
      'source_desc': sourceDesc,
      'remark': remark,
      'is_upload_avatar': isUploadAvatar,
      'status': status,
      'version': version,
      'is_deleted': isDeleted,
      'robot': robot,
      'be_deleted': beDeleted,
      'be_blacklist': beBlacklist,
      'updated_at': updatedAt,
      'created_at': createdAt,
      'join_group_invite_uid': joinGroupInviteUid,
      'join_group_invite_name': joinGroupInviteName,
      'join_group_time': joinGroupTime,
    };
  }

  /// Get display name (prioritize remark over name)
  String get displayName {
    if (remark != null && remark!.isNotEmpty) {
      return remark!;
    }
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return uid;
  }

  /// Check if user is friend
  bool get isFriend => follow == 1;

  /// Check if user is blocked
  bool get isBlocked => status == 2;
}

/// Contact information model matching Android UserInfo.java
/// Used for friend sync API response
class ContactInfo {
  final String uid;
  final String? name;
  final String? username;
  final int mute;
  final int top;
  final int sex;
  final String? category;
  final String? shortNo;
  final int chatPwdOn;
  final int screenshot;
  final int revokeRemind;
  final int receipt;
  final int online;
  final int lastOffline;
  final int follow;
  final String? vercode;
  final String? sourceDesc;
  final String? remark;
  final int isUploadAvatar;
  final int status;
  final int version;
  final int isDeleted;
  final int robot;
  final int beDeleted;
  final int beBlacklist;
  final String? updatedAt;
  final String? createdAt;

  ContactInfo({
    required this.uid,
    this.name,
    this.username,
    this.mute = 0,
    this.top = 0,
    this.sex = 0,
    this.category,
    this.shortNo,
    this.chatPwdOn = 0,
    this.screenshot = 0,
    this.revokeRemind = 0,
    this.receipt = 0,
    this.online = 0,
    this.lastOffline = 0,
    this.follow = 0,
    this.vercode,
    this.sourceDesc,
    this.remark,
    this.isUploadAvatar = 0,
    this.status = 0,
    this.version = 0,
    this.isDeleted = 0,
    this.robot = 0,
    this.beDeleted = 0,
    this.beBlacklist = 0,
    this.updatedAt,
    this.createdAt,
  });

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      uid: json['uid'] ?? '',
      name: json['name'],
      username: json['username'],
      mute: json['mute'] ?? 0,
      top: json['top'] ?? 0,
      sex: json['sex'] ?? 0,
      category: json['category'],
      shortNo: json['short_no'],
      chatPwdOn: json['chat_pwd_on'] ?? 0,
      screenshot: json['screenshot'] ?? 0,
      revokeRemind: json['revoke_remind'] ?? 0,
      receipt: json['receipt'] ?? 0,
      online: json['online'] ?? 0,
      lastOffline: json['last_offline'] ?? 0,
      follow: json['follow'] ?? 0,
      vercode: json['vercode'],
      sourceDesc: json['source_desc'],
      remark: json['remark'],
      isUploadAvatar: json['is_upload_avatar'] ?? 0,
      status: json['status'] ?? 0,
      version: json['version'] ?? 0,
      isDeleted: json['is_deleted'] ?? 0,
      robot: json['robot'] ?? 0,
      beDeleted: json['be_deleted'] ?? 0,
      beBlacklist: json['be_blacklist'] ?? 0,
      updatedAt: json['updated_at'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'mute': mute,
      'top': top,
      'sex': sex,
      'category': category,
      'short_no': shortNo,
      'chat_pwd_on': chatPwdOn,
      'screenshot': screenshot,
      'revoke_remind': revokeRemind,
      'receipt': receipt,
      'online': online,
      'last_offline': lastOffline,
      'follow': follow,
      'vercode': vercode,
      'source_desc': sourceDesc,
      'remark': remark,
      'is_upload_avatar': isUploadAvatar,
      'status': status,
      'version': version,
      'is_deleted': isDeleted,
      'robot': robot,
      'be_deleted': beDeleted,
      'be_blacklist': beBlacklist,
      'updated_at': updatedAt,
      'created_at': createdAt,
    };
  }
}
