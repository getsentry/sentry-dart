// ignore_for_file: invalid_use_of_internal_member

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import '../native/sentry_native_binding.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

/// Handles communication with native frameworks in order to enrich
/// root [SentryTransaction] with app start data for mobile vitals.
class NativeAppStartHandler {
  NativeAppStartHandler(this._native);

  final SentryNativeBinding _native;

  late final Hub _hub;
  late final SentryFlutterOptions _options;

  /// We filter out App starts more than 60s
  static const _maxAppStartMillis = 60000;

  Future<void> call(Hub hub, SentryFlutterOptions options,
      {required DateTime? appStartEnd}) async {
    _hub = hub;
    _options = options;

    final nativeAppStart = await _native.fetchNativeAppStart();
    if (nativeAppStart == null) {
      return;
    }
    final appStartInfo = _infoNativeAppStart(nativeAppStart, appStartEnd);
    if (appStartInfo == null) {
      return;
    }

    // Create Transaction & Span

    const screenName = 'root /';
    final transaction = _hub.startTransaction(
      screenName,
      SentrySpanOperations.uiLoad,
      startTimestamp: appStartInfo.start,
    );
    final ttidSpan = transaction.startChild(
      SentrySpanOperations.uiTimeToInitialDisplay,
      description: '$screenName initial display',
      startTimestamp: appStartInfo.start,
    );

    // Enrich Transaction

    SentryTracer sentryTracer;
    if (transaction is SentryTracer) {
      sentryTracer = transaction;
    } else {
      return;
    }

    SentryMeasurement? measurement;
    if (options.autoAppStart) {
      measurement = appStartInfo.toMeasurement();
    } else if (appStartEnd != null) {
      appStartInfo.end = appStartEnd;
      measurement = appStartInfo.toMeasurement();
    }

    if (measurement != null) {
      sentryTracer.measurements[measurement.name] = measurement;
      await _attachAppStartSpans(appStartInfo, sentryTracer);
    }

    // Finish Transaction & Span

    await ttidSpan.finish(endTimestamp: appStartInfo.end);
    await transaction.finish(endTimestamp: appStartInfo.end);
  }

  _AppStartInfo? _infoNativeAppStart(
    NativeAppStart nativeAppStart,
    DateTime? appStartEnd,
  ) {
    final sentrySetupStartDateTime = SentryFlutter.sentrySetupStartTime;
    if (sentrySetupStartDateTime == null) {
      return null;
    }

    final appStartDateTime = DateTime.fromMillisecondsSinceEpoch(
        nativeAppStart.appStartTime.toInt());
    final pluginRegistrationDateTime = DateTime.fromMillisecondsSinceEpoch(
        nativeAppStart.pluginRegistrationTime);

    if (_options.autoAppStart) {
      // We only assign the current time if it's not already set - this is useful in tests
      appStartEnd ??= _options.clock();

      final duration = appStartEnd.difference(appStartDateTime);

      // We filter out app start more than 60s.
      // This could be due to many different reasons.
      // If you do the manual init and init the SDK too late and it does not
      // compute the app start end in the very first Screen.
      // If the process starts but the App isn't in the foreground.
      // If the system forked the process earlier to accelerate the app start.
      // And some unknown reasons that could not be reproduced.
      // We've seen app starts with hours, days and even months.
      if (duration.inMilliseconds > _maxAppStartMillis) {
        return null;
      }
    }

    List<_TimeSpan> nativeSpanTimes = [];
    for (final entry in nativeAppStart.nativeSpanTimes.entries) {
      try {
        final startTimestampMs =
            entry.value['startTimestampMsSinceEpoch'] as int;
        final endTimestampMs = entry.value['stopTimestampMsSinceEpoch'] as int;
        nativeSpanTimes.add(_TimeSpan(
          start: DateTime.fromMillisecondsSinceEpoch(startTimestampMs),
          end: DateTime.fromMillisecondsSinceEpoch(endTimestampMs),
          description: entry.key as String,
        ));
      } catch (e) {
        _options.logger(
            SentryLevel.warning, 'Failed to parse native span times: $e');
        continue;
      }
    }

    // We want to sort because the native spans are not guaranteed to be in order.
    // Performance wise this won't affect us since the native span amount is very low.
    nativeSpanTimes.sort((a, b) => a.start.compareTo(b.start));

    return _AppStartInfo(
      nativeAppStart.isColdStart ? _AppStartType.cold : _AppStartType.warm,
      start: appStartDateTime,
      end: appStartEnd,
      pluginRegistration: pluginRegistrationDateTime,
      sentrySetupStart: sentrySetupStartDateTime,
      nativeSpanTimes: nativeSpanTimes,
    );
  }

