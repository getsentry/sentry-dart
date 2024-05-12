// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import '../../sentry_flutter.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  final SentryNative _native;
  final Hub _hub;

  NativeAppStartEventProcessor(
    this._native, {
    Hub? hub,
  }) : _hub = hub ?? HubAdapter();

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    final options = _hub.options;
    if (_native.didAddAppStartMeasurement ||
        event is! SentryTransaction ||
        options is! SentryFlutterOptions) {
      return event;
    }

    final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();

    final appStartEnd = _native.appStartEnd;
    if (!options.autoAppStart) {
      if (appStartEnd != null) {
        appStartInfo?.end = appStartEnd;
      } else {
        // If autoAppStart is disabled and appStartEnd is not set, we can't add app starts
        return event;
      }
    }

    final measurement = appStartInfo?.toMeasurement();
    if (measurement != null) {
      event.measurements[measurement.name] = measurement;
      _native.didAddAppStartMeasurement = true;
    }

    if (appStartInfo != null) {
      await _attachAppStartSpans(appStartInfo, event.tracer);
    }

    return event;
  }

  Future<void> _attachAppStartSpans(
      AppStartInfo appStartInfo, SentryTracer transaction) async {
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
        endTimestamp: appStartEnd);

    await _attachNativeSpans(appStartInfo, transaction, appStartSpan);

    final pluginRegistrationSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: appStartInfo.appStartTypeOperation,
        description: appStartInfo.pluginRegistrationDescription,
        parentSpanId: appStartSpan.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.start,
        endTimestamp: appStartInfo.pluginRegistration);

    final sentrySetupSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: appStartInfo.appStartTypeOperation,
        description: appStartInfo.sentrySetupDescription,
        parentSpanId: appStartSpan.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.pluginRegistration,
        endTimestamp: appStartInfo.sentrySetupStart);

    final firstFrameRenderSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: appStartInfo.appStartTypeOperation,
        description: appStartInfo.firstFrameRenderDescription,
        parentSpanId: appStartSpan.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.sentrySetupStart,
        endTimestamp: appStartEnd);

    transaction.children.addAll([
      appStartSpan,
      pluginRegistrationSpan,
      sentrySetupSpan,
      firstFrameRenderSpan
    ]);
  }

  Future<void> _attachNativeSpans(AppStartInfo appStartInfo,
      SentryTracer transaction, SentrySpan parent) async {
    await Future.forEach<TimeSpan>(appStartInfo.nativeSpanTimes,
        (timeSpan) async {
      try {
        final span = await _createAndFinishSpan(
            tracer: transaction,
            operation: appStartInfo.appStartTypeOperation,
            description: timeSpan.description,
            parentSpanId: parent.context.spanId,
            traceId: transaction.context.traceId,
            startTimestamp: timeSpan.start,
            endTimestamp: timeSpan.end);
        span.data.putIfAbsent('native', () => true);
        transaction.children.add(span);
      } catch (e) {
        _hub.options.logger(SentryLevel.warning,
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
        startTimestamp: startTimestamp);
    await span.finish(endTimestamp: endTimestamp);
    return span;
  }
}
