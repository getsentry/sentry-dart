import 'dart:io';

import '../../debug_logger.dart';
import '../../hint.dart';
import '../../protocol.dart';
import '../../sentry_options.dart';
import 'exception_event_processor.dart';

ExceptionEventProcessor exceptionEventProcessor(SentryOptions options) =>
    IoExceptionEventProcessor(options);

class IoExceptionEventProcessor implements ExceptionEventProcessor {
  IoExceptionEventProcessor(this._options);

  final SentryOptions _options;

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    final throwable = event.throwable;
    if (throwable is HttpException) {
      return _applyHttpException(throwable, event);
    }
    if (throwable is SocketException) {
      return _applySocketException(throwable, event);
    }
    if (throwable is FileSystemException) {
      return _applyFileSystemException(throwable, event);
    }

    return event;
  }

  // https://api.dart.dev/stable/dart-io/HttpException-class.html
  SentryEvent _applyHttpException(HttpException exception, SentryEvent event) {
    final uri = exception.uri;
    if (uri == null) {
      return event;
    }
    return event..request = event.request ?? SentryRequest.fromUri(uri: uri);
  }

  // https://api.dart.dev/stable/dart-io/SocketException-class.html
  SentryEvent _applySocketException(
    SocketException exception,
    SentryEvent event,
  ) {
    final osError = exception.osError;
    SentryException? osException;
    List<SentryException>? exceptions = event.exceptions;
    if (osError != null) {
      // OSError is the underlying error
      // https://api.dart.dev/stable/dart-io/SocketException/osError.html
      // https://api.dart.dev/stable/dart-io/OSError-class.html
      osException = _sentryExceptionFromOsError(osError);
      final exception = event.exceptions?.firstOrNull;
      if (exception != null) {
        exception.addException(osException);
      } else {
        exceptions = [osException];
      }
    } else {
      exceptions = event.exceptions;
    }

    final address = exception.address;
    if (address == null) {
      event.exceptions = exceptions;
      return event;
    }
    SentryRequest? request;
    try {
      var uri = Uri.parse(address.host);
      request = SentryRequest.fromUri(uri: uri);
    } catch (exception, stackTrace) {
      debugLogger.error(
        'Could not parse ${address.host} to Uri',
        category: 'exception_processor',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }

    return event
      ..request = event.request ?? request
      ..exceptions = exceptions;
  }

  // https://api.dart.dev/stable/dart-io/FileSystemException-class.html
  SentryEvent _applyFileSystemException(
    FileSystemException exception,
    SentryEvent event,
  ) {
    final osError = exception.osError;

    if (osError != null) {
      // OSError is the underlying error
      // https://api.dart.dev/stable/dart-io/SocketException/osError.html
      // https://api.dart.dev/stable/dart-io/OSError-class.html
      final osException = _sentryExceptionFromOsError(osError);
      final exception = event.exceptions?.firstOrNull;
      if (exception != null) {
        exception.addException(osException);
      } else {
        event.exceptions = [osException];
      }
    }
    return event;
  }
}

SentryException _sentryExceptionFromOsError(OSError osError) {
  return SentryException(
    type: osError.runtimeType.toString(),
    value: osError.toString(),
    // osError.errorCode is likely a posix signal
    // https://develop.sentry.dev/sdk/event-payloads/types/#mechanismmeta
    mechanism: Mechanism(
      type: 'OSError',
      meta: {
        'errno': {'number': osError.errorCode},
      },
      source: 'osError',
    ),
  );
}
