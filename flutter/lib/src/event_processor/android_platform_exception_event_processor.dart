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

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event is SentryTransaction) {
      return event;
    }

    final plaformException = event.throwable;
    if (plaformException is! PlatformException) {
      return event;
    }

    try {
      // PackageInfo has an internal cache, so no need to do it ourselves.
      final packageInfo = await PackageInfo.fromPlatform();

      final nativeStackTrace =
          _tryParse(plaformException.stacktrace, packageInfo.packageName);
      final messageStackTrace =
          _tryParse(plaformException.message, packageInfo.packageName);

      if (nativeStackTrace == null && messageStackTrace == null) {
        return event;
      }

      return _processPlatformException(
        event,
        nativeStackTrace,
        messageStackTrace,
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

  List<MapEntry<SentryException, SentryThread>>? _tryParse(
    String? potentialStackTrace,
    String packageName,
  ) {
    if (potentialStackTrace == null) {
      return null;
    }

    return _JvmExceptionFactory(packageName)
        .fromJvmStackTrace(potentialStackTrace);
  }

  SentryEvent _processPlatformException(
    SentryEvent event,
    List<MapEntry<SentryException, SentryThread>>? nativeStackTrace,
    List<MapEntry<SentryException, SentryThread>>? messageStackTrace,
  ) {
    final threads = _markDartThreadsAsNonCrashed(event.threads);

    final jvmExceptions = [
      ...?nativeStackTrace?.map((e) => e.key),
      ...?messageStackTrace?.map((e) => e.key)
    ];

    var jvmThreads = [
      ...?nativeStackTrace?.map((e) => e.value),
      ...?messageStackTrace?.map((e) => e.value),
    ];

    if (jvmThreads.isNotEmpty) {
      // filter potential duplicated threads
      final first = jvmThreads.first;
      jvmThreads = jvmThreads
          .skip(1)
          .where((element) => element.id != first.id)
          .toList(growable: true);
      jvmThreads.add(first);
    }

    return event.copyWith(
      exceptions: [
        ...?event.exceptions,
        ...jvmExceptions,
      ],
      threads: [
        ...?threads,
        if (_options.attachThreads) ...jvmThreads,
      ],
    );
  }

  /// If the crash originated on Android, the Dart side didn't crash.
  /// Mark it accordingly.
  List<SentryThread>? _markDartThreadsAsNonCrashed(
    List<SentryThread>? threads,
  ) {
    return threads
        ?.map(
          (e) => e.copyWith(
            crashed: false,
            // Isolate is safe to use directly,
            // because Android is only run in the dart:io context.
            current: e.name == Isolate.current.debugName,
          ),
        )
        .toList(growable: false);
  }
}

class _JvmExceptionFactory {
  const _JvmExceptionFactory(this.nativePackageName);

  final String nativePackageName;

  List<MapEntry<SentryException, SentryThread>> fromJvmStackTrace(
    String exceptionAsString,
  ) {
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
      if (typeParts.isNotEmpty) {
        exceptionType = typeParts.last;
      }
      typeParts.remove(typeParts.last);

      if (typeParts.isNotEmpty) {
        module = typeParts.join('.');
      }
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
