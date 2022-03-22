import 'dart:async';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../sentry_flutter.dart';
import '../jvm/jvm_exception.dart';
import '../jvm/jvm_frame.dart';

/// Transforms an Android PlatformException to a human readable SentryException
class AndroidPlatformExceptionEventProcessor implements EventProcessor {
  const AndroidPlatformExceptionEventProcessor(this._options);

  final SentryFlutterOptions _options;

  // Because of obfuscation, we need to dynamically get the name
  static final _platformExceptionType = (PlatformException).toString();

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
    } catch (e, stackTrace) {
      _options.logger(
        SentryLevel.info,
        "Couldn't prettify PlatformException. "
        'The exception will still be reported.',
        exception: e,
        stackTrace: stackTrace,
      );
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

  /// Remove the StackTrace from [PlatformException] so the message on Sentry
  /// looks much better.
  List<SentryException>? _removePlatformExceptionStackTraceFromValue(
    List<SentryException>? exceptions,
    PlatformException platformException,
  ) {
    if (exceptions == null || exceptions.isEmpty) {
      return null;
    }
    final exceptionCopy = List<SentryException>.from(exceptions);

    final sentryExceptions = exceptionCopy
        .where((element) => element.type == _platformExceptionType);
    if (sentryExceptions.isEmpty) {
      return [];
    }
    var sentryException = sentryExceptions.first;

    final exceptionIndex = exceptionCopy.indexOf(sentryException);
    exceptionCopy.remove(sentryException);

    // Remove stacktrace, so that the PlatformException value doesn't
    // include the chained exception.
    // PlatformException.stackTrace is an empty string so that
    // PlatformException.toString() results in
    // `PlatformException(error, Exception Message, null, )`
    // instead of
    // `PlatformException(error, Exception Message, null, null)`.
    // While `null` for `PlatformException.stackTrace` is technically correct
    // it's semantically wrong.
    platformException = PlatformException(
      code: platformException.code,
      details: platformException.details,
      message: platformException.message,
      stacktrace: '',
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
    String? exceptionType;
    String? module;
    final typeParts = type?.split('.');
    if (typeParts != null) {
      if (typeParts.length > 1) {
        exceptionType = typeParts.last;
      }
      typeParts.remove(typeParts.last);
      module = typeParts.join('.');
    }
    final stackFrames = stackTrace.asMap().entries.map((entry) {
      return entry.value.toSentryStackFrame(entry.key, nativePackageName);
    }).toList(growable: false);

    return SentryException(
      value: description,
      type: exceptionType,
      module: module,
      stackTrace: SentryStackTrace(
        frames: stackFrames.reversed.toList(growable: false),
      ),
    );
  }
}

extension on JvmFrame {
  SentryStackFrame toSentryStackFrame(int index, String nativePackageName) {
    final skippedFrames = this.skippedFrames;
    final framesOmitted =
        skippedFrames == null ? null : [index, index + skippedFrames];

    return SentryStackFrame(
      lineNo: lineNumber,
      native: isNativeMethod,
      fileName: fileName,
      inApp: className?.startsWith(nativePackageName),
      framesOmitted: framesOmitted,
      function: method,
      platform: 'java',
      module: className,
    );
  }
}
