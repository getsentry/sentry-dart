import 'dart:async';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'package:stack_trace_parser/stack_trace_parser.dart';

class PlatformExceptionEventProcessor implements EventProcessor {
  final SentryOptions _options;
  PackageInfo? _packageInfo;

  PlatformExceptionEventProcessor(this._options);

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
    final plaformException = event.throwable;
    if (plaformException is PlatformException) {
      final nativeStackTrace = plaformException.stacktrace;
      if (nativeStackTrace == null) {
        return event;
      }
      _packageInfo = await PackageInfo.fromPlatform();
      return processPlatformException(
          event, plaformException, nativeStackTrace);
    } else {
      return event;
    }
  }

  SentryEvent processPlatformException(
    SentryEvent event,
    PlatformException exception,
    String nativeStackTrace,
  ) {
    if (!_options.platformChecker.platform.isAndroid) {
      return event;
    }
    final e = JvmExceptionFactory(_packageInfo!.packageName)
        .fromJvmStackTrace(nativeStackTrace);
    return event.copyWith(
      exceptions: [
        ...?event.exceptions,
        ...e,
      ],
    );
  }
}

class JvmExceptionFactory {
  JvmExceptionFactory(this.nativePackageName);

  final String nativePackageName;

  List<SentryException> fromJvmStackTrace(String exceptionAsString) {
    final jvmException = JvmException.parse(exceptionAsString);
    final jvmExceptions = <JvmException>[
      jvmException,
      ...?jvmException.causes,
      ...?jvmException.suppressed,
    ];

    return jvmExceptions.map((exception) {
      return SentryException(
        type: exception.type,
        value: exception.description,
        // thread is an int, not a string
        // threadId: exception.thread,
        stackTrace: SentryStackTrace(
          frames: exception.stackTrace.map((e) {
            return SentryStackFrame(
              lineNo: e.lineNumber,
              native: e.isNativeMethod,
              fileName: e.fileName,
              absPath: e.package,
              inApp: e.package?.startsWith(nativePackageName),
              //framesOmitted: e.skippedFrames,
              function: e.method,
              platform: 'java', // or Kotlin or any other JVM language
            );
          }).toList(growable: false),
        ),
      );
    }).toList(growable: false);
  }
}
