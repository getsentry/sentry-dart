import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import '../binding_utils.dart';
import '../sentry_flutter_options.dart';

typedef ErrorCallback = bool Function(Object exception, StackTrace stackTrace);

/// Integration which captures `PlatformDispatcher.onError`
/// See:
/// - https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html
///
/// Remarks:
/// - Only usable on Flutter >= 3.3.0.
///
/// This can be used instead of the [RunZonedGuardedIntegration]. Removing the
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
    final binding = BindingUtils.getWidgetsBindingInstance();

    if (binding == null) {
      return;
    }

    // WidgetsBinding works with WidgetsFlutterBinding and other custom bindings
    final wrapper = dispatchWrapper ??
        PlatformDispatcherWrapper(binding.platformDispatcher);

    _defaultOnError = wrapper.onError;

    _integrationOnError = (Object exception, StackTrace stackTrace) {
      final handledToReturn =
          _defaultOnError?.call(exception, stackTrace) ?? false;

      // As per docs, the app might crash on some platforms
      // after this is called.
      // https://master-api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html
      // https://master-api.flutter.dev/flutter/dart-ui/ErrorCallback.html
      final mechanism = Mechanism(
        type: 'PlatformDispatcher.onError',
        handled: false,
      );
      final throwableMechanism = ThrowableMechanism(mechanism, exception);

      var event = SentryEvent(
        throwable: throwableMechanism,
        level: SentryLevel.fatal,
        // ignore: invalid_use_of_internal_member
        timestamp: options.clock(),
      );

      // unawaited future
      hub.captureEvent(event, stackTrace: stackTrace);

      return handledToReturn;
    };

    wrapper.onError = _integrationOnError;
    dispatchWrapper = wrapper;

    options.sdk.addIntegration('OnErrorIntegration');
  }

  @override
  void close() async {
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

  final PlatformDispatcher _dispatcher;

  /// Should not be accessed if [isOnErrorSupported] == false
  ErrorCallback? get onError =>
      (_dispatcher as dynamic).onError as ErrorCallback?;

  /// Should not be accessed if [isOnErrorSupported] == false
  set onError(ErrorCallback? callback) {
    (_dispatcher as dynamic).onError = callback;
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
      return false;
    }
    return true;
  }
}
