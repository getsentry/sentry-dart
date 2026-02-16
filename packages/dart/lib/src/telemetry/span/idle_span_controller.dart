import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';

/// Reason why an idle span was finished.
enum _IdleSpanFinishReason {
  /// The idle timer expired (no child activity for [idleTimeout]).
  idleTimeout,

  /// A child span ran longer than [childSpanTimeout].
  childSpanTimeout,

  /// The absolute [finalTimeout] was reached.
  finalTimeout,

  /// The span was ended externally (e.g. via [RecordingSentrySpanV2.end]).
  externalFinish,
}

/// Manages idle span behavior: auto-ending when the app goes idle,
/// tracking descendant spans as "activity", and restoring the previous
/// active span when done.
@internal
class IdleSpanController {
  final RecordingSentrySpanV2 span;
  final Duration idleTimeout;
  final Duration finalTimeout;
  final Duration childSpanTimeout;
  final bool trimEndTimestamp;
  final SdkLifecycleRegistry _lifecycleRegistry;
  final RecordingSentrySpanV2? previousActiveSpan;
  final void Function(IdleSpanController) _onFinish;

  final Map<SpanId, RecordingSentrySpanV2> _activities = {};
  bool _finished = false;
  bool _hadActivity = false;
  Timer? _idleTimer;
  Timer? _childTimer;
  Timer? _finalTimer;
  DateTime? _latestChildEndTimestamp;

  IdleSpanController({
    required this.span,
    required this.idleTimeout,
    required this.finalTimeout,
    required this.childSpanTimeout,
    required this.trimEndTimestamp,
    required SdkLifecycleRegistry lifecycleRegistry,
    required this.previousActiveSpan,
    required void Function(IdleSpanController) onFinish,
  })  : _lifecycleRegistry = lifecycleRegistry,
        _onFinish = onFinish {
    _lifecycleRegistry.registerCallback<OnSpanStartV2>(_onSpanStarted);
    _lifecycleRegistry.registerCallback<OnSpanEndV2>(_onSpanEnded);
    _restartIdleTimer();
    _startFinalTimer();
  }

  /// Whether any descendant span was ever tracked as activity.
  bool get hadActivity => _hadActivity;

  /// Called when the idle span's [RecordingSentrySpanV2.end] fires.
  /// Triggers cleanup if not already finished.
  void endFromSpan() {
    _finish(_IdleSpanFinishReason.externalFinish);
  }

  /// Resets the idle timer, extending the span's lifetime.
  /// Only effective when no descendant spans are currently active
  /// (i.e. the idle timer is the one running, not the child timer).
  void resetIdleTimer() {
    if (_finished) return;
    if (_activities.isNotEmpty) return;
    _restartIdleTimer();
  }

  void _onSpanStarted(OnSpanStartV2 event) {
    if (_finished) return;

    if (event.span case final RecordingSentrySpanV2 child
        when child != span && !child.isEnded && _isDescendant(child)) {
      _activities[child.spanId] = child;
      _hadActivity = true;

      _cancelIdleTimer();
      _restartChildTimer();
    }
  }

  void _onSpanEnded(OnSpanEndV2 event) {
    if (_finished) return;

    if (event.span case final RecordingSentrySpanV2 child) {
      final childEnd = _activities.remove(child.spanId)?.endTimestamp;
      if (childEnd != null) {
        _trackLatestChildEnd(childEnd);
      }

      if (_activities.isEmpty) {
        _cancelChildTimer();
        _restartIdleTimer();
      }
    }
  }

  bool _isDescendant(RecordingSentrySpanV2 candidate) {
    RecordingSentrySpanV2? current = candidate.parentSpan;
    while (current != null) {
      if (current == span) return true;
      current = current.parentSpan;
    }
    return false;
  }

  void _restartIdleTimer() {
    _cancelIdleTimer();
    _idleTimer = Timer(idleTimeout, () {
      _finish(_IdleSpanFinishReason.idleTimeout);
    });
  }

