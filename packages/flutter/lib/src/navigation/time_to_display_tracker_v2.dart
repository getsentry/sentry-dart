// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../utils/internal_logger.dart';

@internal
class TimeToDisplayTrackerV2 {
  final Hub _hub;
  final FrameCallbackHandler _frameCallbackHandler;
  SentrySpanV2? _routeSpan;
  SentrySpanV2? _ttfdSpan;

  TimeToDisplayTrackerV2({
    Hub? hub,
    FrameCallbackHandler? frameCallbackHandler,
  })  : _hub = hub ?? HubAdapter(),
        _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler();

  SpanId? get ttfdSpanId => _ttfdSpan?.spanId;

  void trackRoute(String routeName) {
    cancelCurrentRoute();

    final routeSpan = _hub.startIdleSpan(routeName, attributes: {
      SemanticAttributesConstants.sentryOp:
          SentryAttribute.string(SentrySpanOperations.uiLoad),
      SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoNavigationRouteObserver),
    });
    _routeSpan = routeSpan;

    final ttidSpan = _hub.startInactiveSpan(
      '$routeName initial display',
      parentSpan: routeSpan,
      attributes: {
        SemanticAttributesConstants.sentryOp:
            SentryAttribute.string(SentrySpanOperations.uiTimeToInitialDisplay),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
            SentryTraceOrigins.autoNavigationRouteObserver),
      },
    );

    _ttfdSpan = _hub.startInactiveSpan(
      '$routeName full display',
      parentSpan: routeSpan,
      attributes: {
        SemanticAttributesConstants.sentryOp:
            SentryAttribute.string(SentrySpanOperations.uiTimeToFullDisplay),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
            SentryTraceOrigins.autoNavigationRouteObserver),
      },
    );

    _frameCallbackHandler.addPostFrameCallback((_) {
      ttidSpan.end();
    });
  }

  void reportFullyDisplayed(SpanId spanId) {
    final ttfdSpanId = _ttfdSpan?.spanId;
    if (ttfdSpanId != spanId) {
      internalLogger.debug(
        'Ignoring reportFullyDisplayed for span $spanId because active TTFD span is $ttfdSpanId.',
      );
      return;
    }
    _ttfdSpan?.end();
    _ttfdSpan = null;
  }

  void cancelCurrentRoute() {
    _ttfdSpan = null;

    // Ending the route idle span cascades cancellation to any unfinished
    // descendant spans, including TTID and TTFD.
    final routeSpan = _routeSpan;
    if (routeSpan != null && !routeSpan.isEnded) {
      routeSpan
        ..status = SentrySpanStatusV2.cancelled
        ..end();
    }
    _routeSpan = null;
  }
}
