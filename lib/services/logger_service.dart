import 'package:flutter/foundation.dart';

/// Logger service for production-safe logging
/// Only logs in debug mode unless explicitly specified
class LoggerService {
  // Check if we're in debug mode (controlled by --dart-define=DEBUG=true)
  static const bool _debugMode = bool.fromEnvironment('DEBUG', defaultValue: kDebugMode);
  
  /// Log debug information (only in debug mode)
  static void debug(String message, [String? tag]) {
    if (_debugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('🔍 $prefix $message');
    }
  }
  
  /// Log error messages (always logged, with details only in debug mode)
  static void error(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    final prefix = tag != null ? '[$tag]' : '';
    debugPrint('❌ $prefix $message');
    
    if (_debugMode && error != null) {
      debugPrint('Details: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }
  
  /// Log informational messages (always logged in production)
  static void info(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag]' : '';
    debugPrint('ℹ️ $prefix $message');
  }
  
  /// Log warning messages (always logged)
  static void warning(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag]' : '';
    debugPrint('⚠️ $prefix $message');
  }
  
  /// Log success messages (only in debug mode)
  static void success(String message, [String? tag]) {
    if (_debugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('✅ $prefix $message');
    }
  }
}
