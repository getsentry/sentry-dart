import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../integrations/app_start/app_start_tracker.dart';
import '../sentry_flutter_measurement.dart';

@internal
class TimeToInitialDisplayTracker {
  static final TimeToInitialDisplayTracker _instance =
      TimeToInitialDisplayTracker._internal();

  factory TimeToInitialDisplayTracker(
      {FrameCallbackHandler? frameCallbackHandler}) {
    if (frameCallbackHandler != null) {
      _instance._frameCallbackHandler = frameCallbackHandler;
    }
    return _instance;
  }

  TimeToInitialDisplayTracker._internal();

  FrameCallbackHandler _frameCallbackHandler = DefaultFrameCallbackHandler();
  bool _isManual = false;
  Completer<DateTime>? _trackingCompleter;
  DateTime? _endTimestamp;

  /// This endTimestamp is needed in the [TimeToFullDisplayTracker] class
  @internal
  DateTime? get endTimestamp => _endTimestamp;

  Future<void> trackRegularRoute(ISentrySpan transaction,
      DateTime startTimestamp, String routeName) async {
    final endTimestamp = await determineEndTime();
    if (endTimestamp == null) return;

    final ttidSpan = transaction.startChild(
        SentrySpanOperations.uiTimeToInitialDisplay,
        description: '$routeName initial display',
        startTimestamp: startTimestamp);

    if (_isManual) {
      ttidSpan.origin = SentryTraceOrigins.manualUiTimeToDisplay;
    } else {
      ttidSpan.origin = SentryTraceOrigins.autoUiTimeToDisplay;
    }

    final ttidMeasurement = SentryFlutterMeasurement.timeToInitialDisplay(
        Duration(
            milliseconds:
                endTimestamp.difference(startTimestamp).inMilliseconds));
    transaction.setMeasurement(ttidMeasurement.name, ttidMeasurement.value,
        unit: ttidMeasurement.unit);
    await ttidSpan.finish(endTimestamp: endTimestamp);

    // We can clear the state after creating and finishing the ttid span has finished
    clear();
  }

  Future<void> trackAppStart(ISentrySpan transaction, AppStartInfo appStartInfo,
      String routeName) async {
    final ttidSpan = transaction.startChild(
      SentrySpanOperations.uiTimeToInitialDisplay,
      description: '$routeName initial display',
      startTimestamp: appStartInfo.start,
    );
    ttidSpan.origin = SentryTraceOrigins.autoUiTimeToDisplay;

    transaction.setMeasurement(
        appStartInfo.measurement.name, appStartInfo.measurement.value,
        unit: appStartInfo.measurement.unit);

    final ttidMeasurement = SentryFlutterMeasurement.timeToInitialDisplay(
      Duration(milliseconds: appStartInfo.measurement.value.toInt()),
    );
    transaction.setMeasurement(ttidMeasurement.name, ttidMeasurement.value,
        unit: ttidMeasurement.unit);

    // Since app start measurement is immediate, finish the TTID span with the app start's end timestamp
    await ttidSpan.finish(endTimestamp: appStartInfo.end);

    // Store the end timestamp for potential use by TTFD tracking
    _endTimestamp = appStartInfo.end;
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
      // Reset after completion
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
