// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'QGIM';

  @override
  String get settings_title => 'Settings';

  @override
  String get language_title => 'Language';

  @override
  String get language_english => 'English';

  @override
  String get language_chinese => 'Chinese';

  @override
  String get text_size => 'Text Size';

  @override
  String get about => 'About';

  @override
  String get clear_images_cache => 'Clear Images Cache';

  @override
  String get cache_size_calculating => 'Calculating...';

  @override
  String get sign_out => 'Sign out';

  @override
  String get coming_soon => 'Coming soon';

  @override
  String get me_title => 'Me';

  @override
  String get me_user_placeholder => 'User';

  @override
  String get me_computer_login => 'Computer login';

  @override
  String get me_notifications => 'Notifications';

  @override
  String get me_setting => 'Setting';

  @override
  String get login_auth_title => 'Login Authentication';

  @override
  String get device_verification_required => 'Device Verification Required';

  @override
  String get device_verification_description =>
      'For your account security, QGIM needs to verify this device. We will send a verification code to your registered phone number.';

  @override
  String get phone_number => 'Phone Number';

  @override
  String get send_verification_code => 'Send Verification Code';

  @override
  String get verification_help_text =>
      'If you don\'t receive the code, please check your phone number or contact support.';

  @override
  String get cancel => 'Cancel';

  @override
  String get enter_verification_code => 'Enter Verification Code';

  @override
  String verification_code_sent_to(String phone) =>
      'Enter the verification code sent to $phone';

  @override
  String get verification_code_hint => '------';

  @override
  String get please_enter_verification_code => 'Please enter verification code';

  @override
  String get please_enter_complete_code =>
      'Please enter complete verification code';

  @override
  String get verify => 'Verify';

  @override
  String get resend_code => 'Resend Code';

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get notice => 'Notice';

  @override
  String get retry => 'Retry';

  @override
  String get new_chat => 'New Chat';

  @override
  String get no_conversations_yet => 'No conversations yet';

  @override
  String get start_new_conversation => 'Start a new conversation';

  @override
  String get oops_something_went_wrong => 'Oops! Something went wrong';

  @override
  String get loading_contacts => 'Loading contacts...';

  @override
  String get contacts => 'Contacts';

  @override
  String get copy => 'Copy';

  @override
  String get forward => 'Forward';

  @override
  String get delete => 'Delete';

  @override
  String get delete_message => 'Delete message';

  @override
  String get delete_message_confirm =>
      'Are you sure you want to delete this message?';

  @override
  String get delete_for_everyone_group => 'Delete for everyone in this group';

  @override
  String get delete_for_both_sides => 'Delete for both sides';

  @override
  String get deleted_for_everyone => 'Deleted for everyone';

  @override
  String get delete_failed => 'Delete failed';

  @override
  String failed_to_send_message(String error) =>
      'Failed to send message: $error';

  @override
  String get cannot_forward_message => 'Cannot forward this message';

  @override
  String get cannot_forward_image => 'Cannot forward this image';

  @override
  String get image_forwarded_successfully => 'Image forwarded successfully';

  @override
  String get account_logged_another_device =>
      'Your account logged in on another device';

  @override
  String get account_banned => 'Your account has been banned';

  @override
  String get official => 'Official';

  @override
  String get bot => 'Bot';

  @override
  String login_to_app(String appName) => 'Login to $appName';

  @override
  String get phone_number_label => 'Phone Number';

  @override
  String get password_label => 'Password';

  @override
  String get agree_terms => 'I agree to the Terms of Service and Privacy Policy';

  @override
  String get login_button => 'Login';

  @override
  String get register_button => 'Register';

  @override
  String get forgot_password => 'Forgot Password?';

  @override
  String get api_settings => 'API Settings';
}
