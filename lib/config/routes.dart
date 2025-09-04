import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/wk_login_screen.dart';
import '../screens/home/tab_navigation_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/video_call/video_call_screen.dart';
import '../providers/video_call_provider.dart';
import '../models/video_call_model.dart';

class AppRoutes {
  // Splash screen
  static const String splash = '/';

  // Login system routes
  static const String wkLogin = '/wk-login';

  // App routes
  static const String home = '/home';
  static const String chatList = '/chat-list';
  static const String chat = '/chat';
  static const String videoCall = '/video-call';

  static final Map<String, WidgetBuilder> routes = {
    // Splash screen
    splash: (context) => const SplashScreen(),

    // Login system routes
    wkLogin: (context) => const WKLoginScreen(),

    // App routes
    home: (context) => const TabNavigationScreen(), // Main tab navigation
    chatList: (context) => const ChatListScreen(),
    // chat route removed from simple routes - handled in generateRoute
  };

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // For routes that need parameters
    switch (settings.name) {
      case chat:
        final args = settings.arguments as Map<String, dynamic>?;
        return CupertinoPageRoute(
          builder: (_) => ChatScreen(
            channelId: args?['channelId'] ?? '',
            channelType: args?['channelType'] ?? 1, // Default to personal chat
            initialAroundOrderSeq: args?['aroundOrderSeq'] ?? 0,
            imagePath: args?['imagePath'], // Optional image to send immediately
          ),
        );

      case videoCall:
        final args = settings.arguments as Map<String, dynamic>?;
        return CupertinoPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => VideoCallProvider(),
            child: VideoCallScreen(
              channelId: args?['channelId'] ?? '',
              callerId: args?['callerId'] ?? '',
              callerName: args?['callerName'] ?? 'Unknown',
              callerAvatar: args?['callerAvatar'],
              participants: List<String>.from(args?['participants'] ?? []),
              callType: args?['callType'] ?? VideoCallType.p2p,
              isIncoming: args?['isIncoming'] ?? false,
            ),
          ),
        );

      default:
        break;
    }

    // Default fallback route
    return CupertinoPageRoute(
      builder: (_) =>
          const Scaffold(body: Center(child: Text('Route not found!'))),
    );
  }

  /// Get the initial route - always start with splash screen
  static String getInitialRoute() {
    return splash;
  }

  /// Navigation helper methods
  static void navigateToLogin(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, wkLogin, (route) => false);
  }

  static void navigateToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, home, (route) => false);
  }

  static void navigateToVideoCall(
    BuildContext context, {
    required String channelId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required List<String> participants,
    required VideoCallType callType,
    bool isIncoming = false,
  }) {
    Navigator.pushNamed(
      context,
      videoCall,
      arguments: {
        'channelId': channelId,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'participants': participants,
        'callType': callType,
        'isIncoming': isIncoming,
      },
    );
  }
}
