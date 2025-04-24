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

    final platformException = event.throwable;
    if (platformException is! PlatformException) {
      return event;
    }

    try {
      // PackageInfo has an internal cache, so no need to do it ourselves.
      final packageInfo = await PackageInfo.fromPlatform();

      final nativeStackTrace = _tryParse(
        platformException.stacktrace,
        packageInfo.packageName,
        "stackTrace",
      );

      final details = platformException.details;
      String? detailsString;
      if (details is String) {
        detailsString = details;
      }
      final detailsStackTrace = _tryParse(
        detailsString,
        packageInfo.packageName,
        "details",
      );

      if (nativeStackTrace == null && detailsStackTrace == null) {
        return event;
      }

      return _processPlatformException(
        event,
        nativeStackTrace,
        detailsStackTrace,
      );
    } catch (e, stackTrace) {
      _options.logger(
        SentryLevel.info,
        "Couldn't prettify PlatformException. "
        'The exception will still be reported.',
        exception: e,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
      return event;
    }
  }

  MapEntry<SentryException, List<SentryThread>>? _tryParse(
    String? potentialStackTrace,
    String packageName,
    String source,
  ) {
    if (potentialStackTrace == null) {
      return null;
    }
    return _JvmExceptionFactory(packageName)
        .fromJvmStackTrace(potentialStackTrace, source);
  }

  SentryEvent _processPlatformException(
    SentryEvent event,
    MapEntry<SentryException, List<SentryThread>>? nativeStackTrace,
    MapEntry<SentryException, List<SentryThread>>? detailsStackTrace,
  ) {
    _markDartThreadsAsNonCrashed(event.threads);
    final exception = event.exceptions?.firstOrNull;

    // Assumption is that the first exception is the original exception and there is only one.
    if (exception == null) {
      return event;
    }

    var jvmThreads = <SentryThread>[];
    if (nativeStackTrace != null) {
      // ignore: invalid_use_of_internal_member
      exception.addException(nativeStackTrace.key);
      jvmThreads.addAll(nativeStackTrace.value);
    }

    if (detailsStackTrace != null) {
      // ignore: invalid_use_of_internal_member
      exception.addException(detailsStackTrace.key);
      jvmThreads.addAll(detailsStackTrace.value);
    }

    if (jvmThreads.isNotEmpty) {
      // filter potential duplicated threads
      final first = jvmThreads.first;
      jvmThreads = jvmThreads
          .skip(1)
          .where((element) => element.id != first.id)
          .toList(growable: true);
      jvmThreads.add(first);
    }

    event.exceptions = [exception];
    event.threads = [
      ...?event.threads,
      if (_options.attachThreads) ...jvmThreads,
    ];
    return event;
  }

  /// If the crash originated on Android, the Dart side didn't crash.
  /// Mark it accordingly.
  void _markDartThreadsAsNonCrashed(
    List<SentryThread>? threads,
  ) {
    for (final thread in threads ?? []) {
      thread.crashed = false;
      // Isolate is safe to use directly,
      // because Android is only run in the dart:io context.
      thread.current = thread.name == Isolate.current.debugName;
    }
  }
}

class _JvmExceptionFactory {
  const _JvmExceptionFactory(this.nativePackageName);

  final String nativePackageName;

  MapEntry<SentryException, List<SentryThread>> fromJvmStackTrace(
    String exceptionAsString,
    String source,
  ) {
    final jvmException = JvmException.parse(exceptionAsString);

    List<SentryThread> sentryThreads = [];

    final sentryException = jvmException.toSentryException(nativePackageName);
    final sentryThread = jvmException.toSentryThread();
    sentryThreads.add(sentryThread);

    final mechanism = sentryException.mechanism ?? Mechanism(type: "generic");
    mechanism.source = source;
    sentryException.threadId = sentryThread.id;
    sentryException.mechanism = mechanism;

    int causeIndex = 0;
    for (final cause in jvmException.causes ?? <JvmException>[]) {
      var causeSentryException = cause.toSentryException(nativePackageName);
      final causeSentryThread = cause.toSentryThread();
      sentryThreads.add(causeSentryThread);

      final causeMechanism =
          causeSentryException.mechanism ?? Mechanism(type: "generic");
      causeMechanism.source = 'causes[$causeIndex]';

      causeSentryException.threadId = causeSentryThread.id;
      causeSentryException.mechanism = causeMechanism;

      // ignore: invalid_use_of_internal_member
      sentryException.addException(causeSentryException);
      causeIndex++;
    }

    int suppressedIndex = 0;
    for (final suppressed in jvmException.suppressed ?? <JvmException>[]) {
      var suppressedSentryException =
          suppressed.toSentryException(nativePackageName);
      final suppressedSentryThread = suppressed.toSentryThread();
      sentryThreads.add(suppressedSentryThread);

      final suppressedMechanism =
          suppressedSentryException.mechanism ?? Mechanism(type: "generic");
      suppressedMechanism.source = 'suppressed[$suppressedIndex]';

      suppressedSentryException.threadId = suppressedSentryThread.id;
      suppressedSentryException.mechanism = suppressedMechanism;

      // ignore: invalid_use_of_internal_member
      sentryException.addException(suppressedSentryException);
      suppressedIndex++;
    }
    return MapEntry(sentryException, sentryThreads.toList(growable: false));
  }
}

extension on JvmException {
  SentryException toSentryException(String nativePackageName) {
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

    return SentryException(
      value: description,
      type: exceptionType,
      module: module,
      stackTrace: SentryStackTrace(
        frames: stackFrames.reversed.toList(growable: false),
      ),
    );
  }

  SentryThread toSentryThread() {
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

    return SentryThread(
      crashed: true,
      current: false,
      name: threadName,
      id: threadId,
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
