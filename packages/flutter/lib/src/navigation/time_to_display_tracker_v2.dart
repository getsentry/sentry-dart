// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';

@internal
class TimeToDisplayTrackerV2 {
  final Hub _hub;
  final FrameCallbackHandler _frameCallbackHandler;
  SentrySpanV2? _ttfdSpan;

  TimeToDisplayTrackerV2({
    Hub? hub,
    FrameCallbackHandler? frameCallbackHandler,
  })  : _hub = hub ?? HubAdapter(),
        _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler();

  SpanId? get ttfdSpanId => _ttfdSpan?.spanId;

  void trackRoute(String routeName) {
    _hub.getActiveSpan()
      ?..status = SentrySpanStatusV2.cancelled
      ..end();

    final uiLoadSpan = _hub.startIdleSpan(routeName, attributes: {
      SemanticAttributesConstants.sentryOp:
          SentryAttribute.string(SentrySpanOperations.uiLoad),
      SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoNavigationRouteObserver),
    });

    final ttidSpan = _hub.startInactiveSpan(
      '$routeName initial display',
      parentSpan: uiLoadSpan,
      attributes: {
        SemanticAttributesConstants.sentryOp:
            SentryAttribute.string(SentrySpanOperations.uiTimeToInitialDisplay),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
            SentryTraceOrigins.autoNavigationRouteObserver),
      },
    );

    _ttfdSpan = _hub.startInactiveSpan(
      '$routeName full display',
      parentSpan: uiLoadSpan,
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
    if (_ttfdSpan?.spanId != spanId) return;
    _ttfdSpan?.end();
    _ttfdSpan = null;
  }

  void clear() {
    _ttfdSpan
      ?..status = SentrySpanStatusV2.cancelled
      ..end();
    _ttfdSpan = null;
  }
}
