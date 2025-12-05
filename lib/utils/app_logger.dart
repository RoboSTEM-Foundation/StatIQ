import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// A global logger instance configured to only output logs in debug mode.
/// 
/// In release mode, all logs are suppressed by using [Level.off].
/// In debug mode, logs are output with a pretty printer for readability.
/// 
/// Usage example:
/// ```dart
/// // Import the logger
/// import 'package:stat_iq/utils/app_logger.dart';
/// 
/// // Use it anywhere in your code
/// AppLogger.d('Debug message'); // Only shows in debug mode
/// AppLogger.i('Info message');
/// AppLogger.w('Warning message');
/// AppLogger.e('Error message');
/// ```
class AppLogger {
  // Private constructor to prevent instantiation
  AppLogger._();

  /// The underlying logger instance.
  /// Configured to use Level.off in release mode to suppress all logs.
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
    level: kDebugMode ? Level.debug : Level.off,
  );

  /// Log a debug message.
  /// Only outputs in debug mode.
  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log an info message.
  /// Only outputs in debug mode.
  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.i(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log a warning message.
  /// Only outputs in debug mode.
  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log an error message.
  /// Only outputs in debug mode.
  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log a trace message (verbose).
  /// Only outputs in debug mode.
  static void t(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.t(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log a fatal error message.
  /// Only outputs in debug mode.
  static void f(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.f(message, error: error, stackTrace: stackTrace);
    }
  }
}
