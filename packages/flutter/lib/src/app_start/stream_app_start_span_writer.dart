// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'app_start_info.dart';

@internal
final class StreamAppStartSpanWriter {
  StreamAppStartSpanWriter({required Hub hub}) : _hub = hub;

  final Hub _hub;

  void writeAttached(
    SentrySpanV2 rootSpan,
    AppStartInfo appStartInfo,
  ) {
    final attributes = {
      SemanticAttributesConstants.sentryOp: SentryAttribute.string(
        appStartInfo.appStartTypeOperation,
      ),
      SemanticAttributesConstants.appVitalsStartType: SentryAttribute.string(
        appStartInfo.type.name,
      ),
    };

    final appStartSpan = _hub.startInactiveSpan(
      appStartInfo.appStartTypeDescription,
      parentSpan: rootSpan,
      startTimestamp: appStartInfo.start,
      attributes: attributes,
    );

    _startBreakdownSpans(
      appStartInfo,
      parent: appStartSpan,
      attributesFor: (_) => attributes,
    );

    finish(appStartSpan, appStartInfo);
  }

  void writeStandalone(
    SentrySpanV2 rootSpan,
    AppStartInfo appStartInfo,
  ) {
    final appStartType = SentryAttribute.string(appStartInfo.type.name);
    _startBreakdownSpans(
      appStartInfo,
      parent: rootSpan,
      attributesFor: (operation) => {
        SemanticAttributesConstants.sentryOp: SentryAttribute.string(
          operation,
        ),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoAppStart,
        ),
        SemanticAttributesConstants.appVitalsStartType: appStartType,
      },
    );
  }

  /// The finish path for the app start span: measurement values are written
  /// immediately before the span ends, mirroring the static lifecycle's
  /// `onFinish` hook. V2 spans expose no end callback, so a deferred
  /// finalization (e.g. an extended app start, #3767) must re-enter through
  /// this method to stamp the final values at the actual end.
  void finish(SentrySpanV2 span, AppStartInfo appStartInfo) {
    _writeMeasurement(span, appStartInfo);
    span.end(endTimestamp: appStartInfo.end);
  }

  void _startBreakdownSpans(
    AppStartInfo appStartInfo, {
    required SentrySpanV2 parent,
    required Map<String, SentryAttribute> Function(String operation)
        attributesFor,
  }) {
    final pluginRegistrationSpan = _hub.startInactiveSpan(
      AppStartInfo.pluginRegistrationDescription,
      parentSpan: parent,
      startTimestamp: appStartInfo.start,
      attributes: attributesFor(
        SentrySpanOperations.appStartPluginRegistration,
      ),
    );

    final sentrySetupSpan = _hub.startInactiveSpan(
      AppStartInfo.sentrySetupDescription,
      parentSpan: parent,
      startTimestamp: appStartInfo.pluginRegistration,
      attributes: attributesFor(SentrySpanOperations.appStartSentrySetup),
    );

    final firstFrameRenderSpan = _hub.startInactiveSpan(
      AppStartInfo.firstFrameRenderDescription,
      parentSpan: parent,
      startTimestamp: appStartInfo.sentrySetupStart,
      attributes: attributesFor(SentrySpanOperations.appStartFirstFrameRender),
    );

    for (final timeSpan in appStartInfo.nativeSpanTimes) {
      try {
        final nativeSpan = _hub.startInactiveSpan(
          timeSpan.description,
          parentSpan: parent,
          startTimestamp: timeSpan.start,
          attributes: attributesFor(SentrySpanOperations.appStartNative),
        );
        nativeSpan.end(endTimestamp: timeSpan.end);
      } catch (error, stackTrace) {
        internalLogger.error(
          'Failed to attach native span to app start',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    pluginRegistrationSpan.end(endTimestamp: appStartInfo.pluginRegistration);
    sentrySetupSpan.end(endTimestamp: appStartInfo.sentrySetupStart);
    firstFrameRenderSpan.end(endTimestamp: appStartInfo.end);
  }

  /// Emits both the legacy cold/warm split and the unified value pair during
  /// the deprecation window for the former.
  void _writeMeasurement(SentrySpanV2 span, AppStartInfo appStartInfo) {
    final durationMs = SentryAttribute.double(
      appStartInfo.duration.inMilliseconds.toDouble(),
    );
    final legacyValueKey = switch (appStartInfo.type) {
      AppStartType.cold => SemanticAttributesConstants.appVitalsStartColdValue,
      AppStartType.warm => SemanticAttributesConstants.appVitalsStartWarmValue,
    };
    span.setAttribute(legacyValueKey, durationMs);
    span.setAttribute(
      SemanticAttributesConstants.appVitalsStartValue,
      durationMs,
    );
    span.setAttribute(
      SemanticAttributesConstants.appVitalsStartType,
      SentryAttribute.string(appStartInfo.type.name),
    );
  }
}
