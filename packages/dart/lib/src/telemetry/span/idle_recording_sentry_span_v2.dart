part of 'sentry_span_v2.dart';

/// Reason why an idle span was finished.
///
/// Used to log the reason why an idle span was finished.
enum _IdleSpanFinishReason {
  /// The idle timer expired (no pending child activity within [IdleRecordingSentrySpanV2.idleTimeout]).
  idleTimeout,

  /// The absolute [IdleRecordingSentrySpanV2.finalTimeout] was reached.
  finalTimeout,

  /// The span was ended  manually (e.g. via [end]).
  manualFinish,
}

/// Recording span with idle behavior built into the span itself.
final class IdleRecordingSentrySpanV2 extends RecordingSentrySpanV2 {
  final Duration idleTimeout;
  final Duration finalTimeout;
  final bool trimEndTimestamp;
  final SdkLifecycleRegistry _lifecycleRegistry;

  final Map<SpanId, RecordingSentrySpanV2> _activeDescendants = {};
  bool _isEnded = false;
  bool _hadActivity = false;
  Timer? _idleTimer;
  Timer? _finalTimer;
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
  })  : _lifecycleRegistry = lifecycleRegistry,
        super._(parentSpan: null) {
    _lifecycleRegistry.registerCallback<OnSpanStartV2>(_onSpanStartEvent);
    _lifecycleRegistry.registerCallback<OnSpanEndV2>(_onSpanEndEvent);
    _startIdleTimer();
    _startFinalTimer();
  }

  bool get hadActivity => _hadActivity;

  void resetIdleTimer() {
    if (_isEnded) return;
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
    if (_isEnded) return;

    if (event.span case final RecordingSentrySpanV2 child
        when _shouldTrackDescendant(child)) {
      _activeDescendants[child.spanId] = child;
      _hadActivity = true;

      _cancelIdleTimer();
    }
  }

  void _onSpanEndEvent(OnSpanEndV2 event) {
    if (_isEnded) return;

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
    if (_isEnded) return;

    _isEnded = true;

    _cancelTimers();
    _lifecycleRegistry.removeCallback<OnSpanStartV2>(_onSpanStartEvent);
    _lifecycleRegistry.removeCallback<OnSpanEndV2>(_onSpanEndEvent);

    final idleEndTimestamp = _resolveIdleEndTimestamp(requestedEndTimestamp);

    if (reason == _IdleSpanFinishReason.finalTimeout) {
      status = SentrySpanStatusV2.deadlineExceeded;
    }

    _finishActiveDescendants(idleEndTimestamp);
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

  void _finishActiveDescendants(DateTime idleEndTimestamp) {
    for (final child in _activeDescendants.values.toList()) {
      if (child.isEnded) continue;
      if (child.startTimestamp.isAfter(idleEndTimestamp)) continue;

      child.status = SentrySpanStatusV2.cancelled;
      child.end(endTimestamp: idleEndTimestamp);
      // Track explicitly because lifecycle callbacks are already unregistered
      // at this point, so _onSpanEndEvent won't fire for these force-ended children.
      _trackLatestChildEnd(idleEndTimestamp);

      internalLogger.debug(
        () => 'IdleRecordingSentrySpanV2: finished child span "${child.name}" '
            'with reason: ${SentrySpanStatusV2.cancelled.name}',
      );
    }
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
    final maxEndTimestamp = startTimestamp.add(finalTimeout);
    final upperBound = idleEndTimestamp.isBefore(maxEndTimestamp)
        ? idleEndTimestamp
        : maxEndTimestamp;

    var trimmedEndTimestamp = _latestChildEndTimestamp!;
    if (trimmedEndTimestamp.isBefore(startTimestamp)) {
      trimmedEndTimestamp = startTimestamp;
    }
    if (trimmedEndTimestamp.isAfter(upperBound)) {
      trimmedEndTimestamp = upperBound;
    }

    return trimmedEndTimestamp;
  }
}
