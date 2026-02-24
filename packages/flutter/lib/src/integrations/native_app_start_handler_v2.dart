// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import 'native_app_start_data.dart';

/// V2 handler for native app start spans using the streaming span API.
///
/// Unlike the V1 handler, this handler:
/// - Uses [TimeToDisplayTrackerV2.trackRoute] to create the root idle span
/// - Creates backdated child spans via [Hub.startInactiveSpan]
/// - Does not create transactions or bind to scope
@internal
class NativeAppStartHandlerV2 {
  NativeAppStartHandlerV2(this._native);

  final SentryNativeBinding _native;

  Future<void> call(
    Hub hub,
    SentryFlutterOptions options, {
    required DateTime appStartEnd,
  }) async {
    final nativeAppStart = await _native.fetchNativeAppStart();
    if (nativeAppStart == null) {
      return;
    }

    final appStartInfo =
        parseNativeAppStart(nativeAppStart, appStartEnd, options);
    if (appStartInfo == null) {
      return;
    }

    final tracker = options.timeToDisplayTrackerV2;
    final rootSpan = tracker.trackRootNavigation(
      startTimestamp: appStartInfo.start,
      ttidEndTimestamp: appStartInfo.end,
    );

    // Step 4: Create app start parent span (inactive, backdated)
    final appStartSpan = hub.startInactiveSpan(
      appStartInfo.appStartTypeDescription,
      parentSpan: rootSpan,
      startTimestamp: appStartInfo.start,
      attributes: {
        SemanticAttributesConstants.sentryOp:
            SentryAttribute.string(appStartInfo.appStartTypeOperation),
        SemanticAttributesConstants.sentryOrigin:
            SentryAttribute.string(SentryTraceOrigins.autoUiTimeToDisplay),
      },
    );

    // Step 5: Create child phase spans (inactive, backdated) under app start span
    final pluginRegistrationSpan = hub.startInactiveSpan(
      appStartInfo.pluginRegistrationDescription,
      parentSpan: appStartSpan,
      startTimestamp: appStartInfo.start,
      attributes: {
        SemanticAttributesConstants.sentryOp:
            SentryAttribute.string(appStartInfo.appStartTypeOperation),
        SemanticAttributesConstants.sentryOrigin:
            SentryAttribute.string(SentryTraceOrigins.autoUiTimeToDisplay),
      },
    );

    final sentrySetupSpan = hub.startInactiveSpan(
      appStartInfo.sentrySetupDescription,
      parentSpan: appStartSpan,
      startTimestamp: appStartInfo.pluginRegistration,
      attributes: {
        SemanticAttributesConstants.sentryOp:
            SentryAttribute.string(appStartInfo.appStartTypeOperation),
        SemanticAttributesConstants.sentryOrigin:
            SentryAttribute.string(SentryTraceOrigins.autoUiTimeToDisplay),
      },
    );

    final firstFrameRenderSpan = hub.startInactiveSpan(
      appStartInfo.firstFrameRenderDescription,
      parentSpan: appStartSpan,
      startTimestamp: appStartInfo.sentrySetupStart,
      attributes: {
        SemanticAttributesConstants.sentryOp:
            SentryAttribute.string(appStartInfo.appStartTypeOperation),
        SemanticAttributesConstants.sentryOrigin:
            SentryAttribute.string(SentryTraceOrigins.autoUiTimeToDisplay),
      },
    );

    // Step 6: Create native spans (inactive, backdated) under app start span
    final nativeSpans = <SentrySpanV2>[];
    for (final timeSpan in appStartInfo.nativeSpanTimes) {
      try {
        final nativeSpan = hub.startInactiveSpan(
          timeSpan.description,
          parentSpan: appStartSpan,
          startTimestamp: timeSpan.start,
          attributes: {
            SemanticAttributesConstants.sentryOp:
                SentryAttribute.string(appStartInfo.appStartTypeOperation),
            SemanticAttributesConstants.sentryOrigin:
                SentryAttribute.string(SentryTraceOrigins.autoUiTimeToDisplay),
          },
        );
        nativeSpans.add(nativeSpan);
      } catch (e) {
        options.log(SentryLevel.warning,
            'Failed to attach native span to app start: $e');
      }
    }

    // Step 7: End all spans with their respective endTimestamps.
    // End children first, then parent.
    pluginRegistrationSpan.end(endTimestamp: appStartInfo.pluginRegistration);
    sentrySetupSpan.end(endTimestamp: appStartInfo.sentrySetupStart);
    firstFrameRenderSpan.end(endTimestamp: appStartEnd);

    for (int i = 0; i < nativeSpans.length; i++) {
      nativeSpans[i].end(endTimestamp: appStartInfo.nativeSpanTimes[i].end);
    }

    appStartSpan.end(endTimestamp: appStartEnd);

    // TODO: Add measurement when V2 span measurement API is available.
    // V2 spans don't currently support measurements. When the API is added:
    // rootSpan.setMeasurement(appStartInfo.toMeasurement());
  }
}
