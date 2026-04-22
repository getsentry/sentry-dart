// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../utils/internal_logger.dart';

const _rootRouteName = 'root /';

@internal
class TimeToDisplayTrackerV2 {
  final Hub _hub;
  final FrameCallbackHandler _frameCallbackHandler;
  SentrySpanV2? _ttfdSpan;

  /// Prepared root idle span, consumed by [trackAppStart].
  ///
  /// Null when no preparation is pending.
  SentrySpanV2? _preparedRootNavigationSpan;

  TimeToDisplayTrackerV2({
    Hub? hub,
    FrameCallbackHandler? frameCallbackHandler,
  })  : _hub = hub ?? HubAdapter(),
        _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler();

  /// The active TTFD span's ID, used by [SentryFlutter.currentDisplay].
  SpanId? get ttfdSpanId => _ttfdSpan?.spanId;

  /// Prepares the root navigation span for native app start.
  ///
  /// Creates an idle span so child spans can attach before navigation fires.
  /// Also creates the TTFD span so [ttfdSpanId] is available for
  /// [SentryFlutter.currentDisplay] before [trackAppStart] fires.
  /// Timestamps are backdated later in [trackAppStart].
  void prepareAppStart() {
    assert(_preparedRootNavigationSpan == null,
        'prepareRootNavigation called while a prepared span is still pending');

    cancelCurrentRoute();

    final routeSpan = _createRouteSpan(_rootRouteName);
    _preparedRootNavigationSpan = routeSpan;
    _ensureTtfdSpan(routeSpan, _rootRouteName);
  }

  /// Tracks the app start (native or generic).
  ///
  /// If [prepareAppStart] was called earlier, reuses that span and
  /// backdates it (along with the pre-created TTFD span) to [startTimestamp].
  /// Otherwise creates a fresh idle span (covers [GenericAppStartIntegration]
  /// which skips preparation).
  SentrySpanV2 trackAppStart({
    DateTime? startTimestamp,
    DateTime? ttidEndTimestamp,
  }) {
    final SentrySpanV2 routeSpan;
    switch (_preparedRootNavigationSpan) {
      case final prepared?:
        _preparedRootNavigationSpan = null;
        if (startTimestamp != null) {
          if (prepared case final RecordingSentrySpanV2 span) {
            span.startTimestamp = startTimestamp;
          }
          if (_ttfdSpan case final RecordingSentrySpanV2 ttfd) {
            ttfd.startTimestamp = startTimestamp;
          }
        }
        routeSpan = prepared;
      case null:
        routeSpan =
            _createRouteSpan(_rootRouteName, startTimestamp: startTimestamp);
    }

    _trackDisplaySpans(
      routeSpan,
      _rootRouteName,
      startTimestamp: startTimestamp,
      ttidEndTimestamp: ttidEndTimestamp,
    );
    return routeSpan;
  }

  /// Tracks a subsequent in-app navigation (push/replace).
  ///
  /// Cancels the previous route and starts fresh.
  SentrySpanV2 trackRoute(String routeName) {
    cancelCurrentRoute();

    final routeSpan = _createRouteSpan(routeName);
    _trackDisplaySpans(routeSpan, routeName);
    return routeSpan;
  }

  SentrySpanV2 _createRouteSpan(String routeName, {DateTime? startTimestamp}) =>
      _hub.startIdleSpan(routeName,
          startTimestamp: startTimestamp,
          attributes: {
            SemanticAttributesConstants.sentryOp:
                SentryAttribute.string(SentrySpanOperations.uiLoad),
            SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
                SentryTraceOrigins.autoNavigationRouteObserver),
          });

  /// Ensures the TTFD span exists, creating it if not already present.
  void _ensureTtfdSpan(
    SentrySpanV2 parentSpan,
    String routeName, {
    DateTime? startTimestamp,
  }) {
    if (_ttfdSpan != null) return;
    if (_hub.options
        case SentryFlutterOptions(enableTimeToFullDisplayTracing: true)) {
      _ttfdSpan = _hub.startInactiveSpan(
        '$routeName full display',
        parentSpan: parentSpan,
        startTimestamp: startTimestamp,
        attributes: {
          SemanticAttributesConstants.sentryOp:
              SentryAttribute.string(SentrySpanOperations.uiTimeToFullDisplay),
          SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
              SentryTraceOrigins.autoNavigationRouteObserver),
        },
      );
    }
  }

  /// Creates TTID and TTFD child spans for the given route span.
  void _trackDisplaySpans(
    SentrySpanV2 routeSpan,
    String routeName, {
    DateTime? startTimestamp,
    DateTime? ttidEndTimestamp,
  }) {
    _ensureTtfdSpan(routeSpan, routeName, startTimestamp: startTimestamp);

    final ttidSpan = _hub.startInactiveSpan(
      '$routeName initial display',
      parentSpan: routeSpan,
      startTimestamp: startTimestamp,
      attributes: {
        SemanticAttributesConstants.sentryOp:
            SentryAttribute.string(SentrySpanOperations.uiTimeToInitialDisplay),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
            SentryTraceOrigins.autoNavigationRouteObserver),
      },
    );
    if (ttidEndTimestamp != null) {
      if (startTimestamp != null) {
        ttidSpan.setAttribute(
            SemanticAttributesConstants.appVitalsTtidValue,
            SentryAttribute.double(ttidEndTimestamp
                .difference(startTimestamp)
                .inMilliseconds
                .toDouble()));
      }
      ttidSpan.end(endTimestamp: ttidEndTimestamp);
    } else {
      _frameCallbackHandler.addPostFrameCallback((_) {
        final endTimestamp = DateTime.now();
        if (startTimestamp != null) {
          ttidSpan.setAttribute(
              SemanticAttributesConstants.appVitalsTtidValue,
              SentryAttribute.double(endTimestamp
                  .difference(startTimestamp)
                  .inMilliseconds
                  .toDouble()));
        }
        ttidSpan.end(endTimestamp: endTimestamp);
      });
    }
  }

  /// Ends the active TTFD span if [spanId] matches, otherwise ignores the call.
  void reportFullyDisplayed(SpanId spanId) {
    final ttfdSpan = _ttfdSpan;
    if (ttfdSpan == null || ttfdSpan.spanId != spanId) {
      internalLogger.debug(
        'Ignoring reportFullyDisplayed for span $spanId because active TTFD span is ${ttfdSpan?.spanId}.',
      );
      return;
    }
    final endTimestamp = DateTime.now();
    ttfdSpan.setAttribute(
        SemanticAttributesConstants.appVitalsTtfdValue,
        SentryAttribute.double(endTimestamp
            .difference(ttfdSpan.startTimestamp)
            .inMilliseconds
            .toDouble()));
    ttfdSpan.end(endTimestamp: endTimestamp);
    _ttfdSpan = null;
  }

  /// Cancels all spans for the current route and resets tracker state.
  void cancelCurrentRoute() {
    _ttfdSpan = null;
    _preparedRootNavigationSpan = null;

    final activeSpan = _hub.getActiveSpan();
    if (activeSpan is IdleRecordingSentrySpanV2) {
      activeSpan
        ..status = SentrySpanStatusV2.cancelled
        ..end();
    }
  }
}
