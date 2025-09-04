import 'dart:developer' as developer;

/// Centralized logging utility for the application
class Logger {
  static const String _defaultTag = 'WuKongIM';
  
  /// Log levels
  static const int _levelDebug = 0;
  static const int _levelInfo = 1;
  static const int _levelWarning = 2;
  static const int _levelError = 3;
  
  /// Current log level (can be configured based on build mode)
  static int _currentLevel = _levelDebug;
  
  /// Set the minimum log level
  static void setLogLevel(int level) {
    _currentLevel = level;
  }
  
  /// Debug logging - for detailed debugging information
  static void debug(String message, {String? tag}) {
    if (_currentLevel <= _levelDebug) {
      developer.log(
        message,
        name: tag ?? _defaultTag,
        level: 500, // Debug level
      );
    }
  }
  
  /// Info logging - for general information
  static void info(String message, {String? tag}) {
    if (_currentLevel <= _levelInfo) {
      developer.log(
        message,
        name: tag ?? _defaultTag,
        level: 800, // Info level
      );
    }
  }
  
  /// Warning logging - for potential issues
  static void warning(String message, {String? tag}) {
    if (_currentLevel <= _levelWarning) {
      developer.log(
        message,
        name: tag ?? _defaultTag,
        level: 900, // Warning level
      );
    }
  }
  
  /// Error logging - for errors and exceptions
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_currentLevel <= _levelError) {
      developer.log(
        message,
        name: tag ?? _defaultTag,
        level: 1000, // Error level
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Service-specific loggers for better organization
  static void service(String serviceName, String message, {int level = _levelInfo}) {
    switch (level) {
      case _levelDebug:
        debug('[$serviceName] $message');
        break;
      case _levelInfo:
        info('[$serviceName] $message');
        break;
      case _levelWarning:
        warning('[$serviceName] $message');
        break;
      case _levelError:
        error('[$serviceName] $message');
        break;
    }
  }
  
  /// UI-specific logging
  static void ui(String component, String message, {int level = _levelDebug}) {
    service('UI:$component', message, level: level);
  }
  
  /// API-specific logging
  static void api(String endpoint, String message, {int level = _levelInfo}) {
    service('API:$endpoint', message, level: level);
  }
  
  /// Connection-specific logging
  static void connection(String message, {int level = _levelInfo}) {
    service('Connection', message, level: level);
  }
  
  /// Sync-specific logging
  static void sync(String type, String message, {int level = _levelInfo}) {
    service('Sync:$type', message, level: level);
  }
}
