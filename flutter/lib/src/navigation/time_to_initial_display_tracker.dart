// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
import '../integrations/integrations.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';

@internal
class TimeToInitialDisplayTracker {
  static final TimeToInitialDisplayTracker _instance =
      TimeToInitialDisplayTracker._();

  factory TimeToInitialDisplayTracker(
      {FrameCallbackHandler? frameCallbackHandler}) {
    if (frameCallbackHandler != null) {
      _instance._frameCallbackHandler = frameCallbackHandler;
    }
    return _instance;
  }

  TimeToInitialDisplayTracker._();

  FrameCallbackHandler _frameCallbackHandler = DefaultFrameCallbackHandler();
  bool _isManual = false;
  Completer<DateTime>? _trackingCompleter;
  DateTime? _endTimestamp;

  /// This endTimestamp is needed in the [TimeToFullDisplayTracker] class
  @internal
  DateTime? get endTimestamp => _endTimestamp;

  Future<void> trackRegularRoute(
    ISentrySpan transaction,
    DateTime startTimestamp,
    String routeName,
  ) async {
    await _trackTimeToInitialDisplay(
      transaction: transaction,
      startTimestamp: startTimestamp,
      routeName: routeName,
      // endTimestamp is null by default, determined inside the private method
      // origin could be set here if needed, or determined inside the private method
    );
  }

  Future<void> trackAppStart(
    ISentrySpan transaction,
    AppStartInfo appStartInfo,
    String routeName,
  ) async {
    await _trackTimeToInitialDisplay(
      transaction: transaction,
      startTimestamp: appStartInfo.start,
      routeName: routeName,
      endTimestamp: appStartInfo.end,
      origin: SentryTraceOrigins.autoUiTimeToDisplay,
    );

    // Store the end timestamp for potential use by TTFD tracking
    _endTimestamp = appStartInfo.end;
  }

  Future<void> _trackTimeToInitialDisplay({
    required ISentrySpan transaction,
    required DateTime startTimestamp,
    required String routeName,
    DateTime? endTimestamp,
    String? origin,
  }) async {
    // Determine endTimestamp if not provided
    final _endTimestamp = endTimestamp ?? await determineEndTime();
    if (_endTimestamp == null) return;

    final ttidSpan = transaction.startChild(
      SentrySpanOperations.uiTimeToInitialDisplay,
      description: '$routeName initial display',
      startTimestamp: startTimestamp,
    );

    // Set the origin based on provided value or determine based on _isManual
    ttidSpan.origin = origin ??
        (_isManual
            ? SentryTraceOrigins.manualUiTimeToDisplay
            : SentryTraceOrigins.autoUiTimeToDisplay);

    final duration = Duration(
        milliseconds: _endTimestamp.difference(startTimestamp).inMilliseconds);
    final ttidMeasurement = SentryMeasurement.timeToInitialDisplay(duration);

    transaction.setMeasurement(ttidMeasurement.name, ttidMeasurement.value,
        unit: ttidMeasurement.unit);
    await ttidSpan.finish(endTimestamp: _endTimestamp);
  }

  Future<DateTime>? determineEndTime() {
    _trackingCompleter = Completer<DateTime>();

    // If we already know it's manual we can return the future immediately
    if (_isManual) {
      return _trackingCompleter?.future;
    }

    // Schedules a check at the end of the frame to determine if the tracking
    // should be completed immediately (approximation mode) or deferred (manual mode).
    _frameCallbackHandler.addPostFrameCallback((_) {
      if (!_isManual) {
        completeTracking();
      }
    });

    return _trackingCompleter?.future;
  }

  void markAsManual() {
    _isManual = true;
  }

  void completeTracking() {
    if (_trackingCompleter != null && !_trackingCompleter!.isCompleted) {
      final endTimestamp = DateTime.now();
      _endTimestamp = endTimestamp;
      _trackingCompleter?.complete(endTimestamp);
    }
  }

  void clear() {
    _isManual = false;
    _trackingCompleter = null;
    // We can't clear the ttid end time stamp here, because it might be needed
    // in the [TimeToFullDisplayTracker] class
  }
}
