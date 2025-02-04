import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import '../integrations/on_error_integration.dart';
import '../sentry_flutter_options.dart';

/// This class wraps the `this as dynamic` hack in a type-safe manner.
/// It helps to introduce code, which uses newer features from Flutter
/// without breaking Sentry on older versions of Flutter.
///
/// Should not become part of public API.
@internal
class PlatformDispatcherWrapper {
  PlatformDispatcherWrapper(this._dispatcher);

  final PlatformDispatcher? _dispatcher;

  bool isMultiViewEnabled(SentryFlutterOptions options) {
    try {
      return ((_dispatcher as dynamic)?.implicitView as FlutterView?) == null;
    } on NoSuchMethodError {
      // This error is expected on pre 3.10.0 Flutter version
      return false;
    } catch (exception, stacktrace) {
      // This error is neither expected on pre 3.10.0 nor on >= 3.10.0 Flutter versions
      options.logger(
        SentryLevel.debug,
        'An unexpected exception was thrown, please create an issue at https://github.com/getsentry/sentry-dart/issues',
        exception: exception,
        stackTrace: stacktrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
      return false;
    }
  }

  /// Should not be accessed if [isOnErrorSupported] == false
  ErrorCallback? get onError =>
      (_dispatcher as dynamic)?.onError as ErrorCallback?;

  /// Should not be accessed if [isOnErrorSupported] == false
  set onError(ErrorCallback? callback) {
    (_dispatcher as dynamic)?.onError = callback;
  }

  bool isOnErrorSupported(SentryFlutterOptions options) {
    try {
      onError;
    } on NoSuchMethodError {
      // This error is expected on pre 3.1 Flutter version
      return false;
    } catch (exception, stacktrace) {
      // This error is neither expected on pre 3.1 nor on >= 3.1 Flutter versions
      options.logger(
        SentryLevel.debug,
        'An unexpected exception was thrown, please create an issue at https://github.com/getsentry/sentry-dart/issues',
        exception: exception,
        stackTrace: stacktrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
      return false;
    }
    return true;
  }
}
