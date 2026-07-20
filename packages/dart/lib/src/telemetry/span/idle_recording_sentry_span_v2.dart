part of 'sentry_span_v2.dart';

/// Reason why an idle span was finished.
///
/// Used to log the reason why an idle span was finished.
enum _IdleSpanFinishReason {
  /// The idle timer expired (no pending child activity within [IdleRecordingSentrySpanV2.idleTimeout]).
  idleTimeout,

  /// The absolute [IdleRecordingSentrySpanV2.finalTimeout] was reached.
  finalTimeout,

  /// The span was ended manually (e.g. via [end]).
  manualFinish,
}

/// Recording span with idle behavior built into the span itself.
final class IdleRecordingSentrySpanV2 extends RecordingSentrySpanV2 {
  final Duration idleTimeout;
  final Duration finalTimeout;
  final bool trimEndTimestamp;
  final SdkLifecycleRegistry _lifecycleRegistry;

  final Map<SpanId, RecordingSentrySpanV2> _activeDescendants = {};

  /// Separate from [isEnded] which only becomes true after [super.end()].
  /// This flag is set at the start of [_end] to guard against re-entrant calls
  /// while teardown (cancelling timers, finishing descendants) is still in progress.
  bool _isEnding = false;
  Timer? _idleTimer;
  Timer? _finalTimer;
  late final DateTime _finalDeadlineTimestamp;
  DateTime? _latestChildEndTimestamp;

  IdleRecordingSentrySpanV2({
    required super.traceId,
    required super.name,
    required super.onSpanEnd,
    required super.clock,
    required super.dscCreator,
    required super.samplingDecision,
    required this.idleTimeout,
    required this.finalTimeout,
    required this.trimEndTimestamp,
    required SdkLifecycleRegistry lifecycleRegistry,
    super.startTimestamp,
  })  : _lifecycleRegistry = lifecycleRegistry,
        super._(parentSpan: null) {
    _finalDeadlineTimestamp = _clock().toUtc().add(finalTimeout);
    _lifecycleRegistry.registerCallback<OnSpanStartV2>(_onSpanStartEvent);
    _lifecycleRegistry.registerCallback<OnSpanEndV2>(_onSpanEndEvent);
    _startIdleTimer();
    _startFinalTimer();
  }

  void resetIdleTimer() {
    if (_isEnding) return;
    if (_activeDescendants.isNotEmpty) return;
    _startIdleTimer();
  }

  @override
  void end({DateTime? endTimestamp}) {
    _end(
      _IdleSpanFinishReason.manualFinish,
      requestedEndTimestamp: endTimestamp,
    );
  }

  void _onSpanStartEvent(OnSpanStartV2 event) {
    if (_isEnding) return;

    if (event.span case final RecordingSentrySpanV2 child
        when _shouldTrackDescendant(child)) {
      _activeDescendants[child.spanId] = child;
      _cancelIdleTimer();
    }
  }

  void _onSpanEndEvent(OnSpanEndV2 event) {
    if (_isEnding) return;

    if (event.span case final RecordingSentrySpanV2 child) {
      if (_activeDescendants.remove(child.spanId) == null) return;

      final childEnd = child.endTimestamp;
      if (childEnd != null) {
        _trackLatestChildEnd(childEnd);
      }

      if (_activeDescendants.isEmpty) {
        _startIdleTimer();
      }
    }
  }

  bool _shouldTrackDescendant(RecordingSentrySpanV2 candidate) =>
      candidate != this && !candidate.isEnded && _isDescendant(candidate);

  bool _isDescendant(RecordingSentrySpanV2 candidate) {
    RecordingSentrySpanV2? current = candidate.parentSpan;
    while (current != null) {
      if (current == this) return true;
      current = current.parentSpan;
    }
    return false;
  }

  void _startIdleTimer() {
    _cancelIdleTimer();
    _idleTimer = Timer(idleTimeout, () {
      _end(_IdleSpanFinishReason.idleTimeout);
    });
  }

