// ignore_for_file: invalid_use_of_internal_member

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import 'native_app_start_data.dart';

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
    if (nativeAppStart == null) {
      return;
    }
    final appStartInfo = parseNativeAppStart(nativeAppStart, appStartEnd);
    if (appStartInfo == null) {
      return;
    }

    // Create Transaction & Span

    final rootScreenTransaction = _hub.startTransactionWithContext(
      context,
      startTimestamp: appStartInfo.start,
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
    sentryTracer.setData("app_start_type", appStartInfo.type.name);

    // We need to add the measurements before we add the child spans
    // If the child span finish the transaction will finish and then we cannot add measurements
    // TODO(buenaflor): eventually we can move this to the onFinish callback
    SentryMeasurement? measurement = appStartInfo.toMeasurement();
    sentryTracer.measurements[measurement.name] = appStartInfo.toMeasurement();

    await _attachAppStartSpans(appStartInfo, sentryTracer);
    await options.timeToDisplayTracker.track(
      rootScreenTransaction,
      ttidEndTimestamp: appStartInfo.end,
    );
  }

  Future<void> _attachAppStartSpans(
      AppStartInfo appStartInfo, SentryTracer transaction) async {
    final transactionTraceId = transaction.context.traceId;
    final appStartEnd = appStartInfo.end;

    final appStartSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.appStartTypeDescription,
      parentSpanId: transaction.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.start,
      endTimestamp: appStartEnd,
      appStartType: appStartInfo.type.name,
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
      appStartType: appStartInfo.type.name,
    );

    final sentrySetupSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.sentrySetupDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.pluginRegistration,
      endTimestamp: appStartInfo.sentrySetupStart,
      appStartType: appStartInfo.type.name,
    );

    final firstFrameRenderSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: appStartInfo.appStartTypeOperation,
      description: appStartInfo.firstFrameRenderDescription,
      parentSpanId: appStartSpan.context.spanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.sentrySetupStart,
      endTimestamp: appStartEnd,
      appStartType: appStartInfo.type.name,
    );

    transaction.children.addAll([
      appStartSpan,
      pluginRegistrationSpan,
      sentrySetupSpan,
      firstFrameRenderSpan
    ]);
  }

  Future<void> _attachNativeSpans(
    AppStartInfo appStartInfo,
    SentryTracer transaction,
    SentrySpan parent,
  ) async {
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
          appStartType: appStartInfo.type.name,
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
