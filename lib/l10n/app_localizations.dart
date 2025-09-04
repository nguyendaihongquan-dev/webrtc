import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'QGIM'**
  String get appTitle;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @language_title.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language_title;

  /// No description provided for @language_english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get language_english;

  /// No description provided for @language_chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get language_chinese;

  /// No description provided for @text_size.
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get text_size;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @clear_images_cache.
  ///
  /// In en, this message translates to:
  /// **'Clear Images Cache'**
  String get clear_images_cache;

  /// No description provided for @cache_size_calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get cache_size_calculating;

  /// No description provided for @sign_out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sign_out;

  /// No description provided for @coming_soon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get coming_soon;

  /// No description provided for @me_title.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me_title;

  /// No description provided for @me_user_placeholder.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get me_user_placeholder;

  /// No description provided for @me_computer_login.
  ///
  /// In en, this message translates to:
  /// **'Computer login'**
  String get me_computer_login;

  /// No description provided for @me_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get me_notifications;

  /// No description provided for @me_setting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get me_setting;

  /// No description provided for @login_auth_title.
  ///
  /// In en, this message translates to:
  /// **'Login Authentication'**
  String get login_auth_title;

  /// No description provided for @device_verification_required.
  ///
  /// In en, this message translates to:
  /// **'Device Verification Required'**
  String get device_verification_required;

  /// No description provided for @device_verification_description.
  ///
  /// In en, this message translates to:
  /// **'For your account security, QGIM needs to verify this device. We will send a verification code to your registered phone number.'**
  String get device_verification_description;

  /// No description provided for @phone_number.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone_number;

  /// No description provided for @send_verification_code.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get send_verification_code;

  /// No description provided for @verification_help_text.
  ///
  /// In en, this message translates to:
  /// **'If you don't receive the code, please check your phone number or contact support.'**
  String get verification_help_text;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @enter_verification_code.
  ///
  /// In en, this message translates to:
  /// **'Enter Verification Code'**
  String get enter_verification_code;

  /// No description provided for @verification_code_sent_to.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to {phone}'**
  String verification_code_sent_to(String phone);

  /// No description provided for @verification_code_hint.
  ///
  /// In en, this message translates to:
  /// **'------'**
  String get verification_code_hint;

  /// No description provided for @please_enter_verification_code.
  ///
  /// In en, this message translates to:
  /// **'Please enter verification code'**
  String get please_enter_verification_code;

  /// No description provided for @please_enter_complete_code.
  ///
  /// In en, this message translates to:
  /// **'Please enter complete verification code'**
  String get please_enter_complete_code;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resend_code.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resend_code;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @notice.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get notice;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @new_chat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get new_chat;

  /// No description provided for @no_conversations_yet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get no_conversations_yet;

  /// No description provided for @start_new_conversation.
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation'**
  String get start_new_conversation;

  /// No description provided for @oops_something_went_wrong.
  ///
  /// In en, this message translates to:
  /// **'Oops! Something went wrong'**
  String get oops_something_went_wrong;

  /// No description provided for @loading_contacts.
  ///
  /// In en, this message translates to:
  /// **'Loading contacts...'**
  String get loading_contacts;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @delete_message.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get delete_message;

  /// No description provided for @delete_message_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message?'**
  String get delete_message_confirm;

  /// No description provided for @delete_for_everyone_group.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone in this group'**
  String get delete_for_everyone_group;

  /// No description provided for @delete_for_both_sides.
  ///
  /// In en, this message translates to:
  /// **'Delete for both sides'**
  String get delete_for_both_sides;

  /// No description provided for @deleted_for_everyone.
  ///
  /// In en, this message translates to:
  /// **'Deleted for everyone'**
  String get deleted_for_everyone;

  /// No description provided for @delete_failed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get delete_failed;

  /// No description provided for @failed_to_send_message.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message: {error}'**
  String failed_to_send_message(String error);

  /// No description provided for @cannot_forward_message.
  ///
  /// In en, this message translates to:
  /// **'Cannot forward this message'**
  String get cannot_forward_message;

  /// No description provided for @cannot_forward_image.
  ///
  /// In en, this message translates to:
  /// **'Cannot forward this image'**
  String get cannot_forward_image;

  /// No description provided for @image_forwarded_successfully.
  ///
  /// In en, this message translates to:
  /// **'Image forwarded successfully'**
  String get image_forwarded_successfully;

  /// No description provided for @account_logged_another_device.
  ///
  /// In en, this message translates to:
  /// **'Your account logged in on another device'**
  String get account_logged_another_device;

  /// No description provided for @account_banned.
  ///
  /// In en, this message translates to:
  /// **'Your account has been banned'**
  String get account_banned;

  /// No description provided for @official.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get official;

  /// No description provided for @bot.
  ///
  /// In en, this message translates to:
  /// **'Bot'**
  String get bot;

  /// No description provided for @login_to_app.
  ///
  /// In en, this message translates to:
  /// **'Login to {appName}'**
  String login_to_app(String appName);

  /// No description provided for @phone_number_label.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone_number_label;

  /// No description provided for @password_label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password_label;

  /// No description provided for @agree_terms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and Privacy Policy'**
  String get agree_terms;

  /// No description provided for @login_button.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login_button;

  /// No description provided for @register_button.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register_button;

  /// No description provided for @forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgot_password;

  /// No description provided for @api_settings.
  ///
  /// In en, this message translates to:
  /// **'API Settings'**
  String get api_settings;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
