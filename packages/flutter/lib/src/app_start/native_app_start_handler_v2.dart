// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'app_start_info.dart';

/// Stream-lifecycle adapter that maps [AppStartInfo] onto v2 spans.
///
/// Owned by the app start tracker; not a seam on its own.
@internal
class NativeAppStartHandlerV2 {
  Future<void> call(
    Hub hub,
    SentryFlutterOptions options, {
    required AppStartInfo appStartInfo,
    required bool standalone,
  }) async {
    final rootSpan = options.timeToDisplayTrackerV2.trackAppStart(
      startTimestamp: appStartInfo.start,
      ttidEndTimestamp: appStartInfo.end,
    );

    if (standalone) {
      _trackStandalone(hub, appStartInfo);
    } else {
      _trackAttached(hub, appStartInfo, rootSpan);
    }
  }

  /// Detached root representing the app start itself, with the breakdown
  /// spans directly beneath it — no per-type wrapper span.
  void _trackStandalone(Hub hub, AppStartInfo appStartInfo) {
    final appStartType = SentryAttribute.string(appStartInfo.type.name);
    final root = hub.startIdleSpan(
      'App Start',
      bindToScope: false,
      startTimestamp: appStartInfo.start,
      attributes: {
        SemanticAttributesConstants.sentryOp: SentryAttribute.string(
          SentrySpanOperations.appStart,
        ),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoAppStart,
        ),
        SemanticAttributesConstants.appVitalsStartType: appStartType,
      },
    );

    _startBreakdownSpans(
      hub,
      appStartInfo,
      parent: root,
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

    _writeMeasurement(root, appStartInfo);
    root.end(endTimestamp: appStartInfo.end);
  }

  /// Legacy shape under the ui.load root: a per-type app start span carrying
  /// the measurement, with the breakdown spans nested beneath it.
  void _trackAttached(
    Hub hub,
    AppStartInfo appStartInfo,
    SentrySpanV2 rootSpan,
  ) {
    final attributes = {
      SemanticAttributesConstants.sentryOp: SentryAttribute.string(
        appStartInfo.appStartTypeOperation,
      ),
      SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
        SentryTraceOrigins.autoUiTimeToDisplay,
      ),
      SemanticAttributesConstants.appVitalsStartType: SentryAttribute.string(
        appStartInfo.type.name,
      ),
    };

    final appStartSpan = hub.startInactiveSpan(
      appStartInfo.appStartTypeDescription,
      parentSpan: rootSpan,
      startTimestamp: appStartInfo.start,
      attributes: attributes,
    );

    _startBreakdownSpans(
      hub,
      appStartInfo,
      parent: appStartSpan,
      attributesFor: (_) => attributes,
    );

    _writeMeasurement(appStartSpan, appStartInfo);
    appStartSpan.end(endTimestamp: appStartInfo.end);
  }

  void _startBreakdownSpans(
    Hub hub,
    AppStartInfo appStartInfo, {
    required SentrySpanV2 parent,
    required Map<String, SentryAttribute> Function(String operation)
        attributesFor,
  }) {
    final pluginRegistrationSpan = hub.startInactiveSpan(
      appStartInfo.pluginRegistrationDescription,
      parentSpan: parent,
      startTimestamp: appStartInfo.start,
      attributes: attributesFor(
        SentrySpanOperations.appStartPluginRegistration,
      ),
    );

    final sentrySetupSpan = hub.startInactiveSpan(
      appStartInfo.sentrySetupDescription,
      parentSpan: parent,
      startTimestamp: appStartInfo.pluginRegistration,
      attributes: attributesFor(SentrySpanOperations.appStartSentrySetup),
    );

    final firstFrameRenderSpan = hub.startInactiveSpan(
      appStartInfo.firstFrameRenderDescription,
      parentSpan: parent,
      startTimestamp: appStartInfo.sentrySetupStart,
      attributes: attributesFor(SentrySpanOperations.appStartFirstFrameRender),
    );

    for (final timeSpan in appStartInfo.nativeSpanTimes) {
      try {
        final nativeSpan = hub.startInactiveSpan(
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
  }
}