  void _startFinalTimer() {
    _cancelFinalTimer();
    _finalTimer = Timer(finalTimeout, () {
      _end(_IdleSpanFinishReason.finalTimeout);
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _cancelFinalTimer() {
    _finalTimer?.cancel();
    _finalTimer = null;
  }

  void _cancelTimers() {
    _cancelIdleTimer();
    _cancelFinalTimer();
  }

  void _end(
    _IdleSpanFinishReason reason, {
    DateTime? requestedEndTimestamp,
  }) {
    if (_isEnding) return;

    _isEnding = true;

    _cancelTimers();
    _removeLifecycleCallbacks();

    final deadlineExceeded = reason == _IdleSpanFinishReason.finalTimeout;
    final idleEndTimestamp = deadlineExceeded
        ? _finalDeadlineTimestamp
        : _resolveIdleEndTimestamp(requestedEndTimestamp);

    if (deadlineExceeded) {
      status = SentrySpanStatusV2.error;
      setAttribute(
        SemanticAttributesConstants.sentryStatusMessage,
        SentryAttribute.string(SentrySpanStatusMessages.deadlineExceeded),
      );
    }

    _finishActiveDescendants(
      idleEndTimestamp,
      deadlineExceeded: deadlineExceeded,
    );
    _activeDescendants.clear();

    final finalEndTimestamp = _computeFinalEndTimestamp(idleEndTimestamp);

    super.end(endTimestamp: finalEndTimestamp);

    internalLogger.debug(
      () => 'IdleRecordingSentrySpanV2: finished idle span "$name" '
          'with reason: ${reason.name}',
    );
  }

  DateTime _resolveIdleEndTimestamp(DateTime? requestedEndTimestamp) =>
      (requestedEndTimestamp ?? _clock()).toUtc();

  void _finishActiveDescendants(
    DateTime idleEndTimestamp, {
    required bool deadlineExceeded,
  }) {
    for (final child in _activeDescendants.values.toList()) {
      if (child.isEnded) continue;
      if (child.startTimestamp.isAfter(idleEndTimestamp)) continue;

      child.status =
          deadlineExceeded ? SentrySpanStatusV2.error : SentrySpanStatusV2.ok;
      if (deadlineExceeded) {
        child.setAttribute(
          SemanticAttributesConstants.sentryStatusMessage,
          SentryAttribute.string(SentrySpanStatusMessages.deadlineExceeded),
        );
      }
      child.end(endTimestamp: idleEndTimestamp);
      // Track explicitly because lifecycle callbacks are already unregistered
      // at this point, so _onSpanEndEvent won't fire for these force-ended children.
      _trackLatestChildEnd(idleEndTimestamp);

      internalLogger.debug(
        () => 'IdleRecordingSentrySpanV2: finished still-active child span '
            '"${child.name}"',
      );
    }
  }

  void _removeLifecycleCallbacks() {
    _lifecycleRegistry.removeCallback<OnSpanStartV2>(_onSpanStartEvent);
    _lifecycleRegistry.removeCallback<OnSpanEndV2>(_onSpanEndEvent);
  }

  void _trackLatestChildEnd(DateTime childEndTimestamp) {
    if (_latestChildEndTimestamp == null ||
        childEndTimestamp.isAfter(_latestChildEndTimestamp!)) {
      _latestChildEndTimestamp = childEndTimestamp;
    }
  }

  DateTime _computeFinalEndTimestamp(DateTime idleEndTimestamp) {
    if (!trimEndTimestamp || _latestChildEndTimestamp == null) {
      return idleEndTimestamp;
    }
    // Clamp: don't extend beyond when the idle span actually ended.
    return _latestChildEndTimestamp!.isBefore(idleEndTimestamp)
        ? _latestChildEndTimestamp!
        : idleEndTimestamp;
  }
}
