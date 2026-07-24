// ignore_for_file: invalid_use_of_internal_member

import '../../../sentry_flutter.dart';
import '../app_start_data.dart';
import '../../native/sentry_native_binding.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
import 'dart:async';

/// Handles communication with native frameworks in order to enrich
/// root [SentryTransaction] with app start data for mobile vitals.
class NativeAppStartHandler {
  NativeAppStartHandler(this._native);

  final SentryNativeBinding _native;

  late final Hub _hub;
  late final SentryFlutterOptions _options;

  Future<void> call(
    Hub hub,
    SentryFlutterOptions options, {
    required SentryTransactionContext context,
    required DateTime appStartEnd,
  }) async {
    _hub = hub;
    _options = options;

    final nativeAppStart = await _native.fetchNativeAppStart();
    final setupTimestamp = SentryFlutter.sentrySetupStartTime;
    if (nativeAppStart == null || setupTimestamp == null) {
      return;
    }
    final appStartData = AppStartData.tryParse(
      nativeAppStart,
      sentrySetupTimestamp: setupTimestamp,
      validUntil: appStartEnd,
    );
    if (appStartData == null) {
      return;
    }

    // Create Transaction & Span

    final rootScreenTransaction = _hub.startTransactionWithContext(
      context,
      startTimestamp: appStartData.processStartTimestamp,
      waitForChildren: true,
      autoFinishAfter: Duration(seconds: 3),
      bindToScope: true,
      trimEnd: true,
    );

    SentryTracer sentryTracer;
    if (rootScreenTransaction is SentryTracer) {
      sentryTracer = rootScreenTransaction;
    } else {
      return;
    }
    sentryTracer.setData(
      "app_start_type",
      appStartData.type.name,
    );

    // We need to add the measurements before we add the child spans
    // If the child span finish the transaction will finish and then we cannot add measurements
    // TODO(buenaflor): eventually we can move this to the onFinish callback
    final measurement = appStartData.measurementUntil(appStartEnd);
    sentryTracer.measurements[measurement.name] = measurement;

    await _attachAppStartSpans(appStartData, appStartEnd, sentryTracer);
    await options.timeToDisplayTracker.track(
      rootScreenTransaction,
      ttidEndTimestamp: appStartEnd,
    );
  }

  Future<void> _attachAppStartSpans(
    AppStartData appStartData,
    DateTime appStartEnd,
    SentryTracer transaction,
  ) async {
    final transactionTraceId = transaction.context.traceId;

    final appStartSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartData.type.operation,
      description: appStartData.type.description,
      parentSpanId: transaction.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartData.processStartTimestamp,
      endTimestamp: appStartEnd,
      appStartType: appStartData.type.name,
    );

    await _attachNativeSpans(appStartData, transaction, appStartSpan);

    final pluginRegistrationSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartData.type.operation,
      description: appStartPluginRegistrationDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartData.processStartTimestamp,
      endTimestamp: appStartData.pluginRegistrationTimestamp,
      appStartType: appStartData.type.name,
    );

    final sentrySetupSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartData.type.operation,
      description: appStartSentrySetupDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartData.pluginRegistrationTimestamp,
      endTimestamp: appStartData.sentrySetupTimestamp,
      appStartType: appStartData.type.name,
    );

    final firstFrameRenderSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartData.type.operation,
      description: appStartFirstFrameRenderDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartData.sentrySetupTimestamp,
      endTimestamp: appStartEnd,
      appStartType: appStartData.type.name,
    );

    transaction.children.addAll([
      appStartSpan,
      pluginRegistrationSpan,
      sentrySetupSpan,
      firstFrameRenderSpan
    ]);
  }

  Future<void> _attachNativeSpans(
    AppStartData appStartData,
    SentryTracer transaction,
    SentrySpan parent,
  ) async {
    await Future.forEach<AppStartPhase>(appStartData.nativePhases,
        (timeSpan) async {
      try {
        final span = await _createAndFinishSpan(
          tracer: transaction,
          operation: appStartData.type.operation,
          description: timeSpan.description,
          parentSpanId: parent.context.spanId,
          traceId: transaction.context.traceId,
          startTimestamp: timeSpan.startTimestamp,
          endTimestamp: timeSpan.endTimestamp,
          appStartType: appStartData.type.name,
        );
        span.data.putIfAbsent('native', () => true);
        transaction.children.add(span);
      } catch (e) {
        _options.log(SentryLevel.warning,
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
    required String appStartType,
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
    span.setData("app_start_type", appStartType);
    await span.finish(endTimestamp: endTimestamp);
    return span;
  }
}
