import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/db/const.dart';

/// Multiple forward message content
/// Corresponds to WKMultiForwardContent in Android
class WKMultiForwardContent extends WKMessageContent {
  int channelType = 0;
  List<WKChannel> userList = [];
  List<WKMsg> msgList = [];

  WKMultiForwardContent() {
    contentType = 98; // Custom type for multiple forward
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {
      'channel_type': channelType,
      'msgs': msgList.map((msg) {
        final json = <String, dynamic>{};
        if (msg.content.isNotEmpty) {
          json['payload'] = msg.messageContent?.encodeJson() ?? {};
        }
        json['timestamp'] = msg.timestamp;
        json['message_id'] = msg.messageID;
        json['from_uid'] = msg.fromUID;
        return json;
      }).toList(),
      'users': userList
          .map(
            (user) => {
              'uid': user.channelID,
              'name': user.channelName,
              'avatar': user.avatar,
            },
          )
          .toList(),
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    channelType = WKDBConst.readInt(json, 'channel_type');

    final msgArr = json['msgs'] as List<dynamic>?;
    if (msgArr != null) {
      msgList = msgArr.map((msgJson) {
        final msg = WKMsg();
        final contentJson = msgJson['payload'] as Map<String, dynamic>?;
        if (contentJson != null) {
          msg.content = contentJson.toString();
          // Note: In actual implementation, decode content properly
          msg.contentType = contentJson['type'] ?? 0;
        } else {
          msg.contentType = 0; // Unknown message type
        }
        msg.timestamp = msgJson['timestamp'] ?? 0;
        msg.messageID = msgJson['message_id'] ?? '';
        msg.fromUID = msgJson['from_uid'] ?? '';
        return msg;
      }).toList();
    }

    final userArr = json['users'] as List<dynamic>?;
    if (userArr != null) {
      userList = userArr.map((userJson) {
        final channel = WKChannel(
          userJson['uid'] ?? '',
          WKChannelType.personal,
        );
        channel.channelName = userJson['name'] ?? '';
        channel.avatar = userJson['avatar'] ?? '';
        return channel;
      }).toList();
    }

    return this;
  }

  @override
  String displayText() {
    return '[Chat Record]';
  }
}
