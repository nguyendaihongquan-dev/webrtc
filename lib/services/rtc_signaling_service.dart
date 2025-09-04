import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import '../models/video_call_model.dart';
import '../utils/navigation_service.dart';
import '../screens/video_call/video_call_screen.dart';
import 'package:provider/provider.dart';
import '../providers/video_call_provider.dart';
import '../services/video_call_service.dart';

class RtcSignalingService {
  RtcSignalingService._();
  static final RtcSignalingService instance = RtcSignalingService._();

  bool _initialized = false;
  bool _isCallUIShowing = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Prefer new-message listener for incoming messages (works reliably)
    WKIM.shared.messageManager.addOnNewMsgListener('rtc_global_listener_new', (
      List<WKMsg> messages,
    ) async {
      for (final msg in messages) {
        try {
          final content = msg.content;
          final isInvite = content.startsWith('__RTC_INVITE__|');
          final isOffer = content.startsWith('__RTC_OFFER__|');
          final isIce = content.startsWith('__RTC_ICE__|');
          if (!isInvite && !isOffer && !isIce) continue;

          // For testing across same UID on two devices, do not ignore self messages here
          // final uid = await _getCurrentUid();
          // if (uid != null && uid == msg.fromUID) continue; // ignore self

          String callerId = msg.fromUID;
          String callerName = 'Unknown';
          String? callerAvatar;
          List<String> participants = <String>[];
          String channelId = msg.channelID;
          final callType = msg.channelType == 2
              ? VideoCallType.group
              : VideoCallType.p2p;

          Map<String, dynamic> data = const {};
          if (isInvite) {
            final String jsonText = content.substring('__RTC_INVITE__|'.length);
            data = jsonDecode(jsonText) as Map<String, dynamic>;
            callerId = (data['callerId'] ?? callerId) as String;
            callerName = (data['callerName'] ?? 'Unknown') as String;
            callerAvatar = data['callerAvatar'] as String?;
            participants =
                (data['participants'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                <String>[];
            channelId = (data['channelId'] ?? channelId) as String;
          }

          final videoCallService = VideoCallService();
          await videoCallService.initialize();
          // Always ensure we have an incoming model; safe to call multiple times
          videoCallService.beginIncomingCall(
            channelId: channelId,
            callerId: callerId,
            callerName: callerName,
            callerAvatar: callerAvatar,
            participants: participants,
            callType: callType,
          );

          // Handle OFFER/ICE immediately (even if UI not yet opened)
          if (isOffer) {
            final String jsonText = content.substring('__RTC_OFFER__|'.length);
            final offerData = jsonDecode(jsonText) as Map<String, dynamic>;
            final sdp = (offerData['sdp'] ?? '') as String;
            final type = (offerData['type'] ?? 'offer') as String;
            if (sdp.isNotEmpty) {
              await videoCallService.acceptCall();
              await videoCallService.handleRemoteOffer(sdp, type);
            }
          } else if (isIce) {
            final String jsonText = content.substring('__RTC_ICE__|'.length);
            final iceData = jsonDecode(jsonText) as Map<String, dynamic>;
            final candidate = (iceData['candidate'] ?? '') as String;
            final sdpMid = iceData['sdpMid'] as String?;
            final sdpMLineIndex = (iceData['sdpMLineIndex'] as num?)?.toInt();
            if (candidate.isNotEmpty) {
              await videoCallService.handleRemoteIce(
                candidate,
                sdpMid,
                sdpMLineIndex,
              );
            }
          }

          if (_isCallUIShowing) continue;
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
      }
    });

    _initialized = true;
  }

  // Reserved: get current uid if needed later
}
