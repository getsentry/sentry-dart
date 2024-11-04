import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

/// Helper to safely invoke native methods. Any errors are logged and ignored.
@internal
mixin SentryNativeSafeInvoker {
  SentryFlutterOptions get options;

  Future<T?> tryCatchAsync<T>(
      String nativeMethodName, Future<T?> Function() fn) async {
    try {
      return await fn();
    } catch (error, stackTrace) {
      _logError(nativeMethodName, error, stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
      return null;
    }
  }

  T? tryCatchSync<T>(String nativeMethodName, T? Function() fn) {
    try {
      return fn();
    } catch (error, stackTrace) {
      _logError(nativeMethodName, error, stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
      return null;
    }
  }

  void _logError(String nativeMethodName, Object error, StackTrace stackTrace) {
    options.logger(
      SentryLevel.error,
      'Native call `$nativeMethodName` failed',
      exception: error,
      stackTrace: stackTrace,
    );
  }
}
