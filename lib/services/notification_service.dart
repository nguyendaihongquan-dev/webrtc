import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:qgim_client_flutter/config/constants.dart';
import 'package:qgim_client_flutter/utils/logger.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS init
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {},
    );

    // Request permission on Android 13+
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      // Ensure channels exist
      await _createChannelsIfNeeded();
    }

    _initialized = true;
  }

  Future<void> _createChannelsIfNeeded() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    // New message channel
    const AndroidNotificationChannel newMsgChannel = AndroidNotificationChannel(
      WKConstants.newMsgChannelID,
      'New message notifications',
      description: 'Notifications for new messages',
      importance: Importance.high,
    );

    // Additional channels to control sound/vibration precisely
    const AndroidNotificationChannel newMsgSoundOnlyChannel =
        AndroidNotificationChannel(
          WKConstants.newMsgChannelSoundOnlyID,
          'New messages (sound only)',
          description: 'New message notifications with sound only',
          importance: Importance.high,
          playSound: true,
          enableVibration: false,
        );

    const AndroidNotificationChannel newMsgVibrateOnlyChannel =
        AndroidNotificationChannel(
          WKConstants.newMsgChannelVibrateOnlyID,
          'New messages (vibration only)',
          description: 'New message notifications with vibration only',
          importance: Importance.high,
          playSound: false,
          enableVibration: true,
        );

    const AndroidNotificationChannel newMsgSilentChannel =
        AndroidNotificationChannel(
          WKConstants.newMsgChannelSilentID,
          'New messages (silent)',
          description: 'New message notifications without sound and vibration',
          importance: Importance.high,
          playSound: false,
          enableVibration: false,
        );

    // RTC (audio/video invite) channel
    const AndroidNotificationChannel rtcChannel = AndroidNotificationChannel(
      WKConstants.newRTCChannelID,
      'Audio/Video invitation notifications',
      description: 'Notifications for audio and video calls',
      importance: Importance.max,
    );

    await android.createNotificationChannel(newMsgChannel);
    await android.createNotificationChannel(newMsgSoundOnlyChannel);
    await android.createNotificationChannel(newMsgVibrateOnlyChannel);
    await android.createNotificationChannel(newMsgSilentChannel);
    await android.createNotificationChannel(rtcChannel);
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true; // Default for other platforms
  }

  /// Show a notification for new message.
  ///
  /// [showDetail] controls whether to show real message text or a generic text.
  /// [playSound] and [vibrate] are best-effort toggles; on Android 8+ the user’s
  /// system channel settings prevail.
  Future<void> showNewMessageNotification({
    required String conversationId,
    required String senderName,
    required String messageText,
    required bool showDetail,
    required bool playSound,
    required bool vibrate,
  }) async {
    try {
      Logger.service(
        'NotificationService',
        'Attempting to show notification for $senderName: $messageText',
      );
      await initialize();

      // Use a stable notification id per conversation so the latest replaces previous
      final int notificationId = conversationId.hashCode & 0x7fffffff;

      // Choose channel based on sound/vibration settings
      final String channelId = playSound && vibrate
          ? WKConstants.newMsgChannelID
          : playSound
          ? WKConstants.newMsgChannelSoundOnlyID
          : vibrate
          ? WKConstants.newMsgChannelVibrateOnlyID
          : WKConstants.newMsgChannelSilentID;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        'New message',
        channelDescription: 'New message notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: playSound,
        enableVibration: vibrate,
        category: AndroidNotificationCategory.message,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
        categoryIdentifier: 'message',
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      final body = showDetail ? messageText : 'Bạn có một tin nhắn mới';

      Logger.service(
        'NotificationService',
        'Showing notification ID=$notificationId, title=$senderName, body=$body',
      );

      await _plugin.show(
        notificationId,
        senderName,
        body,
        details,
        payload: conversationId,
      );

      // Trigger vibration manually if enabled (fallback method)
      if (vibrate) {
        try {
          final hasVibrator = await Vibration.hasVibrator();
          if (hasVibrator == true) {
            await Vibration.vibrate(duration: 250);
            Logger.service('NotificationService', 'Manual vibration triggered');
          } else {
            Logger.service('NotificationService', 'Device has no vibrator');
          }
        } catch (e) {
          Logger.error('Failed to trigger manual vibration', error: e);
        }
      }

      Logger.service('NotificationService', 'Notification shown successfully');
    } catch (e) {
      Logger.error('Failed to show notification', error: e);
    }
  }

  /// Test vibration functionality
  Future<void> testVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      Logger.service(
        'NotificationService',
        'Device has vibrator: $hasVibrator',
      );

      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 500);
        Logger.service('NotificationService', 'Test vibration completed');
      } else {
        Logger.service(
          'NotificationService',
          'Device does not support vibration',
        );
      }
    } catch (e) {
      Logger.error('Failed to test vibration', error: e);
    }
  }
}
