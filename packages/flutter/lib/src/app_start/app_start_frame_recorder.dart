// ignore_for_file: invalid_use_of_internal_member
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../utils/internal_logger.dart';
import 'app_start_frame_phases.dart';
import 'app_start_span_kind.dart';

enum _RecorderState { observing, frozen, closed }

/// Collects framework work without claiming that each frame was submitted.
/// Both trace formats consume the same result after the raster cutoff is known.
@internal
final class AppStartFrameRecorder {
  AppStartFrameRecorder({required this.clock});

  final DateTime Function() clock;
  final _builds = <AppStartFrameSpan>[];
  _RecorderState _state = _RecorderState.observing;
  bool _attachmentAttempted = false;
  bool _attached = false;
  DateTime? _attachmentStart;
  AppStartFrameSpan? _attachment;
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
    _attached = true;
    _attachment = AppStartFrameSpan(
      kind: AppStartSpanKind.rootWidgetAttachment,
      startTimestamp: start,
      endTimestamp: end,
    );
  }

  void beginFrame({required bool warmUp}) {
    if (_state != _RecorderState.observing || !_attached) return;
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
      AppStartFrameSpan(
        kind: AppStartSpanKind.frameBuild,
        startTimestamp: start,
        endTimestamp: end,
        data: {
          SemanticAttributesConstants.appStartFrameWarmUp: _warmUp,
          SemanticAttributesConstants.appStartFrameDeferred: deferred,
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

  AppStartFramePhases resolve(
    DateTime startupStart,
    AppStartFramePhases raster,
  ) {
    freeze();
    if (_state == _RecorderState.closed) return raster;
    final candidates = _builds.toList();
    final attachment = _attachment;
    if (attachment != null) candidates.insert(0, attachment);
    final intervals = candidates
        .where(
          (span) =>
              !span.startTimestamp.isBefore(startupStart) &&
              !span.endTimestamp.isAfter(raster.rasterFinish),
        )
        .toList();
    final omittedBuilds = _omittedBuilds;
    cancel();
    return raster.withFrameworkSpans(intervals, omittedBuilds: omittedBuilds);
  }

  void cancel() {
    _state = _RecorderState.closed;
    _attachmentStart = null;
    _frameStart = null;
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
