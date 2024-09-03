// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import '../../sentry_flutter.dart';
import '../integrations/integrations.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  final Hub _hub;

  NativeAppStartEventProcessor({Hub? hub}) : _hub = hub ?? HubAdapter();

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    final options = _hub.options;

    final integrations =
        options.integrations.whereType<NativeAppStartIntegration>();
    if (integrations.isEmpty) {
      return event;
    }
    final nativeAppStartIntegration = integrations.first;

    if (event is! SentryTransaction || options is! SentryFlutterOptions) {
      return event;
    }

    AppStartInfo? appStartInfo = nativeAppStartIntegration.appStartInfo;
    if (appStartInfo == null) {
      return event;
    }

    if (!options.autoAppStart) {
      final appStartEnd = nativeAppStartIntegration.appStartEnd;
      if (appStartEnd != null) {
        appStartInfo.end = appStartEnd;
      } else {
        // If autoAppStart is disabled and appStartEnd is not set, we can't add app starts
        return event;
      }
    }

    final measurement = appStartInfo.toMeasurement();
    if (measurement != null) {
      event.measurements[measurement.name] = measurement;
    }

    await _attachAppStartSpans(appStartInfo, event.tracer);

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

class NativeAppStartHandler {
  final Hub _hub;

  NativeAppStartHandler({Hub? hub}) : _hub = hub ?? HubAdapter();

  Future<void> call(
    AppStartInfo appStartInfo,
    SentryFlutterOptions options,
  ) async {
    const screenName = SentryNavigatorObserver.rootScreenName;
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
    await ttidSpan.finish(endTimestamp: appStartInfo.end);
    await transaction.finish(endTimestamp: appStartInfo.end);

    if (!options.autoAppStart) {
      final appStartEnd = SentryFlutter.appStatEnd;
      if (appStartEnd != null) {
        appStartInfo.end = appStartEnd;
      } else {
        // If autoAppStart is disabled and appStartEnd is not set, we can't add app starts
        return;
      }
    }

    await attachMeasurements(transaction as SentryTransaction, appStartInfo);
    await attachSpans(transaction as SentryTransaction, appStartInfo);
  }

  Future<void> attachMeasurements(
      SentryTransaction transaction, AppStartInfo appStartInfo) async {
    final measurement = appStartInfo.toMeasurement();
    if (measurement != null) {
      transaction.measurements[measurement.name] = measurement;
    }
  }

  Future<void> attachSpans(
      SentryTransaction transaction, AppStartInfo appStartInfo) async {
    SentryTracer tracer = transaction.tracer;

    final transactionTraceId = tracer.context.traceId;
    final appStartEnd = appStartInfo.end;
    if (appStartEnd == null) {
      return;
    }

    final appStartSpan = await _createAndFinishSpan(
      tracer: tracer,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.appStartTypeDescription,
      parentSpanId: tracer.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.start,
      endTimestamp: appStartEnd,
    );

    await _attachNativeSpans(appStartInfo, tracer, appStartSpan);

    final pluginRegistrationSpan = await _createAndFinishSpan(
      tracer: tracer,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.pluginRegistrationDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.start,
      endTimestamp: appStartInfo.pluginRegistration,
    );

    final sentrySetupSpan = await _createAndFinishSpan(
      tracer: tracer,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.sentrySetupDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.pluginRegistration,
      endTimestamp: appStartInfo.sentrySetupStart,
    );

    final firstFrameRenderSpan = await _createAndFinishSpan(
      tracer: tracer,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.firstFrameRenderDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.sentrySetupStart,
      endTimestamp: appStartEnd,
    );

    tracer.children.addAll([
      appStartSpan,
      pluginRegistrationSpan,
      sentrySetupSpan,
      firstFrameRenderSpan,
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
          endTimestamp: timeSpan.end,
        );
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
      startTimestamp: startTimestamp,
    );
    await span.finish(endTimestamp: endTimestamp);
    return span;
  }
}
