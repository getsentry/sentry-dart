// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';
import 'native_app_start_data.dart';

/// V2 handler for native app start spans using the streaming span API.
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
      } catch (error, stackTrace) {
        internalLogger.error('Failed to attach native span to app start',
            error: error, stackTrace: stackTrace);
      }
    }

    pluginRegistrationSpan.end(endTimestamp: appStartInfo.pluginRegistration);
    sentrySetupSpan.end(endTimestamp: appStartInfo.sentrySetupStart);
    firstFrameRenderSpan.end(endTimestamp: appStartEnd);

    for (int i = 0; i < nativeSpans.length; i++) {
      nativeSpans[i].end(endTimestamp: appStartInfo.nativeSpanTimes[i].end);
    }

    appStartSpan.end(endTimestamp: appStartEnd);

    // TODO(next-pr): add mobile vitals specific attributes later
  }
}
