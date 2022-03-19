import 'dart:async';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'package:stack_trace_parser/stack_trace_parser.dart';

class AndroidPlatformExceptionEventProcessor implements EventProcessor {
  const AndroidPlatformExceptionEventProcessor();

  // Because of obfuscation, we need to dynamically get the name
  static final platformExceptionType = (PlatformException).toString();

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {dynamic hint}) async {
    final plaformException = event.throwable;
    if (!(plaformException is PlatformException)) {
      return event;
    }

    final nativeStackTrace = plaformException.stacktrace;
    if (nativeStackTrace == null) {
      return event;
    }

    try {
      // PackageInfo has an internal cache, so no need to do it ourselves.
      final packageInfo = await PackageInfo.fromPlatform();
      return _processPlatformException(
        event,
        plaformException,
        nativeStackTrace,
        packageInfo.packageName,
      );
    } catch (_) {
      return event;
    }
  }

  SentryEvent _processPlatformException(
    SentryEvent event,
    PlatformException exception,
    String nativeStackTrace,
    String packageName,
  ) {
    final jvmException =
        _JvmExceptionFactory(packageName).fromJvmStackTrace(nativeStackTrace);

    final exceptions = _removePlatformExceptionStackTraceFromValue(
      event.exceptions,
      exception,
    );

    return event.copyWith(
      exceptions: [
        ...?exceptions,
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
    final exceptionCopy = List<SentryException>.from(exceptions);

    var sentryException = exceptionCopy
        .where((element) => element.type == platformExceptionType)
        .first;

    final exceptionIndex = exceptionCopy.indexOf(sentryException);
    exceptionCopy.remove(sentryException);

    // Remove stacktrace, so that the PlatformException value doesn't
    // include the chained exception.
    platformException = PlatformException(
      code: platformException.code,
      details: platformException.details,
      message: platformException.message,
    );

    sentryException = sentryException.copyWith(
      value: platformException.toString(),
    );

    exceptionCopy.insert(exceptionIndex, sentryException);

    return exceptionCopy;
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
        frames: stackTrace.asMap().entries.map((entry) {
          return entry.value.toSentryStackFrame(entry.key, nativePackageName);
        }).toList(growable: false),
      ),
    );
  }
}

extension on JvmFrame {
  SentryStackFrame toSentryStackFrame(int index, String nativePackageName) {
    final skippedFrames = this.skippedFrames;
    final framesOmitted =
        skippedFrames == null ? null : [index, index + skippedFrames];

    final absPath = '$package.$declaringClass';
    return SentryStackFrame(
      lineNo: lineNumber,
      native: isNativeMethod,
      fileName: fileName,
      absPath: absPath,
      inApp: package?.startsWith(nativePackageName),
      framesOmitted: framesOmitted,
      function: method,
      platform: 'java',
      module: package,
    );
  }
}
