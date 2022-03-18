import 'dart:async';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'package:stack_trace_parser/stack_trace_parser.dart';

class AndroidPlatformExceptionEventProcessor implements EventProcessor {
  const AndroidPlatformExceptionEventProcessor();

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
    final plaformException = event.throwable;
    if (!(plaformException is PlatformException)) {
      return event;
    }

    final nativeStackTrace = plaformException.stacktrace;
    if (nativeStackTrace == null) {
      return event;
    }

    // PackageInfo has an internal cache, so no need to do it ourselves.
    final packageInfo = await PackageInfo.fromPlatform();
    return _processPlatformException(
      event,
      plaformException,
      nativeStackTrace,
      packageInfo.packageName,
    );
  }

  SentryEvent _processPlatformException(
    SentryEvent event,
    PlatformException exception,
    String nativeStackTrace,
    String packageName,
  ) {
    final e =
        _JvmExceptionFactory(packageName).fromJvmStackTrace(nativeStackTrace);

    return event.copyWith(
      exceptions: [
        ...?event.exceptions,
        ...e,
      ],
    );
  }
}

class _JvmExceptionFactory {
  const _JvmExceptionFactory(this.nativePackageName);

  final String nativePackageName;

  List<SentryException> fromJvmStackTrace(String exceptionAsString) {
    final jvmException = JvmException.parse(exceptionAsString);
    final jvmExceptions = <JvmException>[
      jvmException,
      ...?jvmException.causes,
      ...?jvmException.suppressed,
    ];

    return jvmExceptions.map((exception) {
      return exception.toSentryException(nativePackageName);
    }).toList(growable: false);
  }
}

extension on JvmException {
  SentryException toSentryException(String nativePackageName) {
    return SentryException(
      type: type,
      value: description,
      // thread is an int, not a string
      // threadId: exception.thread,
      stackTrace: SentryStackTrace(
        frames: stackTrace.map((e) {
          return e.toSentryStackFrame(nativePackageName);
        }).toList(growable: false),
      ),
    );
  }
}

extension on JvmFrame {
  SentryStackFrame toSentryStackFrame(String nativePackageName) {
    String? language;
    if (fileName?.endsWith('java') ?? false) {
      language = 'Java';
    } else if (fileName?.endsWith('kt') ?? false) {
      language = 'Kotlin';
    }

    String? absPath;
    if (package != null && fileName != null) {
      absPath = '$package.$fileName';
    }

    final skippedFrames = this.skippedFrames;
    final framesOmitted = skippedFrames == null ? null : [skippedFrames];

    return SentryStackFrame(
      lineNo: lineNumber,
      native: isNativeMethod,
      fileName: fileName,
      absPath: absPath,
      inApp: package?.startsWith(nativePackageName),
      framesOmitted: framesOmitted,
      function: method,
      platform: language,
      module: package,
    );
  }
}
