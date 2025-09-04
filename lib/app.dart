import 'package:flutter/material.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'utils/navigation_service.dart';
import 'config/constants.dart';
import 'l10n/app_localizations.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      navigatorKey: NavigationService.navigatorKey,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.generateRoute,
      initialRoute: AppRoutes.getInitialRoute(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
