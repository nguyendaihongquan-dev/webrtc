import 'chat_view_locale.dart';

class PackageStrings {
  static final Map<String, ChatViewLocale> _localeObjects = {
    'en': ChatViewLocale.en,
    'zh': ChatViewLocale.zh,
  };

  static String _currentLocale = 'en';

  /// Set the current locale for the package strings (e.g., 'en', 'es').
  static void setLocale(String locale) {
    assert(
      _localeObjects.containsKey(locale),
      'Locale "$locale" not found. Please add it using PackageStrings.addLocaleObject("$locale", ChatViewLocale(...)) before setting.',
    );
    if (_localeObjects.containsKey(locale)) {
      _currentLocale = locale;
    }
  }

  /// Allow developers to add or override locales at runtime using a class
  static void addLocaleObject(String locale, ChatViewLocale localeObj) {
    _localeObjects[locale] = localeObj;
  }

  static ChatViewLocale get currentLocale =>
      _localeObjects[_currentLocale] ?? ChatViewLocale.en;
}
