import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:qgim_client_flutter/services/module_gatekeeper.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/conversation_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ModuleGatekeeper.instance.loadFromStorage();

  await NotificationService.instance.initialize();
  runApp(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LoginProvider()),
          ChangeNotifierProxyProvider<LoginProvider, ChatProvider>(
            create: (context) => ChatProvider(
              Provider.of<LoginProvider>(context, listen: false),
            ),
            update: (context, loginProvider, previousChatProvider) {
              final provider =
                  previousChatProvider ?? ChatProvider(loginProvider);
              provider.onAuthChanged();
              return provider;
            },
          ),
          ChangeNotifierProxyProvider<LoginProvider, ConversationProvider>(
            create: (context) => ConversationProvider(),
            update: (context, loginProvider, previousConversationProvider) {
              final provider =
                  previousConversationProvider ?? ConversationProvider();
              provider.setLoginProvider(loginProvider);
              return provider;
            },
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}
