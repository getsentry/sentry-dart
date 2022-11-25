import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

/// Integration that capture errors on the [FlutterError.onError] handler.
///
/// Remarks:
///   - Most UI and layout related errors (such as
///     [these](https://flutter.dev/docs/testing/common-errors)) are AssertionErrors
///     and are stripped in release mode. See [Flutter build modes](https://flutter.dev/docs/testing/build-modes).
///     So they only get caught in debug mode.
class FlutterErrorIntegration extends Integration<SentryFlutterOptions> {
  /// Reference to the original handler.
  FlutterExceptionHandler? _defaultOnError;

  /// The error handler set by this integration.
  FlutterExceptionHandler? _integrationOnError;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _defaultOnError = FlutterError.onError;
    _integrationOnError = (FlutterErrorDetails errorDetails) async {
      final exception = errorDetails.exception;

      options.logger(
        SentryLevel.debug,
        'Capture from onError $exception',
      );

      if (errorDetails.silent != true || options.reportSilentFlutterErrors) {
        final context = errorDetails.context?.toDescription();

        final collector = errorDetails.informationCollector?.call() ?? [];
        final information =
            (StringBuffer()..writeAll(collector, '\n')).toString();
        // errorDetails.library defaults to 'Flutter framework' even though it
        // is nullable. We do null checks anyway, just to be sure.
        final library = errorDetails.library;

        final flutterErrorDetails = <String, String>{
          // This is a message which should make sense if written after the
          // word `thrown`:
          // https://api.flutter.dev/flutter/foundation/FlutterErrorDetails/context.html
          if (context != null) 'context': 'thrown $context',
          if (collector.isNotEmpty) 'information': information,
          if (library != null) 'library': library,
        };

        options.logger(
          SentryLevel.error,
          errorDetails.toStringShort(),
          logger: 'sentry.flutterError',
          exception: exception,
          stackTrace: errorDetails.stack,
        );

        // FlutterError doesn't crash the App.
        final mechanism = Mechanism(
          type: 'FlutterError',
          handled: true,
        );
        final throwableMechanism = ThrowableMechanism(mechanism, exception);

        var event = SentryEvent(
          throwable: throwableMechanism,
          level: SentryLevel.fatal,
          contexts: flutterErrorDetails.isNotEmpty
              ? (Contexts()..['flutter_error_details'] = flutterErrorDetails)
              : null,
          // ignore: invalid_use_of_internal_member
          timestamp: options.clock(),
        );

        await hub.captureEvent(event, stackTrace: errorDetails.stack);
        // we don't call Zone.current.handleUncaughtError because we'd like
        // to set a specific mechanism for FlutterError.onError.
      } else {
        options.logger(
          SentryLevel.debug,
          'Error not captured due to [FlutterErrorDetails.silent], '
          'Enable [SentryFlutterOptions.reportSilentFlutterErrors] '
          'if you wish to capture silent errors',
        );
      }
      // Call original handler, regardless of `errorDetails.silent` or
      // `reportSilentFlutterErrors`. This ensures, that we don't swallow
      // messages.
      if (_defaultOnError != null) {
        _defaultOnError!(errorDetails);
      }
    };
    FlutterError.onError = _integrationOnError;

    options.sdk.addIntegration('flutterErrorIntegration');
  }

  @override
  FutureOr<void> close() async {
    /// Restore default if the integration error is still set.
    if (FlutterError.onError == _integrationOnError) {
      FlutterError.onError = _defaultOnError;
      _defaultOnError = null;
      _integrationOnError = null;
    }
  }
}
