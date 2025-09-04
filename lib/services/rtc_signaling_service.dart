import 'dart:convert';
import 'dart:async';
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
  bool _isPushRetryScheduled = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Prefer new-message listener for incoming messages (works reliably)
    WKIM.shared.messageManager.addOnNewMsgListener('rtc_global_listener_new', (
      List<WKMsg> messages,
    ) async {
      for (final msg in messages) {
        try {
          debugPrint(
            '[RTC] onNewMsg channelID=${msg.channelID} from=${msg.fromUID} contentLen=${msg.content.length}',
          );
          final content = msg.content;
          final isInvite = content.startsWith('__RTC_INVITE__|');
          final isOffer = content.startsWith('__RTC_OFFER__|');
          final isAnswer = content.startsWith('__RTC_ANSWER__|');
          final isIce = content.startsWith('__RTC_ICE__|');
          final isEnd = content.startsWith('__RTC_END__|');
          final isReject = content.startsWith('__RTC_REJECT__|');
          debugPrint(
            '[RTC] flags invite=$isInvite offer=$isOffer answer=$isAnswer ice=$isIce end=$isEnd reject=$isReject',
          );
          if (!isInvite &&
              !isOffer &&
              !isAnswer &&
              !isIce &&
              !isEnd &&
              !isReject)
            continue;

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

          // Handle OFFER/ANSWER/ICE immediately (even if UI not yet opened)
          if (isOffer) {
            final String jsonText = content.substring('__RTC_OFFER__|'.length);
            final offerData = jsonDecode(jsonText) as Map<String, dynamic>;
            final sdp = (offerData['sdp'] ?? '') as String;
            final type = (offerData['type'] ?? 'offer') as String;
            if (sdp.isNotEmpty) {
              debugPrint(
                '[RTC] Received OFFER, calling acceptCall + handleRemoteOffer',
              );
              await videoCallService.acceptCall();
              await videoCallService.handleRemoteOffer(sdp, type);
            }
          } else if (isAnswer) {
            final String jsonText = content.substring('__RTC_ANSWER__|'.length);
            final ansData = jsonDecode(jsonText) as Map<String, dynamic>;
            final sdp = (ansData['sdp'] ?? '') as String;
            final type = (ansData['type'] ?? 'answer') as String;
            if (sdp.isNotEmpty) {
              debugPrint(
                '[RTC] Received ANSWER, passing to handleRemoteAnswer',
              );
              await videoCallService.handleRemoteAnswer(sdp, type);
            }
          } else if (isIce) {
            final String jsonText = content.substring('__RTC_ICE__|'.length);
            final iceData = jsonDecode(jsonText) as Map<String, dynamic>;
            final candidate = (iceData['candidate'] ?? '') as String;
            final sdpMid = iceData['sdpMid'] as String?;
            final sdpMLineIndex = (iceData['sdpMLineIndex'] as num?)?.toInt();
            if (candidate.isNotEmpty) {
              debugPrint(
                '[RTC] Received ICE, passing candidate to handleRemoteIce',
              );
              await videoCallService.handleRemoteIce(
                candidate,
                sdpMid,
                sdpMLineIndex,
              );
            }
          } else if (isEnd) {
            final String jsonText = content.substring('__RTC_END__|'.length);
            final endData = jsonDecode(jsonText) as Map<String, dynamic>;
            final reason = endData['reason'] as String?;
            debugPrint('[RTC] Received END, closing call');
            await videoCallService.handleRemoteEnd(reason: reason);
          } else if (isReject) {
            final String jsonText = content.substring('__RTC_REJECT__|'.length);
            final rejData = jsonDecode(jsonText) as Map<String, dynamic>;
            final reason = rejData['reason'] as String?;
            debugPrint('[RTC] Received REJECT, updating state');
            await videoCallService.handleRemoteReject(reason: reason);
          }

          if (_isCallUIShowing) {
            debugPrint('[RTC][SKIP] Call UI already showing, skip push');
            continue;
          }
          _isCallUIShowing = true;

          debugPrint('[RTC] Preparing to push VideoCallScreen (incoming)');
          final pushed = await _pushIncomingCallUI(
            channelId: channelId,
            callerId: callerId,
            callerName: callerName,
            callerAvatar: callerAvatar,
            participants: participants,
            callType: callType,
          );
          if (!pushed) {
            debugPrint(
              '[RTC][ERROR] Failed to push VideoCallScreen after retries',
            );
          }
          _isCallUIShowing = false;
        } catch (e, s) {
          debugPrint('[RTC][ERROR] Exception in onNewMsg handler: $e\n$s');
          _isCallUIShowing = false;
        }
      }
    });

    _initialized = true;
  }

  // Reserved: get current uid if needed later
  Future<bool> _pushIncomingCallUI({
    required String channelId,
    required String callerId,
    required String callerName,
    required String? callerAvatar,
    required List<String> participants,
    required VideoCallType callType,
  }) async {
    // Try immediate push with navigatorKey.currentState
    final nav = NavigationService.navigatorKey.currentState;
    if (nav != null) {
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
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
        completer.complete();
      });
      await completer.future;
      debugPrint('[RTC] VideoCallScreen pushed via navigatorKey');
      return true;
    }

    // Fallback to currentContext immediately
    final ctx = NavigationService.navigatorKey.currentContext;
    if (ctx != null) {
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Navigator.of(ctx, rootNavigator: true).push(
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
        completer.complete();
      });
      await completer.future;
      debugPrint('[RTC] VideoCallScreen pushed via currentContext');
      return true;
    }

    // If neither is ready (e.g., early messages before runApp), retry a few times
    if (_isPushRetryScheduled) {
      debugPrint(
        '[RTC][WARN] Push retry already scheduled; skipping duplicate schedule',
      );
      return false;
    }
    _isPushRetryScheduled = true;
    const int maxAttempts = 10; // ~3s (10 * 300ms)
    int attempt = 0;
    final Completer<bool> result = Completer<bool>();
    Future<void> tryPush() async {
      attempt++;
      final nav2 = NavigationService.navigatorKey.currentState;
      final ctx2 = NavigationService.navigatorKey.currentContext;
      if (nav2 != null || ctx2 != null) {
        _isPushRetryScheduled = false;
        if (!result.isCompleted) {
          debugPrint('[RTC] Navigator ready on attempt #$attempt, pushing UI');
          if (nav2 != null) {
            final c = Completer<void>();
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await nav2.push(
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
              c.complete();
            });
            await c.future;
            debugPrint(
              '[RTC] VideoCallScreen pushed via navigatorKey(after retry)',
            );
          } else if (ctx2 != null) {
            final c = Completer<void>();
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await Navigator.of(ctx2, rootNavigator: true).push(
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
              c.complete();
            });
            await c.future;
            debugPrint(
              '[RTC] VideoCallScreen pushed via currentContext(after retry)',
            );
          }
          result.complete(true);
        }
        return;
      }
      if (attempt >= maxAttempts) {
        _isPushRetryScheduled = false;
        if (!result.isCompleted) {
          debugPrint(
            '[RTC][ERROR] Navigator not ready after $maxAttempts attempts',
          );
          result.complete(false);
        }
        return;
      }
      Future.delayed(const Duration(milliseconds: 300), tryPush);
    }

    debugPrint('[RTC][WARN] Navigator not ready, scheduling retry push...');
    Future.delayed(const Duration(milliseconds: 300), tryPush);
    return result.future;
  }
}
