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
  final _frameBuilds = <AppStartRecordedInterval>[];
  _RecorderState _state = _RecorderState.observing;
  bool _rootAttachmentAttempted = false;
  DateTime? _rootAttachmentStart;
  AppStartRecordedInterval? _rootAttachment;
  DateTime? _frameBuildStart;
  bool _isWarmUpFrame = false;

  void beginRootAttachment({required bool hasRoot}) {
    if (_state != _RecorderState.observing || _rootAttachmentAttempted) return;
    _rootAttachmentAttempted = true;
    if (!hasRoot) _rootAttachmentStart = _now();
  }

  void endRootAttachment({bool succeeded = true}) {
    if (_state != _RecorderState.observing) return;
    final start = _rootAttachmentStart;
    _rootAttachmentStart = null;
    if (!succeeded || start == null) return;
    final end = _now();
    if (end == null || end.isBefore(start)) return;
    _rootAttachment = AppStartRecordedInterval(
      description: 'Root Widget Attachment',
      operation: SentrySpanOperations.appStartRootWidgetAttachment,
      startTimestamp: start,
      endTimestamp: end,
    );
  }

  void beginFrameBuild({required bool warmUp}) {
    if (_state != _RecorderState.observing || _rootAttachment == null) return;
    _frameBuildStart = _now();
    _isWarmUpFrame = warmUp;
  }

  void endFrameBuild({required bool deferred, bool succeeded = true}) {
    if (_state != _RecorderState.observing) return;
    final start = _frameBuildStart;
    _frameBuildStart = null;
    if (!succeeded || start == null) return;
    final end = _now();
    if (end == null || end.isBefore(start)) return;
    if (_frameBuilds.length == 10) {
      return;
    }
    _frameBuilds.add(
      AppStartRecordedInterval(
        description: 'Frame Build',
        operation: SentrySpanOperations.appStartFrameBuild,
        startTimestamp: start,
        endTimestamp: end,
        data: {
          ProposedSemanticAttributes.flutterFrameWarmUp: _isWarmUpFrame,
          ProposedSemanticAttributes.flutterFrameDeferred: deferred,
        },
      ),
    );
  }

  /// Stops observation immediately, even if native startup timing is pending.
  void freeze() {
    if (_state != _RecorderState.observing) return;
    _state = _RecorderState.frozen;
    _rootAttachmentStart = null;
    _frameBuildStart = null;
  }

  AppStartResult resolve(DateTime processStart, AppStartResult rasterResult) {
    freeze();
    if (_state == _RecorderState.closed) return rasterResult;
    final intervals =
        <AppStartRecordedInterval>[?_rootAttachment, ..._frameBuilds].where(
          (interval) =>
              !interval.startTimestamp.isBefore(processStart) &&
              !interval.endTimestamp.isAfter(rasterResult.rasterFinish),
        );
    final result = rasterResult.withFrameworkIntervals(intervals);
    cancel();
    return result;
  }

  void cancel() {
    freeze();
    _state = _RecorderState.closed;
    _rootAttachment = null;
    _frameBuilds.clear();
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
