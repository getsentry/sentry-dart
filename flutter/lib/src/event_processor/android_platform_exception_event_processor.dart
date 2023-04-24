import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../sentry_flutter.dart';
import '../jvm/jvm_exception.dart';
import '../jvm/jvm_frame.dart';

/// Transforms an Android PlatformException to a human readable SentryException
// Relevant links:
// - https://docs.flutter.dev/development/platform-integration/platform-channels?tab=ios-channel-objective-c-tab#channels-and-platform-threading
class AndroidPlatformExceptionEventProcessor implements EventProcessor {
  const AndroidPlatformExceptionEventProcessor(this._options);

  final SentryFlutterOptions _options;

  // Because of obfuscation, we need to dynamically get the name
  static final _platformExceptionType = (PlatformException).toString();

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    if (event is SentryTransaction) {
      return event;
    }

    final plaformException = event.throwable;
    if (plaformException is! PlatformException) {
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

    final threads = _markDartThreadsAsNonCrashed(event.threads);

    final jvmExceptions = jvmException.map((e) => e.key);

    var jvmThreads = jvmException.map((e) => e.value).toList(growable: false);
    if (jvmThreads.isNotEmpty) {
      // filter potential duplicated threads
      final first = jvmThreads.first;
      jvmThreads = jvmThreads
          .skip(1)
          .where((element) => element.id != first.id)
          .toList(growable: true);
      jvmThreads.add(first);
    }

    return event.copyWith(exceptions: [
      ...?exceptions,
      ...jvmExceptions,
    ], threads: [
      ...?threads,
      if (_options.attachThreads) ...jvmThreads,
    ]);
  }

  /// If the crash originated on Android, the Dart side didn't crash.
  /// Mark it accordingly.
  List<SentryThread>? _markDartThreadsAsNonCrashed(
    List<SentryThread>? threads,
  ) {
    return threads
        ?.map((e) => e.copyWith(
              crashed: false,
              // Isolate is safe to use directly,
              // because Android is only run in the dart:io context.
              current: e.name == Isolate.current.debugName,
            ))
        .toList(growable: false);
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
      return null;
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

  List<MapEntry<SentryException, SentryThread>> fromJvmStackTrace(
      String exceptionAsString) {
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
  MapEntry<SentryException, SentryThread> toSentryException(
      String nativePackageName) {
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

    var exception = SentryException(
      value: description,
      type: exceptionType,
      module: module,
      stackTrace: SentryStackTrace(
        frames: stackFrames.reversed.toList(growable: false),
      ),
    );

    String threadName;
    if (thread != null) {
      // Needs to be prefixed with 'Android', otherwise this thread id might
      // clash with isolate names from the Dart side.
      threadName = 'Android: $thread';
    } else {
      // If there's no thread in the exception, we just indicate that it's
      // from Android
      threadName = 'Android';
    }
    final threadId = threadName.hashCode;

    final sentryThread = SentryThread(
      crashed: true,
      current: false,
      name: threadName,
      id: threadId,
    );
    exception = exception.copyWith(threadId: threadId);

    return MapEntry(exception, sentryThread);
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
