import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';

class GroupEntity {
  final String groupNo;
  final String name;

  GroupEntity({required this.groupNo, required this.name});

  factory GroupEntity.fromJson(Map<String, dynamic> json) {
    return GroupEntity(
      groupNo: (json['group_no'] ?? json['groupNo'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }
}

class GroupMemberEntity {
  final String uid;
  final String? name;
  final String? remark;
  final int role;
  final int status;
  final String? avatar;

  GroupMemberEntity({
    required this.uid,
    this.name,
    this.remark,
    this.role = 0,
    this.status = 0,
    this.avatar,
  });

  factory GroupMemberEntity.fromJson(Map<String, dynamic> json) {
    return GroupMemberEntity(
      uid: (json['uid'] ?? '').toString(),
      name: (json['name'] ?? json['username'] ?? '').toString(),
      remark: (json['remark'] ?? '').toString(),
      role: (json['role'] ?? 0) as int,
      status: (json['status'] ?? 0) as int,
      avatar: (json['avatar'] ?? '').toString(),
    );
  }
}

class GroupQrData {
  final int day;
  final String qrcode;
  final String expire;
  GroupQrData({required this.day, required this.qrcode, required this.expire});

  factory GroupQrData.fromJson(Map<String, dynamic> json) => GroupQrData(
    day: (json['day'] ?? 0) as int,
    qrcode: (json['qrcode'] ?? json['qrCode'] ?? '').toString(),
    expire: (json['expire'] ?? '').toString(),
  );
}

class GroupInfoResult {
  final String? notice;
  final int? groupType;
  final int? memberCount;
  GroupInfoResult({this.notice, this.groupType, this.memberCount});
  factory GroupInfoResult.fromJson(Map<String, dynamic> json) =>
      GroupInfoResult(
        notice: (json['notice'] ?? '').toString(),
        groupType: json['group_type'] is int
            ? json['group_type'] as int
            : (json['groupType'] as int?)?.toInt(),
        memberCount: json['member_count'] is int
            ? json['member_count'] as int
            : (json['memberCount'] as int?)?.toInt(),
      );
}

class GroupService {
  GroupService._();
  static final GroupService _instance = GroupService._();
  factory GroupService() => _instance;

  Future<Dio?> _createDio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(WKConstants.tokenKey) ?? '';

      final dio = Dio();
      final base = WKApiConfig.baseUrl.isNotEmpty
          ? WKApiConfig.baseUrl
          : '${WKApiConfig.defaultBaseUrl}/v1/';
      dio.options.baseUrl = base;
      dio.options.headers = {
        'Content-Type': 'application/json',
        'token': token,
        'package': AppInfo.packageName,
        'os': 'iOS',
        'appid': 'wukongchat',
        'model': 'flutter_app',
        'version': '1.0',
      };
      return dio;
    } catch (e) {
      Logger.error('GroupService: Failed to create Dio', error: e);
      return null;
    }
  }

  // Note: credentials are pulled directly in _createDio(); keep helpers minimal

  Future<GroupEntity?> createGroup(
    String name,
    List<String> ids,
    List<String> names,
    UserInfoEntity? currentUser,
  ) async {
    try {
      final dio = await _createDio();
      if (dio == null) return null;

      final body = {
        'name': name,
        'members': ids,
        'member_names': names,
        // mirror Android: msg_auto_delete uses user.msg_expire_second
        'msg_auto_delete': currentUser?.msgExpireSecond ?? 0,
      };

      Logger.api('group/create', 'Creating group with ${ids.length} members');
      final resp = await dio.post('/group/create', data: body);
      if (resp.statusCode == 200 && resp.data is Map) {
        final entity = GroupEntity.fromJson(resp.data as Map<String, dynamic>);

        // Save minimal channel locally (like Android)
        final channel = WKChannel(entity.groupNo, WKChannelType.group);
        channel.channelName = entity.name;
        WKIM.shared.channelManager.addOrUpdateChannel(channel);

        return entity;
      }
      Logger.warning('GroupService: createGroup failed ${resp.statusCode}');
      return null;
    } catch (e) {
      Logger.error('GroupService: createGroup error', error: e);
      return null;
    }
  }

  Future<bool> addGroupMembers(
    String groupNo,
    List<String> ids,
    List<String> names,
  ) async {
    try {
      final dio = await _createDio();
      if (dio == null) return false;
      final body = {'members': ids, 'names': names};
      final resp = await dio.post('/groups/$groupNo/members', data: body);
      return resp.statusCode == 200;
    } catch (e) {
      Logger.error('GroupService: addGroupMembers error', error: e);
      return false;
    }
  }

  Future<bool> inviteGroupMembers(String groupNo, List<String> ids) async {
    try {
      final dio = await _createDio();
      if (dio == null) return false;
      final body = {'uids': ids, 'remark': ''};
      final resp = await dio.post('/groups/$groupNo/member/invite', data: body);
      return resp.statusCode == 200;
    } catch (e) {
      Logger.error('GroupService: inviteGroupMembers error', error: e);
      return false;
    }
  }

  // ------ New APIs to mirror Android GroupModel/GroupService ------

  Future<bool> updateGroupSettingInt(
    String groupNo,
    String key,
    int value,
  ) async {
    try {
      final dio = await _createDio();
      if (dio == null) return false;
      final resp = await dio.put(
        '/groups/$groupNo/setting',
        data: {key: value},
      );
      return resp.statusCode == 200;
    } catch (e) {
      Logger.error('GroupService: updateGroupSettingInt error', error: e);
      return false;
    }
  }

  Future<bool> updateGroupSettingString(
    String groupNo,
    String key,
    String value,
  ) async {
    try {
      final dio = await _createDio();
      if (dio == null) return false;
      final resp = await dio.put(
        '/groups/$groupNo/setting',
        data: {key: value},
      );
      return resp.statusCode == 200;
    } catch (e) {
      Logger.error('GroupService: updateGroupSettingString error', error: e);
      return false;
    }
  }

  Future<bool> updateGroupInfo(String groupNo, String key, String value) async {
    try {
      final dio = await _createDio();
      if (dio == null) return false;
      final resp = await dio.put('/groups/$groupNo', data: {key: value});
      return resp.statusCode == 200;
    } catch (e) {
      Logger.error('GroupService: updateGroupInfo error', error: e);
      return false;
    }
  }

  Future<bool> updateGroupMemberInfo(
    String groupNo,
    String uid,
    String key,
    String value,
  ) async {
    try {
      final dio = await _createDio();
      if (dio == null) return false;
      final resp = await dio.put(
        '/groups/$groupNo/members/$uid',
        data: {key: value},
      );
      // If needed, SDK cache for member info will be refreshed via channel fetch elsewhere
      return resp.statusCode == 200;
    } catch (e) {
      Logger.error('GroupService: updateGroupMemberInfo error', error: e);
      return false;
    }
  }

  Future<bool> exitGroup(String groupNo) async {
    try {
      final dio = await _createDio();
      if (dio == null) return false;
      final resp = await dio.post('/groups/$groupNo/exit');
      return resp.statusCode == 200;
    } catch (e) {
      Logger.error('GroupService: exitGroup error', error: e);
      return false;
    }
  }

  Future<bool> deleteGroupMembers(
    String groupNo,
    List<String> uidList,
    List<String> names,
  ) async {
    try {
      final dio = await _createDio();
      if (dio == null) return false;
      final body = {'members': uidList, 'names': names};
      final resp = await dio.delete('/groups/$groupNo/members', data: body);
      return resp.statusCode == 200;
    } catch (e) {
      Logger.error('GroupService: deleteGroupMembers error', error: e);
      return false;
    }
  }

  Future<List<GroupMemberEntity>> getGroupMembers(
    String groupNo, {
    String keyword = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final dio = await _createDio();
      if (dio == null) return [];
      final resp = await dio.get(
        '/groups/$groupNo/members',
        queryParameters: {'keyword': keyword, 'page': page, 'limit': limit},
      );
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is List) {
          return data
              .map(
                (e) => GroupMemberEntity.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      Logger.error('GroupService: getGroupMembers error', error: e);
      return [];
    }
  }

  Future<GroupQrData?> getGroupQr(String groupNo) async {
    try {
      final dio = await _createDio();
      if (dio == null) return null;
      final resp = await dio.get('/groups/$groupNo/qrcode');
      if (resp.statusCode == 200 && resp.data is Map) {
        return GroupQrData.fromJson((resp.data as Map).cast<String, dynamic>());
      }
      return null;
    } catch (e) {
      Logger.error('GroupService: getGroupQr error', error: e);
      return null;
    }
  }

  Future<GroupInfoResult> getGroupInfo(String groupNo) async {
    try {
      final dio = await _createDio();
      if (dio == null) return GroupInfoResult();
      final resp = await dio.get('/groups/$groupNo');
      if (resp.statusCode == 200 && resp.data is Map) {
        return GroupInfoResult.fromJson(
          (resp.data as Map).cast<String, dynamic>(),
        );
      }
      return GroupInfoResult();
    } catch (e) {
      Logger.error('GroupService: getGroupInfo error', error: e);
      return GroupInfoResult();
    }
  }
}
