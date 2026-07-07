// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../navigation/time_to_display_tracker_v2.dart';
import '../utils/internal_logger.dart';
import 'app_start_emitter.dart';
import 'app_start_info.dart';

@internal
final class StreamAppStartEmitter implements AppStartEmitter {
  StreamAppStartEmitter({
    required Hub hub,
    required TimeToDisplayTrackerV2 timeToDisplayTracker,
    required bool standalone,
  })  : _hub = hub,
        _timeToDisplayTracker = timeToDisplayTracker,
        _standalone = standalone;

  final Hub _hub;
  final TimeToDisplayTrackerV2 _timeToDisplayTracker;
  final bool _standalone;

  @override
  Future<void> emit(AppStartInfo appStartInfo) async {
    final rootSpan = _timeToDisplayTracker.trackAppStart(
      startTimestamp: appStartInfo.start,
      ttidEndTimestamp: appStartInfo.end,
    );

    if (_standalone) {
      _emitStandalone(appStartInfo);
      return;
    }

    _emitAttached(appStartInfo, rootSpan);
  }

  @override
  void cancel() {
    _timeToDisplayTracker.cancelCurrentRoute();
  }

  /// Detached root representing the app start itself, with the breakdown
  /// spans directly beneath it — no per-type wrapper span.
  void _emitStandalone(AppStartInfo appStartInfo) {
    final appStartType = SentryAttribute.string(appStartInfo.type.name);
    final root = _hub.startIdleSpan(
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

    _finalize(root, appStartInfo);
  }

  /// Legacy shape under the ui.load root: a per-type app start span carrying
  /// the measurement, with the breakdown spans nested beneath it.
  void _emitAttached(
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

    _finalize(appStartSpan, appStartInfo);
  }

  /// The finish path for the app start span: measurement values are written
  /// immediately before the span ends, mirroring the static lifecycle's
  /// `onFinish` hook. V2 spans expose no end callback, so a deferred
  /// finalization (e.g. an extended app start, #3767) must re-enter through
  /// this method to stamp the final values at the actual end.
  void _finalize(SentrySpanV2 span, AppStartInfo appStartInfo) {
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
  }
}
