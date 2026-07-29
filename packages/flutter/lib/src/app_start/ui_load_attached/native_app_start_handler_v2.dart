// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../app_start_timing.dart';
import '../../native/sentry_native_binding.dart';
import '../../utils/internal_logger.dart';

/// V2 handler for native app start spans using the streaming span API.
@internal
class NativeAppStartHandlerV2 {
  final SentryNativeBinding _native;

  NativeAppStartHandlerV2(this._native);

  Future<void> call(
    Hub hub,
    SentryFlutterOptions options, {
    required DateTime appStartEnd,
  }) async {
    final tracker = options.timeToDisplayTrackerV2;

    final nativeAppStart = await _native.fetchNativeAppStart();
    final setupTimestamp = SentryFlutter.sentrySetupStartTime;
    if (nativeAppStart == null || setupTimestamp == null) {
      tracker.cancelCurrentRoute();
      return;
    }

    final appStartTiming = AppStartTiming.tryParse(
      nativeAppStart,
      sentrySetupTimestamp: setupTimestamp,
    );
    final appStartDuration = appStartTiming?.reportableDurationUntil(
      appStartEnd,
    );
    if (appStartTiming == null || appStartDuration == null) {
      tracker.cancelCurrentRoute();
      return;
    }

    final appStartType = SentryAttribute.string(appStartTiming.type.name);
    final attributes = {
      SemanticAttributesConstants.sentryOp: SentryAttribute.string(
        appStartTiming.type.operation,
      ),
      SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
        SentryTraceOrigins.autoUiTimeToDisplay,
      ),
      SemanticAttributesConstants.appVitalsStartType: appStartType,
    };

    final rootSpan = tracker.trackAppStart(
      startTimestamp: appStartTiming.processStartTimestamp,
      ttidEndTimestamp: appStartEnd,
    );

    final appStartSpan = hub.startInactiveSpan(
      appStartTiming.type.description,
      parentSpan: rootSpan,
      startTimestamp: appStartTiming.processStartTimestamp,
      attributes: {
        ...attributes,
        SemanticAttributesConstants.appVitalsStartScreen:
            SentryAttribute.string(rootSpan.name),
      },
    );

    final pluginRegistrationSpan = hub.startInactiveSpan(
      appStartPluginRegistrationDescription,
      parentSpan: appStartSpan,
      startTimestamp: appStartTiming.processStartTimestamp,
      attributes: attributes,
    );

    final sentrySetupSpan = hub.startInactiveSpan(
      appStartSentrySetupDescription,
      parentSpan: appStartSpan,
      startTimestamp: appStartTiming.pluginRegistrationTimestamp,
      attributes: attributes,
    );

    final firstFrameRenderSpan = hub.startInactiveSpan(
      appStartFirstFrameRenderDescription,
      parentSpan: appStartSpan,
      startTimestamp: appStartTiming.sentrySetupTimestamp,
      attributes: attributes,
    );

    for (final timeSpan in appStartTiming.nativePhases) {
      try {
        final nativeSpan = hub.startInactiveSpan(
          timeSpan.description,
          parentSpan: appStartSpan,
          startTimestamp: timeSpan.startTimestamp,
          attributes: attributes,
        );
        nativeSpan.end(endTimestamp: timeSpan.endTimestamp);
      } catch (error, stackTrace) {
        internalLogger.error(
          'Failed to attach native span to app start',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    pluginRegistrationSpan.end(
      endTimestamp: appStartTiming.pluginRegistrationTimestamp,
    );
    sentrySetupSpan.end(endTimestamp: appStartTiming.sentrySetupTimestamp);
    firstFrameRenderSpan.end(endTimestamp: appStartEnd);

    final durationMs = SentryAttribute.double(
      appStartDuration.inMilliseconds.toDouble(),
    );
    // Emit both the legacy cold/warm split and the unified value+type pair
    // during the deprecation window for the former.
    final legacyValueKey = switch (appStartTiming.type) {
      AppStartType.cold => SemanticAttributesConstants.appVitalsStartColdValue,
      AppStartType.warm => SemanticAttributesConstants.appVitalsStartWarmValue,
    };
    appStartSpan.setAttribute(legacyValueKey, durationMs);
    appStartSpan.setAttribute(
      ProposedSemanticAttributes.appVitalsStartValue,
      durationMs,
    );

    appStartSpan.end(endTimestamp: appStartEnd);
  }
}
