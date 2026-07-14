// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../app_start/app_start_constants.dart';
import '../app_start/app_start_data.dart';
import '../app_start/native_app_start_parser.dart';
import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';

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
    if (nativeAppStart == null) {
      tracker.cancelCurrentRoute();
      return;
    }

    final appStartInfo = parseNativeAppStart(nativeAppStart, appStartEnd);
    if (appStartInfo == null) {
      tracker.cancelCurrentRoute();
      return;
    }

    final snapshot = appStartInfo.snapshot;
    final appStartType = SentryAttribute.string(snapshot.type.name);
    final attributes = {
      SemanticAttributesConstants.sentryOp:
          SentryAttribute.string(appStartInfo.typeOperation),
      SemanticAttributesConstants.sentryOrigin:
          SentryAttribute.string(SentryTraceOrigins.autoUiTimeToDisplay),
      SemanticAttributesConstants.appVitalsStartType: appStartType,
    };

    final rootSpan = tracker.trackAppStart(
      startTimestamp: snapshot.processStartTimestamp,
      ttidEndTimestamp: appStartInfo.endTimestamp,
    );

    final appStartSpan = hub.startInactiveSpan(
      appStartInfo.typeDescription,
      parentSpan: rootSpan,
      startTimestamp: snapshot.processStartTimestamp,
      attributes: attributes,
    );

    final pluginRegistrationSpan = hub.startInactiveSpan(
      appStartPluginRegistrationDescription,
      parentSpan: appStartSpan,
      startTimestamp: snapshot.processStartTimestamp,
      attributes: attributes,
    );

    final sentrySetupSpan = hub.startInactiveSpan(
      appStartSentrySetupDescription,
      parentSpan: appStartSpan,
      startTimestamp: snapshot.pluginRegistrationTimestamp,
      attributes: attributes,
    );

    final firstFrameRenderSpan = hub.startInactiveSpan(
      appStartFirstFrameRenderDescription,
      parentSpan: appStartSpan,
      startTimestamp: snapshot.sentrySetupTimestamp,
      attributes: attributes,
    );

    for (final timeSpan in snapshot.nativePhaseIntervals) {
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
      endTimestamp: snapshot.pluginRegistrationTimestamp,
    );
    sentrySetupSpan.end(endTimestamp: snapshot.sentrySetupTimestamp);
    firstFrameRenderSpan.end(endTimestamp: appStartEnd);

    final durationMs =
        SentryAttribute.double(appStartInfo.duration.inMilliseconds.toDouble());
    // Emit both the legacy cold/warm split and the unified value+type pair
    // during the deprecation window for the former.
    final legacyValueKey = switch (snapshot.type) {
      AppStartType.cold => SemanticAttributesConstants.appVitalsStartColdValue,
      AppStartType.warm => SemanticAttributesConstants.appVitalsStartWarmValue,
    };
    appStartSpan.setAttribute(legacyValueKey, durationMs);
    appStartSpan.setAttribute(
        SemanticAttributesConstants.appVitalsStartValue, durationMs);

    appStartSpan.end(endTimestamp: appStartEnd);
  }
}
