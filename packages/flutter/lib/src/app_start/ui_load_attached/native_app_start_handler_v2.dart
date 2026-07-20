// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../app_start_data.dart';
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

    final appStartData = AppStartData.tryParse(
      nativeAppStart,
      sentrySetupTimestamp: setupTimestamp,
      validUntil: appStartEnd,
    );
    if (appStartData == null) {
      tracker.cancelCurrentRoute();
      return;
    }

    final appStartType = SentryAttribute.string(appStartData.type.name);
    final attributes = {
      SemanticAttributesConstants.sentryOp:
          SentryAttribute.string(appStartData.type.operation),
      SemanticAttributesConstants.sentryOrigin:
          SentryAttribute.string(SentryTraceOrigins.autoUiTimeToDisplay),
      SemanticAttributesConstants.appVitalsStartType: appStartType,
    };

    final rootSpan = tracker.trackAppStart(
      startTimestamp: appStartData.processStartTimestamp,
      ttidEndTimestamp: appStartEnd,
    );

    final appStartSpan = hub.startInactiveSpan(
      appStartData.type.description,
      parentSpan: rootSpan,
      startTimestamp: appStartData.processStartTimestamp,
      attributes: {
        ...attributes,
        SemanticAttributesConstants.appVitalsStartScreen:
            SentryAttribute.string(rootSpan.name),
      },
    );

    final pluginRegistrationSpan = hub.startInactiveSpan(
      appStartPluginRegistrationDescription,
      parentSpan: appStartSpan,
      startTimestamp: appStartData.processStartTimestamp,
      attributes: attributes,
    );

    final sentrySetupSpan = hub.startInactiveSpan(
      appStartSentrySetupDescription,
      parentSpan: appStartSpan,
      startTimestamp: appStartData.pluginRegistrationTimestamp,
      attributes: attributes,
    );

    final firstFrameRenderSpan = hub.startInactiveSpan(
      appStartFirstFrameRenderDescription,
      parentSpan: appStartSpan,
      startTimestamp: appStartData.sentrySetupTimestamp,
      attributes: attributes,
    );

    for (final timeSpan in appStartData.nativePhases) {
      try {
        final nativeSpan = hub.startInactiveSpan(
          timeSpan.description,
          parentSpan: appStartSpan,
          startTimestamp: timeSpan.startTimestamp,
          attributes: attributes,
        );
        nativeSpan.end(endTimestamp: timeSpan.endTimestamp);
      } catch (error, stackTrace) {
        internalLogger.error('Failed to attach native span to app start',
            error: error, stackTrace: stackTrace);
      }
    }

    pluginRegistrationSpan.end(
      endTimestamp: appStartData.pluginRegistrationTimestamp,
    );
    sentrySetupSpan.end(endTimestamp: appStartData.sentrySetupTimestamp);
    firstFrameRenderSpan.end(endTimestamp: appStartEnd);

    final durationMs = SentryAttribute.double(
      appStartData.durationUntil(appStartEnd).inMilliseconds.toDouble(),
    );
    // Emit both the legacy cold/warm split and the unified value+type pair
    // during the deprecation window for the former.
    final legacyValueKey = switch (appStartData.type) {
      AppStartType.cold => SemanticAttributesConstants.appVitalsStartColdValue,
      AppStartType.warm => SemanticAttributesConstants.appVitalsStartWarmValue,
    };
    appStartSpan.setAttribute(legacyValueKey, durationMs);
    appStartSpan.setAttribute(
        SemanticAttributesConstants.appVitalsStartValue, durationMs);

    appStartSpan.end(endTimestamp: appStartEnd);
  }
}
