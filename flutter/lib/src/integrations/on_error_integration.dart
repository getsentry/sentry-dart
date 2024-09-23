import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

// ignore: implementation_imports
import 'package:sentry/src/utils/stacktrace_utils.dart';

typedef ErrorCallback = bool Function(Object exception, StackTrace stackTrace);

/// Integration which captures `PlatformDispatcher.onError`
/// See:
/// - https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html
///
/// Remarks:
/// - Only usable on Flutter >= 3.3.0.
/// - Does not work on Flutter Web
///
/// This is used instead of [RunZonedGuardedIntegration]. Not using the
/// [RunZonedGuardedIntegration] results in a minimal improved startup time,
/// since creating [Zone]s is not cheap.
class OnErrorIntegration implements Integration<SentryFlutterOptions> {
  OnErrorIntegration({this.dispatchWrapper});

  ErrorCallback? _defaultOnError;
  ErrorCallback? _integrationOnError;
  PlatformDispatcherWrapper? dispatchWrapper;
  SentryFlutterOptions? _options;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _options = options;
    final binding = options.bindingUtils.instance;

    if (binding == null) {
      return;
    }

    // WidgetsBinding works with WidgetsFlutterBinding and other custom bindings
    final wrapper = dispatchWrapper ??
        PlatformDispatcherWrapper(binding.platformDispatcher);

    _defaultOnError = wrapper.onError;

    _integrationOnError = (Object exception, StackTrace stackTrace) {
      _options!.logger(
        SentryLevel.error,
        "Uncaught Platform Error",
        logger: 'sentry.platformError',
        exception: exception,
        stackTrace: stackTrace,
      );

      final handled = _defaultOnError?.call(exception, stackTrace) ?? true;

      // As per docs, the app might crash on some platforms
      // after this is called.
      // https://master-api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html
      // https://master-api.flutter.dev/flutter/dart-ui/ErrorCallback.html
      final mechanism = Mechanism(
        type: 'PlatformDispatcher.onError',
        handled: handled,
      );
      final throwableMechanism = ThrowableMechanism(mechanism, exception);

      var event = SentryEvent(
        throwable: throwableMechanism,
        level: SentryLevel.fatal,
        // ignore: invalid_use_of_internal_member
        timestamp: options.clock(),
      );

      // marks the span status if none to `internal_error` in case there's an
      // unhandled error
      hub.configureScope(
        (scope) => scope.span?.status ??= const SpanStatus.internalError(),
      );

      if (stackTrace == StackTrace.empty) {
        // ignore: invalid_use_of_internal_member
        stackTrace = getCurrentStackTrace();
      }

      // unawaited future
      hub.captureEvent(event, stackTrace: stackTrace);

      return handled;
    };

    wrapper.onError = _integrationOnError;
    dispatchWrapper = wrapper;

    options.sdk.addIntegration('OnErrorIntegration');
  }

  @override
  void close() {
    if (!(dispatchWrapper?.isOnErrorSupported(_options!) == true)) {
      // bail out
      return;
    }

    /// Restore default if the integration error is still set.
    if (dispatchWrapper?.onError == _integrationOnError) {
      dispatchWrapper?.onError = _defaultOnError;
      _defaultOnError = null;
      _integrationOnError = null;
    }
  }
}

/// This class wraps the `this as dynamic` hack in a type-safe manner.
/// It helps to introduce code, which uses newer features from Flutter
/// without breaking Sentry on older versions of Flutter.
// Should not become part of public API.
@visibleForTesting
class PlatformDispatcherWrapper {
  PlatformDispatcherWrapper(this._dispatcher);

  final PlatformDispatcher? _dispatcher;

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
