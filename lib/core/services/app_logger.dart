import 'dart:developer' as developer;

abstract final class AppLogger {
  static const _name = 'finote';

  static void info(String message) {
    developer.log(message, name: _name);
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
