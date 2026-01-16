part of 'sentry_span_v2.dart';

/// Factory for creating a [SentryTraceContextHeader] from a [RecordingSentrySpanV2].
typedef DscCreatorCallback = SentryTraceContextHeader Function(
    RecordingSentrySpanV2 span);

/// Called when a span ends, allowing the span to be processed or buffered.
typedef OnSpanEndCallback = Future<void> Function(RecordingSentrySpanV2 span);

/// A span that records timing and attribute data for performance monitoring.
///
/// This span captures start/end timestamps, attributes, and status. When
/// [end] is called, the span is passed to [OnSpanEndCallback] for processing.
///
/// Use [RecordingSentrySpanV2.root] to create a root span with a sampling
/// decision, or [RecordingSentrySpanV2.child] to create a child span that
/// inherits sampling from its parent.
final class RecordingSentrySpanV2 implements SentrySpanV2 {
  final SpanId _spanId = SpanId.newId();
  final RecordingSentrySpanV2? _parentSpan;
  final ClockProvider _clock;
  final OnSpanEndCallback _onSpanEnd;
  final DateTime _startTimestamp;
  final SentryId _traceId;
  final RecordingSentrySpanV2? _segmentSpan;
  final DscCreatorCallback _dscCreator;
  final Map<String, SentryAttribute> _attributes = {};
  final SentryTracesSamplingDecision _samplingDecision;

  // Mutable span state.
  SentrySpanStatusV2 _status = SentrySpanStatusV2.ok;
  DateTime? _endTimestamp;
  String _name;
  SentryTraceContextHeader? _frozenDsc;

  /// Private constructor. Use [root] or [child] factory constructors.
  RecordingSentrySpanV2._({
    required SentryId traceId,
    required String name,
    required OnSpanEndCallback onSpanEnd,
    required ClockProvider clock,
    required RecordingSentrySpanV2? parentSpan,
    required DscCreatorCallback dscCreator,
    required SentryTracesSamplingDecision samplingDecision,
  })  : _traceId = parentSpan?.traceId ?? traceId,
        _name = name,
        _parentSpan = parentSpan,
        _clock = clock,
        _onSpanEnd = onSpanEnd,
        _startTimestamp = clock(),
        _segmentSpan = parentSpan?.segmentSpan,
        _dscCreator = dscCreator,
        _samplingDecision = samplingDecision;

  /// Creates a root span with an explicit sampling decision.
  ///
  /// Root spans are the entry point of a trace segment.
  factory RecordingSentrySpanV2.root({
    required SentryId traceId,
    required String name,
    required OnSpanEndCallback onSpanEnd,
    required ClockProvider clock,
    required DscCreatorCallback dscCreator,
    required SentryTracesSamplingDecision samplingDecision,
  }) {
    return RecordingSentrySpanV2._(
      traceId: traceId,
      name: name,
      onSpanEnd: onSpanEnd,
      clock: clock,
      parentSpan: null,
      dscCreator: dscCreator,
      samplingDecision: samplingDecision,
    );
  }

  /// Creates a child span that inherits sampling from its parent.
  ///
  /// Child spans automatically inherit the sampling decision from the root
  /// span of their trace segment.
  factory RecordingSentrySpanV2.child({
    required RecordingSentrySpanV2 parent,
    required String name,
    required OnSpanEndCallback onSpanEnd,
    required ClockProvider clock,
    required DscCreatorCallback dscCreator,
  }) {
    return RecordingSentrySpanV2._(
      traceId: parent.traceId,
      name: name,
      onSpanEnd: onSpanEnd,
      clock: clock,
      parentSpan: parent,
      dscCreator: dscCreator,
      samplingDecision: parent.samplingDecision,
    );
  }

  @override
  SentryId get traceId => _traceId;

  @override
  SpanId get spanId => _spanId;

  @override
  RecordingSentrySpanV2? get parentSpan => _parentSpan;

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @override
  SentrySpanStatusV2 get status => _status;

  @override
  set status(SentrySpanStatusV2 value) => _status = value;

  @override
  DateTime? get endTimestamp => _endTimestamp;

  @override
  void end({DateTime? endTimestamp}) {
    if (isEnded) return;

    _endTimestamp = (endTimestamp ?? _clock()).toUtc();

    unawaited(_onSpanEnd(this));
    internalLogger.debug(
        'Span $name ended with start timestamp: $_startTimestamp, end timestamp: $_endTimestamp');
  }

  /// The sampling decision for this span's trace.
  ///
  /// Sampling is evaluated once at the root span level. All child spans
  /// automatically inherit the root span's sampling decision.
  SentryTracesSamplingDecision get samplingDecision =>
      segmentSpan._samplingDecision;

  /// The local root span of this trace segment.
  ///
  /// In distributed tracing, each service (Flutter, backend, etc.) has its own
  /// segment. Returns `this` if this span is the segment root.
  RecordingSentrySpanV2 get segmentSpan => _segmentSpan ?? this;

  /// Freezes and returns this span's DSC (only meaningful for segment spans).
  SentryTraceContextHeader _getOrCreateDsc() =>
      _frozenDsc ??= _dscCreator(this);

  /// The segment's Dynamic Sampling Context (DSC) header.
  ///
  /// Created lazily on first access and frozen for the segment's lifetime.
  /// All spans in the same segment share this DSC.
  SentryTraceContextHeader resolveDsc() => segmentSpan._getOrCreateDsc();

  @override
  bool get isEnded => _endTimestamp != null;

  @override
  Map<String, SentryAttribute> get attributes => Map.unmodifiable(_attributes);

  @override
  void setAttribute(String key, SentryAttribute value) {
    _attributes[key] = value;
  }

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {
    _attributes.addAll(attributes);
  }

  @override
  void removeAttribute(String key) {
    _attributes.remove(key);
  }

  Map<String, dynamic> toJson() {
    double toUnixSeconds(DateTime timestamp) =>
        timestamp.microsecondsSinceEpoch / 1000000;

    return {
      'trace_id': _traceId.toString(),
      'span_id': _spanId.toString(),
      'is_segment': _parentSpan == null,
      'name': _name,
      'status': _status.name,
      'end_timestamp':
          _endTimestamp == null ? null : toUnixSeconds(_endTimestamp!),
      'start_timestamp': toUnixSeconds(_startTimestamp),
      // Create a copy of attributes in case attributes are mutated during serialization
      if (_attributes.isNotEmpty)
        'attributes': Map.from(_attributes)
            .map((key, value) => MapEntry(key, value.toJson())),
      if (_parentSpan != null) 'parent_span_id': _parentSpan.spanId.toString(),
    };
  }
}
