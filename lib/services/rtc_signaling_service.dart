import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import '../config/constants.dart';
import '../models/video_call_model.dart';
import '../utils/navigation_service.dart';
import '../screens/video_call/video_call_screen.dart';
import 'package:provider/provider.dart';
import '../providers/video_call_provider.dart';

class RtcSignalingService {
  RtcSignalingService._();
  static final RtcSignalingService instance = RtcSignalingService._();

  bool _initialized = false;
  bool _isCallUIShowing = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Listen global for new/refresh messages from WKIM
    WKIM.shared.messageManager.addOnRefreshMsgListener('rtc_global_listener', (
      WKMsg msg,
    ) async {
      try {
        final content = msg.content;
        if (!content.startsWith('__RTC_INVITE__|')) return;

        final uid = await _getCurrentUid();
        if (uid != null && uid == msg.fromUID) return; // ignore self

        final String jsonText = content.substring('__RTC_INVITE__|'.length);
        final data = jsonDecode(jsonText) as Map<String, dynamic>;

        final callerId = (data['callerId'] ?? '') as String;
        final callerName = (data['callerName'] ?? 'Unknown') as String;
        final callerAvatar = data['callerAvatar'] as String?;
        final participants =
            (data['participants'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        final callTypeText = (data['callType'] ?? 'p2p') as String;
        final callType = callTypeText == 'group'
            ? VideoCallType.group
            : VideoCallType.p2p;
        final channelId = (data['channelId'] ?? '') as String;

        if (_isCallUIShowing) return;
        _isCallUIShowing = true;

        final nav = NavigationService.navigatorKey.currentState;
        if (nav == null) {
          _isCallUIShowing = false;
          return;
        }

        await nav.push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => VideoCallProvider(),
              child: VideoCallScreen(
                channelId: channelId,
                callerId: callerId,
                callerName: callerName,
                callerAvatar: callerAvatar,
                participants: participants,
                callType: callType,
                isIncoming: true,
              ),
            ),
          ),
        );

        _isCallUIShowing = false;
      } catch (_) {}
    });

    _initialized = true;
  }

  Future<String?> _getCurrentUid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(WKConstants.uidKey);
    } catch (_) {
      return null;
    }
  }
}