  Future<void> _attachAppStartSpans(
      _AppStartInfo appStartInfo, SentryTracer transaction) async {
    final transactionTraceId = transaction.context.traceId;
    final appStartEnd = appStartInfo.end;
    if (appStartEnd == null) {
      return;
    }

    final appStartSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.appStartTypeDescription,
      parentSpanId: transaction.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.start,
      endTimestamp: appStartEnd,
    );

    await _attachNativeSpans(appStartInfo, transaction, appStartSpan);

    final pluginRegistrationSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.pluginRegistrationDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.start,
      endTimestamp: appStartInfo.pluginRegistration,
    );

    final sentrySetupSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.sentrySetupDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.pluginRegistration,
      endTimestamp: appStartInfo.sentrySetupStart,
    );

    final firstFrameRenderSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.firstFrameRenderDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.sentrySetupStart,
      endTimestamp: appStartEnd,
    );

    transaction.children.addAll([
      appStartSpan,
      pluginRegistrationSpan,
      sentrySetupSpan,
      firstFrameRenderSpan
    ]);
  }

  Future<void> _attachNativeSpans(
    _AppStartInfo appStartInfo,
    SentryTracer transaction,
    SentrySpan parent,
  ) async {
    await Future.forEach<_TimeSpan>(appStartInfo.nativeSpanTimes,
        (timeSpan) async {
      try {
        final span = await _createAndFinishSpan(
          tracer: transaction,
          operation: appStartInfo.appStartTypeOperation,
          description: timeSpan.description,
          parentSpanId: parent.context.spanId,
          traceId: transaction.context.traceId,
          startTimestamp: timeSpan.start,
          endTimestamp: timeSpan.end,
        );
        span.data.putIfAbsent('native', () => true);
        transaction.children.add(span);
      } catch (e) {
        _options.logger(SentryLevel.warning,
            'Failed to attach native span to app start transaction: $e');
      }
    });
  }

  Future<SentrySpan> _createAndFinishSpan({
    required SentryTracer tracer,
    required String operation,
    required String description,
    required SpanId parentSpanId,
    required SentryId traceId,
    required DateTime startTimestamp,
    required DateTime endTimestamp,
  }) async {
    final span = SentrySpan(
      tracer,
      SentrySpanContext(
        operation: operation,
        description: description,
        parentSpanId: parentSpanId,
        traceId: traceId,
      ),
      _hub,
      startTimestamp: startTimestamp,
    );
    await span.finish(endTimestamp: endTimestamp);
    return span;
  }
}

enum _AppStartType { cold, warm }

class _AppStartInfo {
  _AppStartInfo(
    this.type, {
    required this.start,
    required this.pluginRegistration,
    required this.sentrySetupStart,
    required this.nativeSpanTimes,
    this.end,
  });

  final _AppStartType type;
  final DateTime start;
  final List<_TimeSpan> nativeSpanTimes;

  // We allow the end to be null, since it might be set at a later time
  // with setAppStartEnd when autoAppStart is disabled
  DateTime? end;

  final DateTime pluginRegistration;
  final DateTime sentrySetupStart;

  Duration? get duration => end?.difference(start);

  SentryMeasurement? toMeasurement() {
    final duration = this.duration;
    if (duration == null) {
      return null;
    }
    return type == _AppStartType.cold
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }

  String get appStartTypeOperation => 'app.start.${type.name}';

  String get appStartTypeDescription =>
      type == _AppStartType.cold ? 'Cold Start' : 'Warm Start';
  final pluginRegistrationDescription = 'App start to plugin registration';
  final sentrySetupDescription = 'Before Sentry Init Setup';
  final firstFrameRenderDescription = 'First frame render';
}

class _TimeSpan {
  _TimeSpan(
      {required this.start, required this.end, required this.description});

  final DateTime start;
  final DateTime end;
  final String description;
}
