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
    if (_native.didAddAppStartMeasurement || event is! SentryTransaction) {
      return event;
    }

    final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();
    final measurement = appStartInfo?.toMeasurement();

    if (measurement != null) {
      event.measurements[measurement.name] = measurement;
      _native.didAddAppStartMeasurement = true;
    }

    if (appStartInfo == null) {
      return event;
    }

    await _attachAppStartSpans(appStartInfo, event.tracer);

    // if (classInitUptimeMs != null && appStartUptimeMs != null) {
    //   final duration = classInitUptimeMs - appStartUptimeMs;
    //
    //   final classInitSpan = await _createAndFinishSpan(
    //       tracer: transaction,
    //       operation: 'ui.load',
    //       description: 'Class init',
    //       parentSpanId: transaction.context.spanId,
    //       traceId: transaction.context.traceId,
    //       startTimestamp: appStartInfo.start,
    //       endTimestamp:
    //       appStartInfo.start.add(Duration(milliseconds: duration)));
    //
    //   transaction.children.addAll([
    //     classInitSpan,
    //   ]);
    //   // await _attachAppStartSpans(appStartInfo, transaction);
    //
    //   return event;
    // }

    return event;
  }

  Future<void> _attachAppStartSpans(
      AppStartInfo appStartInfo, SentryTracer transaction) async {
    final transactionTraceId = transaction.context.traceId;

    final appStartSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: appStartInfo.appStartTypeOperation,
        description: appStartInfo.appStartTypeDescription,
        parentSpanId: transaction.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.start,
        endTimestamp: appStartInfo.end);

    await _attachNativeSpans(appStartInfo, transaction, appStartSpan);

    final pluginRegistrationSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: appStartInfo.appStartTypeOperation,
        description: appStartInfo.pluginRegistrationDescription,
        parentSpanId: appStartSpan.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.start,
        endTimestamp: appStartInfo.pluginRegistration);

    final mainIsolateSetupSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: appStartInfo.appStartTypeOperation,
        description: appStartInfo.mainIsolateSetupDescription,
        parentSpanId: appStartSpan.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.pluginRegistration,
        endTimestamp: appStartInfo.mainIsolateStart);

    final firstFrameRenderSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: appStartInfo.appStartTypeOperation,
        description: appStartInfo.firstFrameRenderDescription,
        parentSpanId: appStartSpan.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: SentryFlutter.mainIsolateStartTime,
        endTimestamp: appStartInfo.end);

    transaction.children.addAll([
      appStartSpan,
      pluginRegistrationSpan,
      mainIsolateSetupSpan,
      firstFrameRenderSpan
    ]);
  }

  Future<void> _attachNativeSpans(AppStartInfo appStartInfo,
      SentryTracer transaction, SentrySpan parent) async {
    final runTimeInitTimestamp =
        appStartInfo.nativeSpanTimes['runtimeInitTimestamp'] as double?;
    final moduleInitTimestamp =
        appStartInfo.nativeSpanTimes['moduleInitTimestamp'] as double?;
    final sdkStartTimestamp =
        appStartInfo.nativeSpanTimes['sdkStartTimestamp'] as double?;
    final didFinishLaunchingTimestamp =
        appStartInfo.nativeSpanTimes['didFinishLaunchingTimestamp'] as double?;

    if (runTimeInitTimestamp != null &&
        moduleInitTimestamp != null &&
        sdkStartTimestamp != null &&
        didFinishLaunchingTimestamp != null) {
      final aa =
          DateTime.fromMillisecondsSinceEpoch(runTimeInitTimestamp.toInt());
      final bb =
          DateTime.fromMillisecondsSinceEpoch(moduleInitTimestamp.toInt());
      final sdkStart =
          DateTime.fromMillisecondsSinceEpoch(sdkStartTimestamp.toInt());
      final didFinishLaunching = DateTime.fromMillisecondsSinceEpoch(
          didFinishLaunchingTimestamp.toInt());

      final op = 'app.start.${appStartInfo.type.name}';

      final preRuntimeInitSpan = await _createAndFinishSpan(
          tracer: transaction,
          operation: op,
          description: 'Pre runtime init',
          parentSpanId: parent.context.spanId,
          traceId: transaction.context.traceId,
          startTimestamp: appStartInfo.start,
          endTimestamp: aa);

      final runtimeInitSpan = await _createAndFinishSpan(
          tracer: transaction,
          operation: op,
          description: 'Runtime init',
          parentSpanId: parent.context.spanId,
          traceId: transaction.context.traceId,
          startTimestamp: aa,
          endTimestamp: bb);

      final appInitSpan = await _createAndFinishSpan(
          tracer: transaction,
          operation: op,
          description: 'UIKit init',
          parentSpanId: parent.context.spanId,
          traceId: transaction.context.traceId,
          startTimestamp: bb,
          endTimestamp: sdkStart);

      final didFinishLaunchingSpan = await _createAndFinishSpan(
          tracer: transaction,
          operation: op,
          description: 'Application init',
          parentSpanId: parent.context.spanId,
          traceId: transaction.context.traceId,
          startTimestamp: sdkStart,
          endTimestamp: didFinishLaunching);

      transaction.children.addAll([
        preRuntimeInitSpan,
        runtimeInitSpan,
        appInitSpan,
        didFinishLaunchingSpan,
      ]);
    }
  }

  Future<SentrySpan> _createAndFinishSpan({
    required SentryTracer tracer,
    required String operation,
    required String description,
    required SpanId? parentSpanId,
    required SentryId? traceId,
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
