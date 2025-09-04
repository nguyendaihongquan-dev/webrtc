import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:ionicons/ionicons.dart';
import '../../providers/auth_provider.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';

/// Main login screen that replicates Android WKLoginActivity
class WKLoginScreen extends StatefulWidget {
  const WKLoginScreen({super.key});

  @override
  State<WKLoginScreen> createState() => _WKLoginScreenState();
}

class _WKLoginScreenState extends State<WKLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isAgreedToTerms = false;
  bool _kickInfoShown = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUserInfo();

    // Show info dialog if navigated due to kick or ban (Android uses from==1 or 2)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (!_kickInfoShown && args is Map && args['from'] != null) {
        final int from = args['from'] is int ? args['from'] as int : 0;
        if (from == 1 || from == 2) {
          final content = from == 1
              ? AppLocalizations.of(context)!.account_logged_another_device
              : AppLocalizations.of(context)!.account_banned;
          _showInfoDialog(content);
          _kickInfoShown = true;
        }
      }
    });
  }

  void _loadSavedUserInfo() async {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);

    // First try to get from current user (if still logged in)
    if (loginProvider.currentUser != null) {
      final user = loginProvider.currentUser!;
      if (user.phone != null && user.phone!.isNotEmpty) {
        _phoneController.text = user.phone!;
        return;
      }
    }

    // If no current user, try to get last login info for auto-fill
    final lastLoginInfo = await loginProvider.getLastLoginInfo();
    if (lastLoginInfo['phone'] != null && lastLoginInfo['phone']!.isNotEmpty) {
      setState(() {
        _phoneController.text = lastLoginInfo['phone']!;
      });
    }
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isAgreedToTerms) {
      _showErrorDialog(ErrorMessages.agreeAuthTips);
      return;
    }

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    // Validate Chinese phone number length (hardcoded for China +86)
    if (phone.length != LoginValidation.chinesePhoneLength) {
      _showErrorDialog(ErrorMessages.phoneError);
      return;
    }

    // Validate password length
    if (password.length < LoginValidation.minPasswordLength ||
        password.length > LoginValidation.maxPasswordLength) {
      _showErrorDialog(ErrorMessages.pwdLengthError);
      return;
    }

    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final username = "0086" + phone; // Hardcoded Chinese country code

    // Save last login info for auto-fill (save before attempting login)
    await loginProvider.saveLastLoginInfo(phone, "0086");

    final success = await loginProvider.login(username, password);

    if (mounted) {
      if (success) {
        // Navigate to main app
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showErrorDialog(loginProvider.error);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.notice),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Consumer<LoginProvider>(
          builder: (context, loginProvider, child) {
            return Column(
              children: [
                // Header with title
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.7),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: AnimationConfiguration.staggeredList(
                    position: 0,
                    duration: const Duration(milliseconds: 450),
                    child: SlideAnimation(
                      curve: Curves.easeOutQuart,
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Text(
                          AppLocalizations.of(
                            context,
                          )!.login_to_app(AppInfo.appName),
                          style: GoogleFonts.notoSansSc(
                            fontSize: 32.0,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF374151),
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.9),
                                offset: const Offset(0.5, 0.5),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),

                // Content Container
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBFC),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32.0),
                        topRight: Radius.circular(32.0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          offset: const Offset(2, 2),
                          blurRadius: 6,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.9),
                          offset: const Offset(-5, -5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: AnimationLimiter(
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: AnimationConfiguration.toStaggeredList(
                              duration: const Duration(milliseconds: 450),
                              childAnimationBuilder: (widget) => SlideAnimation(
                                curve: Curves.easeOutQuart,
                                verticalOffset: 50.0,
                                child: FadeInAnimation(child: widget),
                              ),
                              children: [
                                const SizedBox(height: 20.0),

                                // Phone number input with country code
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(24.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        offset: const Offset(3, 3),
                                        blurRadius: 8,
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.9),
                                        offset: const Offset(-3, -3),
                                        blurRadius: 10,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.7),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 16.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF3B82F6,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            20.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.04,
                                              ),
                                              offset: const Offset(2, 2),
                                              blurRadius: 4,
                                            ),
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              offset: const Offset(-2, -2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '+86',
                                          style: GoogleFonts.notoSansSc(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(
                                              0xFF3B82F6,
                                            ),
                                            shadows: [
                                              Shadow(
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                offset: const Offset(
                                                  0.5,
                                                  0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                          ),
                                          child: TextFormField(
                                            controller: _phoneController,
                                            keyboardType: TextInputType.phone,
                                            style: GoogleFonts.notoSansSc(
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF374151),
                                            ),
                                            decoration: InputDecoration(
                                              labelText: AppLocalizations.of(
                                                context,
                                              )!.phone_number_label,
                                              labelStyle:
                                                  GoogleFonts.notoSansSc(
                                                    fontSize: 14.0,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(
                                                      0xFF6B7280,
                                                    ),
                                                  ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              focusedErrorBorder:
                                                  InputBorder.none,
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return ErrorMessages
                                                    .nameNotNull;
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16.0),

                                // Password input
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(24.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        offset: const Offset(3, 3),
                                        blurRadius: 8,
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.9),
                                        offset: const Offset(-3, -3),
                                        blurRadius: 10,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.7),
                                      width: 1,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 4,
                                  ),
                                  child: TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    style: GoogleFonts.notoSansSc(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF374151),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: AppLocalizations.of(
                                        context,
                                      )!.password_label,
                                      labelStyle: GoogleFonts.notoSansSc(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF6B7280),
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      suffixIcon: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isPasswordVisible =
                                                !_isPasswordVisible;
                                          });
                                        },
                                        child: Container(
                                          width: 46,
                                          height: 46,
                                          margin: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF8B5CF6,
                                            ).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.04,
                                                ),
                                                offset: const Offset(2, 2),
                                                blurRadius: 4,
                                              ),
                                              BoxShadow(
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                                offset: const Offset(-2, -2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            _isPasswordVisible
                                                ? Ionicons.eye
                                                : Ionicons.eye_off,
                                            color: const Color(0xFF8B5CF6),
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return ErrorMessages.pwdNotNull;
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                                SizedBox(height: 20),

                                // Terms and conditions checkbox
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        offset: const Offset(3, 3),
                                        blurRadius: 8,
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.9),
                                        offset: const Offset(-3, -3),
                                        blurRadius: 10,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.7),
                                      width: 1,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isAgreedToTerms =
                                                !_isAgreedToTerms;
                                          });
                                        },
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: _isAgreedToTerms
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFF7F8FA),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.04,
                                                ),
                                                offset: const Offset(2, 2),
                                                blurRadius: 4,
                                              ),
                                              BoxShadow(
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                                offset: const Offset(-2, -2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                            border: Border.all(
                                              color: _isAgreedToTerms
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFE5E7EB),
                                              width: 2,
                                            ),
                                          ),
                                          child: _isAgreedToTerms
                                              ? Icon(
                                                  Ionicons.checkmark,
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                              : null,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isAgreedToTerms =
                                                  !_isAgreedToTerms;
                                            });
                                          },
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.agree_terms,
                                            style: GoogleFonts.notoSansSc(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF6B7280),
                                              shadows: [
                                                Shadow(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  offset: const Offset(
                                                    0.5,
                                                    0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 24),

                                // Login button
                                GestureDetector(
                                  onTap: loginProvider.isLoading
                                      ? null
                                      : _login,
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: 18),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF06B6D4),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          offset: const Offset(4, 4),
                                          blurRadius: 8,
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.95),
                                          offset: const Offset(-4, -4),
                                          blurRadius: 12,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.6),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: loginProvider.isLoading
                                        ? Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child:
                                                  const CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.login_button,
                                            style: GoogleFonts.notoSansSc(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                  ),
                                ),

                                SizedBox(height: 30),

                                // Base URL setting (if enabled)
                                if (loginProvider.appConfig?.canModifyApiUrl ==
                                    1)
                                  GestureDetector(
                                    onTap: _showBaseUrlDialog,
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F8FA),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.04,
                                            ),
                                            offset: const Offset(3, 3),
                                            blurRadius: 8,
                                          ),
                                          BoxShadow(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            offset: const Offset(-3, -3),
                                            blurRadius: 10,
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.7),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.api_settings,
                                        style: GoogleFonts.notoSansSc(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF6B7280),
                                          shadows: [
                                            Shadow(
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                              offset: const Offset(0.5, 0.5),
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showBaseUrlDialog() {
    // Implementation for base URL modification dialog
    // This would show a dialog to modify the API base URL
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
