import 'dart:async';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'package:stack_trace_parser/stack_trace_parser.dart';

class AndroidPlatformExceptionEventProcessor implements EventProcessor {
  const AndroidPlatformExceptionEventProcessor();

  // Because of obfuscation, we need to dynamically get the name
  static final platformExceptionType =
      (PlatformException).runtimeType.toString();

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
    final jvmException =
        _JvmExceptionFactory(packageName).fromJvmStackTrace(nativeStackTrace);

    return event.copyWith(
      exceptions: [
        ...?_removePlatformExceptionStackTraceFromValue(
            event.exceptions, exception),
        ...jvmException,
      ],
    );
  }

  /// Remove the StackTrace from [dioError] so the message on Sentry looks
  /// much better.
  List<SentryException>? _removePlatformExceptionStackTraceFromValue(
    List<SentryException>? exceptions,
    PlatformException platformException,
  ) {
    if (exceptions == null || exceptions.isEmpty) {
      return null;
    }

    var platformExceptionSentryException = exceptions
        .where((element) => element.type == platformExceptionType)
        .first;

    final exceptionIndex = exceptions.indexOf(platformExceptionSentryException);
    exceptions.remove(platformExceptionSentryException);

    // Remove stacktrace, so that the PlatformException value doesn't
    // include the chained exception.
    platformException = PlatformException(
      code: platformException.code,
      details: platformException.details,
      message: platformException.message,
    );

    platformExceptionSentryException =
        platformExceptionSentryException.copyWith(
      value: platformException.toString(),
    );

    exceptions.insert(exceptionIndex, platformExceptionSentryException);

    return exceptions;
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
    final typeParts = type?.split('.');
    String? exceptionType;
    String? module;
    if (typeParts != null) {
      if (typeParts.length > 1) {
        exceptionType = typeParts.last;
      }
      typeParts.remove(typeParts.last);
      module = typeParts.join('.');
    }
    return SentryException(
      value: description,
      type: exceptionType,
      module: module,
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
    final skippedFrames = this.skippedFrames;
    final framesOmitted = skippedFrames == null ? null : [skippedFrames];

    return SentryStackFrame(
      lineNo: lineNumber,
      native: isNativeMethod,
      fileName: fileName,
      absPath: fileName,
      inApp: package?.startsWith(nativePackageName),
      framesOmitted: framesOmitted,
      function: method,
      platform: 'java',
      module: package,
    );
  }
}
