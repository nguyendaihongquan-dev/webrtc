import 'package:dio/dio.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import '../utils/logger.dart';

class MsgService {
  final Dio _dio;

  MsgService(this._dio);

  /// Clear all messages of a channel locally (mark is_deleted=1)
  Future<void> clearChannelMessages(String channelId, int channelType) async {
    try {
      Logger.service(
        'MsgService',
        'Clearing messages for $channelId/$channelType',
      );
      // SDK provides local clear
      await WKIM.shared.messageManager.clearWithChannel(channelId, channelType);
      Logger.service('MsgService', 'Cleared messages for $channelId');
    } catch (e) {
      Logger.error('Failed to clear channel messages', error: e);
    }
  }

  /// Offset messages on server (sync with Android MsgModel.offsetMsg)
  Future<void> offsetMsg(String channelId, int channelType) async {
    try {
      final data = {'channel_id': channelId, 'channel_type': channelType};
      Logger.service('MsgService', 'Offset messages: $data');
      await _dio.post('/message/offset', data: data);
    } catch (e) {
      Logger.error('Failed to offset messages', error: e);
    }
  }

  /// Delete messages on server for everyone (Android: MsgService.deleteMsg)
  /// Returns true if server acknowledges deletion
  Future<bool> deleteMessages(List<WKMsg> list) async {
    try {
      final payload = list
          .map(
            (msg) => {
              'message_id': msg.messageID,
              'channel_id': msg.channelID,
              'channel_type': msg.channelType,
              'message_seq': msg.messageSeq,
            },
          )
          .toList();
      Logger.service(
        'MsgService',
        'Deleting messages: count=${payload.length}',
      );
      final resp = await _dio.delete('/message', data: payload);
      final ok = resp.statusCode == 200;
      if (!ok) {
        Logger.warning('MsgService.deleteMessages failed: ${resp.statusCode}');
      }
      return ok;
    } catch (e) {
      Logger.error('Failed to delete messages on server', error: e);
      return false;
    }
  }

  /// Send typing status to server
  /// Following Android implementation: MsgService.java typing endpoint
  Future<void> sendTyping(String channelId, int channelType) async {
    try {
      final data = {'channel_id': channelId, 'channel_type': channelType};

      Logger.service('MsgService', 'Sending typing status: $data');

      await _dio.post('/message/typing', data: data);

      Logger.service('MsgService', 'Typing status sent successfully');
    } catch (e) {
      Logger.error('Failed to send typing status', error: e);
      // Don't throw - typing status is not critical
    }
  }
}