  void _restartChildTimer() {
    _cancelChildTimer();
    _childTimer = Timer(childSpanTimeout, () {
      _finish(_IdleSpanFinishReason.childSpanTimeout);
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _cancelChildTimer() {
    _childTimer?.cancel();
    _childTimer = null;
  }

  void _cancelFinalTimer() {
    _finalTimer?.cancel();
    _finalTimer = null;
  }

  void _cancelTimers() {
    _cancelIdleTimer();
    _cancelChildTimer();
    _cancelFinalTimer();
  }

  void _startFinalTimer() {
    _finalTimer = Timer(finalTimeout, () {
      _finish(_IdleSpanFinishReason.finalTimeout);
    });
  }

  void _finish(_IdleSpanFinishReason reason) {
    if (_finished) return;
    _finished = true;

    _cancelTimers();

    _lifecycleRegistry.removeCallback<OnSpanStartV2>(_onSpanStarted);
    _lifecycleRegistry.removeCallback<OnSpanEndV2>(_onSpanEnded);

    // Set deadline exceeded status for final timeout.
    if (reason == _IdleSpanFinishReason.finalTimeout) {
      span.status = SentrySpanStatusV2.deadlineExceeded;
    }

    // End the span if it hasn't been ended yet (e.g. timeout-triggered).
    // This must happen BEFORE trimming because overrideEndTimestamp sets
    // _endTimestamp which makes isEnded return true, preventing span.end()
    // from firing the onSpanEnd callback that triggers capture.
    if (!span.isEnded) {
      span.end();
    }

    // Child spans that are still active are ended at the idle span's end time.
    // At this point endTimestamp is guaranteed to be non-null because either
    // the span was ended externally or span.end() above just set it.
    _finishActiveChildren(span.endTimestamp!);

    // Trim end timestamp to latest child end if enabled.
    // Since span.end() fires capture via unawaited, the span object hasn't
    // been serialized yet — overriding the timestamp here is picked up.
    if (trimEndTimestamp) {
      _trimEndTimestamp();
    }

    _activities.clear();

    internalLogger.debug(
      () => 'IdleSpanController: finished idle span "${span.name}" '
          'with reason: ${reason.name}',
    );

    _onFinish(this);
  }

  void _finishActiveChildren(DateTime idleEndTimestamp) {
    // End still-recording descendant spans at the idle span's end time.
    final maxDuration = finalTimeout + idleTimeout;
    for (final child in _activities.values.toList()) {
      if (child.isEnded) continue;

      final startedAfterEnd = child.startTimestamp.isAfter(idleEndTimestamp);
      final ranTooLong =
          idleEndTimestamp.difference(child.startTimestamp) > maxDuration;
      if (startedAfterEnd || ranTooLong) continue;

      child.status = SentrySpanStatusV2.cancelled;
      child.end(endTimestamp: idleEndTimestamp);
      _trackLatestChildEnd(idleEndTimestamp);

      internalLogger.debug(
        () => 'IdleSpanController: finished child span "${child.name}" '
            'with reason: ${SentrySpanStatusV2.cancelled.name}',
      );
    }
  }

  void _trackLatestChildEnd(DateTime endTimestamp) {
    if (_latestChildEndTimestamp == null ||
        endTimestamp.isAfter(_latestChildEndTimestamp!)) {
      _latestChildEndTimestamp = endTimestamp;
    }
  }

  void _trimEndTimestamp() {
    if (_latestChildEndTimestamp == null) return;

    final spanEnd = span.endTimestamp ?? span.startTimestamp;
    final maxEnd = span.startTimestamp.add(finalTimeout);
    final upper = spanEnd.isBefore(maxEnd) ? spanEnd : maxEnd;

    DateTime trimmed = _latestChildEndTimestamp!;
    if (trimmed.isBefore(span.startTimestamp)) trimmed = span.startTimestamp;
    if (trimmed.isAfter(upper)) trimmed = upper;

    span.overrideEndTimestamp(trimmed);
  }
}
