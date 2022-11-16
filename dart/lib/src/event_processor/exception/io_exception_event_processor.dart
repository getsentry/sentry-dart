import 'dart:io';

import '../../protocol.dart';
import 'exception_event_processor.dart';

ExceptionEventProcessor exceptionEventProcessor() =>
    IoExceptionEventProcessor();

class IoExceptionEventProcessor implements ExceptionEventProcessor {
  @override
  SentryEvent apply(SentryEvent event, {dynamic hint}) {
    final throwable = event.throwable;
    if (throwable is HttpException) {
      return applyHttpException(throwable, event);
    }
    if (throwable is SocketException) {
      return applySocketException(throwable, event);
    }
    if (throwable is FileSystemException) {
      return applyFileSystemException(throwable, event);
    }

    return event;
  }

  // https://api.dart.dev/stable/dart-io/HttpException-class.html
  SentryEvent applyHttpException(HttpException exception, SentryEvent event) {
    final uri = exception.uri;
    if (uri == null) {
      return event;
    }
    return event.copyWith(
      request: event.request ?? SentryRequest.fromUri(uri: uri),
    );
  }

  // https://api.dart.dev/stable/dart-io/SocketException-class.html
  SentryEvent applySocketException(
    SocketException exception,
    SentryEvent event,
  ) {
    final address = exception.address;
    final osError = exception.osError;
    if (address == null) {
      return event.copyWith(
        exceptions: [
          // OSError is the underlying error
          // https://api.dart.dev/stable/dart-io/SocketException/osError.html
          // https://api.dart.dev/stable/dart-io/OSError-class.html
          if (osError != null) _sentryExceptionfromOsError(osError),
          ...?event.exceptions,
        ],
      );
    }
    SentryRequest? request;
    try {
      var uri = Uri.parse(address.host);
      request = SentryRequest.fromUri(uri: uri);
    } catch (_) {}

    return event.copyWith(
      request: event.request ?? request,
      exceptions: [
        // OSError is the underlying error
        // https://api.dart.dev/stable/dart-io/SocketException/osError.html
        // https://api.dart.dev/stable/dart-io/OSError-class.html
        if (osError != null) _sentryExceptionfromOsError(osError),
        ...?event.exceptions,
      ],
    );
  }

  // https://api.dart.dev/stable/dart-io/FileSystemException-class.html
  SentryEvent applyFileSystemException(
    FileSystemException exception,
    SentryEvent event,
  ) {
    final osError = exception.osError;
    return event.copyWith(
      exceptions: [
        // OSError is the underlying error
        // https://api.dart.dev/stable/dart-io/FileSystemException/osError.html
        // https://api.dart.dev/stable/dart-io/OSError-class.html
        if (osError != null) _sentryExceptionfromOsError(osError),
        ...?event.exceptions,
      ],
    );
  }
}

SentryException _sentryExceptionfromOsError(OSError osError) {
  return SentryException(
    type: osError.runtimeType.toString(),
    value: osError.toString(),
    // osError.errorCode is likely a posix signal
    // https://develop.sentry.dev/sdk/event-payloads/types/#mechanismmeta
    mechanism: Mechanism(
      type: 'OSError',
      meta: {
        'errno': osError.errorCode,
      },
    ),
  );
}
