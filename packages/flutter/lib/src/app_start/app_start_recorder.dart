// ignore_for_file: invalid_use_of_internal_member
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../utils/internal_logger.dart';
import 'app_start_result.dart';

enum _RecorderState { observing, frozen, closed }

/// Collects framework work without claiming that each frame was submitted.
/// Both trace formats consume the same result after the raster cutoff is known.
@internal
final class AppStartRecorder {
  AppStartRecorder({required this.clock});

  final DateTime Function() clock;
  final _builds = <AppStartRecordedInterval>[];
  _RecorderState _state = _RecorderState.observing;
  bool _attachmentAttempted = false;
  DateTime? _attachmentStart;
  AppStartRecordedInterval? _attachment;
  DateTime? _frameStart;
  bool _warmUp = false;
  int _omittedBuilds = 0;

  void beginAttachment({required bool hasRoot}) {
    if (_state != _RecorderState.observing || _attachmentAttempted) return;
    _attachmentAttempted = true;
    if (!hasRoot) _attachmentStart = _now();
  }

  void endAttachment({bool succeeded = true}) {
    if (_state != _RecorderState.observing) return;
    final start = _attachmentStart;
    _attachmentStart = null;
    if (!succeeded || start == null) return;
    final end = _now();
    if (end == null || end.isBefore(start)) return;
    _attachment = AppStartRecordedInterval(
      description: 'Root Widget Attachment',
      operation: SentrySpanOperations.appStartRootWidgetAttachment,
      threadName: 'ui',
      startTimestamp: start,
      endTimestamp: end,
    );
  }

  void beginFrame({required bool warmUp}) {
    if (_state != _RecorderState.observing || _attachment == null) return;
    _frameStart = _now();
    _warmUp = warmUp;
  }

  void endFrame({required bool deferred, bool succeeded = true}) {
    if (_state != _RecorderState.observing) return;
    final start = _frameStart;
    _frameStart = null;
    if (!succeeded || start == null) return;
    final end = _now();
    if (end == null || end.isBefore(start)) return;
    if (_builds.length == 10) {
      _omittedBuilds++;
      return;
    }
    _builds.add(
      AppStartRecordedInterval(
        description: 'Frame Build',
        operation: SentrySpanOperations.appStartFrameBuild,
        threadName: 'ui',
        startTimestamp: start,
        endTimestamp: end,
        data: {
          ProposedSemanticAttributes.flutterFrameWarmUp: _warmUp,
          ProposedSemanticAttributes.flutterFrameDeferred: deferred,
        },
      ),
    );
  }

  /// Stops observation immediately, even if native startup timing is pending.
  void freeze() {
    if (_state != _RecorderState.observing) return;
    _state = _RecorderState.frozen;
    _attachmentStart = null;
    _frameStart = null;
  }

  AppStartResult resolve(DateTime startupStart, AppStartResult raster) {
    freeze();
    if (_state == _RecorderState.closed) return raster;
    final intervals = <AppStartRecordedInterval>[?_attachment, ..._builds]
        .where(
          (span) =>
              !span.startTimestamp.isBefore(startupStart) &&
              !span.endTimestamp.isAfter(raster.rasterFinish),
        );
    final result = raster.withFrameworkIntervals(
      intervals,
      omittedBuilds: _omittedBuilds,
    );
    cancel();
    return result;
  }

  void cancel() {
    freeze();
    _state = _RecorderState.closed;
    _attachment = null;
    _builds.clear();
  }

  DateTime? _now() {
    try {
      return clock().toUtc();
    } catch (error, stackTrace) {
      internalLogger.warning(
        'Could not timestamp startup framework work',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
