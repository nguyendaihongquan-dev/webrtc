import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() async {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);

    print('SplashScreen: Checking auth status...');

    // Initialize NewFriendsProvider early to ensure message listener is setup
    try {
      print(
        '🔍 FRIENDS DEBUG: Initializing NewFriendsProvider from SplashScreen...',
      );
      print(
        '🔍 FRIENDS DEBUG: NewFriendsProvider initialized successfully from SplashScreen',
      );
    } catch (e) {
      print(
        '🔍 FRIENDS DEBUG: Error initializing NewFriendsProvider from SplashScreen: $e',
      );
    }

    // Wait for initialization to complete
    while (!loginProvider.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    print(
      'SplashScreen: LoginProvider initialized. isLoggedIn: ${loginProvider.isLoggedIn}',
    );

    // Add a small delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Navigate based on login status
    if (loginProvider.isLoggedIn) {
      print('SplashScreen: User is logged in, navigating to home');
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      print('SplashScreen: User not logged in, navigating to login');
      Navigator.pushReplacementNamed(context, AppRoutes.wkLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or icon
            Icon(Icons.chat, size: 80, color: Colors.white),
            SizedBox(height: 24),

            // App name
            Text(
              'QGIM',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 48),

            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
